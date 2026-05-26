import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:velhodozap/features/calls/calls.dart';
import 'dart:ui' as ui;
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';

enum ContactsDefaultTab {
  meusFavoritos,
  celular,
}

class ContactsScreen extends StatefulWidget {
  final String initialQuery;
  final ContactsDefaultTab defaultTab;

  const ContactsScreen({
    this.initialQuery = '',
    this.defaultTab = ContactsDefaultTab.meusFavoritos,
    super.key,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late final TextEditingController _searchController;
  late bool _showDeviceContacts;
  bool _loadingDeviceContacts = false;
  bool _deviceContactsPermissionDenied = false;
  List<fc.Contact> _deviceContacts = const [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _showDeviceContacts = widget.defaultTab == ContactsDefaultTab.celular;
    _loadDeviceContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceContacts() async {
    if (_loadingDeviceContacts) return;
    setState(() {
      _loadingDeviceContacts = true;
      _deviceContactsPermissionDenied = false;
    });

    final allowed = await fc.FlutterContacts.requestPermission(readonly: true);
    if (!allowed) {
      if (!mounted) return;
      setState(() {
        _loadingDeviceContacts = false;
        _deviceContactsPermissionDenied = true;
      });
      return;
    }

    final list = await fc.FlutterContacts.getContacts(withProperties: true, withPhoto: true);
    if (!mounted) return;
    setState(() {
      _deviceContacts = list;
      _loadingDeviceContacts = false;
    });
  }

  Future<fc.Contact?> _getContactForUpdate(String id) async {
    return await fc.FlutterContacts.getContact(
      id,
      withProperties: true,
      withAccounts: false,
      withPhoto: true,
    );
  }

  Future<void> _toggleStar(fc.Contact contact) async {
    final allowed = await fc.FlutterContacts.requestPermission(readonly: false);
    if (!allowed) return;
    try {
      final full = await fc.FlutterContacts.getContact(
        contact.id,
        withProperties: true,
        withAccounts: true,
        withPhoto: true,
      );
      if (full == null) return;
      full.isStarred = !contact.isStarred;
      await full.update();
      await _loadDeviceContacts();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar o favorito neste aparelho.')),
      );
    }
  }

  Future<void> _openDeviceEditor({fc.Contact? contact}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DeviceContactEditScreen(contact: contact)),
    );
    if (saved == true) {
      await _loadDeviceContacts();
    }
  }

  Widget _contactsModeChips() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('Celular'),
            selected: _showDeviceContacts,
            onSelected: (_) {
              setState(() => _showDeviceContacts = true);
              _loadDeviceContacts();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ChoiceChip(
            label: const Text('Meus'),
            selected: !_showDeviceContacts,
            onSelected: (_) => setState(() => _showDeviceContacts = false),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final qRaw = _searchController.text.trim();
    final qNorm = _normalizeForSearch(qRaw);
    final qDigits = qRaw.replaceAll(RegExp(r'\D'), '');
    final all = _deviceContacts.where((c) {
      if (qRaw.isEmpty) return true;

      if (qNorm.isNotEmpty) {
        final name = _normalizeForSearch(c.displayName);
        if (name.contains(qNorm)) return true;
      }

      if (qDigits.isNotEmpty) {
        for (final p in c.phones) {
          final digits = p.number.replaceAll(RegExp(r'\D'), '');
          if (digits.contains(qDigits)) return true;
        }
      }

      return false;
    }).toList(growable: false);
    final favs = all.where((c) => c.isStarred).toList(growable: false);
    final list = _showDeviceContacts ? all : favs;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contatos',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: _showDeviceContacts
          ? null
          : FloatingActionButton(
              onPressed: () => _openDeviceEditor(),
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                filled: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar contato',
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _contactsModeChips(),
          ),
          Expanded(
            child: DeviceContactsList(
              loading: _loadingDeviceContacts,
              permissionDenied: _deviceContactsPermissionDenied,
              contacts: list,
              onRetry: _loadDeviceContacts,
              onCall: (phone) async {
                await Calls.showCallOptions(context, phoneRaw: phone);
              },
              onWhatsApp: (phone) async {
                await Calls.openWhatsAppChat(context, phoneRaw: phone);
              },
              onToggleStar: (c) => _toggleStar(c),
              onEdit: (c) async {
                final full = await _getContactForUpdate(c.id);
                if (!mounted || full == null) return;
                await _openDeviceEditor(contact: full);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeForSearch(String input) {
    var s = input.trim().toLowerCase();
    if (s.isEmpty) return '';
    s = s
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return s;
  }
}

class DeviceContactsList extends StatelessWidget {
  final bool loading;
  final bool permissionDenied;
  final List<fc.Contact> contacts;
  final VoidCallback onRetry;
  final Future<void> Function(String phone) onCall;
  final Future<void> Function(String phone) onWhatsApp;
  final Future<void> Function(fc.Contact contact)? onToggleStar;
  final Future<void> Function(fc.Contact contact)? onEdit;

  const DeviceContactsList({
    required this.loading,
    required this.permissionDenied,
    required this.contacts,
    required this.onRetry,
    required this.onCall,
    required this.onWhatsApp,
    this.onToggleStar,
    this.onEdit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Permissão de contatos negada.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final bottom = MediaQuery.of(context).padding.bottom;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom + 8),
      itemBuilder: (context, index) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.white;
        final fgMuted = isDark ? Colors.white70 : Colors.white70;
        final c = contacts[index];
        final phone = c.phones.isEmpty ? '' : c.phones.first.number;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ContactAvatar(memoryBytes: c.photoOrThumbnail),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.displayName,
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: fg),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: onToggleStar == null ? null : () => onToggleStar!(c),
                            icon: Icon(c.isStarred ? Icons.star : Icons.star_border, color: fg),
                          ),
                          IconButton(
                            onPressed: onEdit == null ? null : () => onEdit!(c),
                            icon: Icon(Icons.edit, color: fg),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        phone.isEmpty ? 'Sem telefone' : phone,
                        style: TextStyle(fontSize: 18, color: fgMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const CircleBorder(),
                              ),
                              onPressed: phone.isEmpty ? null : () => onCall(phone),
                              child: const Icon(Icons.phone, size: 34),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const CircleBorder(),
                              ),
                              onPressed: phone.isEmpty ? null : () => onWhatsApp(phone),
                              child: const FaIcon(FontAwesomeIcons.whatsapp, size: 34),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemCount: contacts.length,
    );
  }
}

class DeviceContactEditScreen extends StatefulWidget {
  final fc.Contact? contact;

  const DeviceContactEditScreen({this.contact, super.key});

  @override
  State<DeviceContactEditScreen> createState() => _DeviceContactEditScreenState();
}

class _DeviceContactEditScreenState extends State<DeviceContactEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late bool _isStarred;
  bool _saving = false;
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.displayName ?? '');
    _numberController = TextEditingController(text: _initialNumber(widget.contact));
    _isStarred = widget.contact?.isStarred ?? true;
    _photoBytes = widget.contact?.photoOrThumbnail;
  }

  String _initialNumber(fc.Contact? c) {
    if (c == null) return '';
    if (c.phones.isEmpty) return '';
    final raw = c.phones.first.number;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('55') && digits.length > 2) return digits.substring(2);
    return digits;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<bool> _ensureWriteContacts() async {
    final allowed = await fc.FlutterContacts.requestPermission(readonly: false);
    if (allowed) return true;
    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Permissão necessária'),
          content: const Text('Permita acesso a Contatos para salvar, editar ou apagar.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return false;
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final digits = _numberController.text.replaceAll(RegExp(r'\D'), '');
    if (name.isEmpty || digits.isEmpty) return;
    final canWrite = await _ensureWriteContacts();
    if (!canWrite) return;

    setState(() => _saving = true);
    try {
      final phone = '+55$digits';
      if (widget.contact == null) {
        final account = await _pickInsertAccount();
        if (account == null) {
          await _fallbackToNativeInsert(name: name, phone: phone);
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
        final c = fc.Contact()
          ..displayName = name
          ..name = fc.Name(first: name)
          ..isStarred = _isStarred
          ..phones = [fc.Phone(phone)]
          ..accounts = [account]
          ..photo = _photoBytes;
        await c.insert();
      } else {
        final c = await fc.FlutterContacts.getContact(
          widget.contact!.id,
          withProperties: true,
          withAccounts: true,
          withPhoto: true,
        );
        if (c == null) return;
        c.displayName = name;
        c.name.first = name;
        c.name.last = '';
        c.name.middle = '';
        c.name.prefix = '';
        c.name.suffix = '';
        c.name.nickname = '';
        c.isStarred = _isStarred;
        c.phones = [fc.Phone(phone)];
        c.photo = _photoBytes;
        await c.update();
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar este contato.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<fc.Account?> _pickInsertAccount() async {
    if (!Platform.isAndroid) return fc.Account('', '', '', const []);
    try {
      final list = await fc.FlutterContacts.getContacts(withProperties: false, withAccounts: true, sorted: false);
      for (final c in list) {
        for (final a in c.accounts) {
          final type = a.type.trim();
          final name = a.name.trim();
          if (type.isEmpty || name.isEmpty) continue;
          final t = type.toLowerCase();
          if (t.contains('whatsapp') ||
              t.contains('telegram') ||
              t.contains('skype') ||
              t.contains('facebook') ||
              t.contains('messenger') ||
              t.contains('viber') ||
              t.contains('signal')) {
            continue;
          }
          return fc.Account('', a.type, a.name, const []);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fallbackToNativeInsert({required String name, required String phone}) async {
    if (!Platform.isAndroid) return;
    final intent = AndroidIntent(
      action: 'android.intent.action.INSERT',
      data: 'content://com.android.contacts/contacts',
      arguments: {
        'name': name,
        'phone': phone,
      },
    );
    await intent.launch();
  }

  Future<void> _pickFromGallery() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final cropped = await PhotoCropperDialog.crop(context, bytes);
    if (!mounted) return;
    setState(() => _photoBytes = cropped ?? bytes);
  }

  Future<void> _pickFromCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final cropped = await PhotoCropperDialog.crop(context, bytes);
    if (!mounted) return;
    setState(() => _photoBytes = cropped ?? bytes);
  }

  Future<void> _delete() async {
    final c = widget.contact;
    if (c == null) return;
    final canWrite = await _ensureWriteContacts();
    if (!canWrite) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Apagar contato?'),
          content: const Text('Esse contato será removido do telefone.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Apagar')),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      final full = await fc.FlutterContacts.getContact(
        c.id,
        withProperties: true,
        withAccounts: true,
        withPhoto: false,
      );
      if (full == null) return;
      await full.delete();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível apagar este contato.')),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.contact != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar contato' : 'Adicionar contato',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isStarred = !_isStarred),
            icon: Icon(_isStarred ? Icons.star : Icons.star_border),
          ),
          if (isEditing)
            IconButton(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(64),
                onTap: () async {
                  await showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (context) {
                      return SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton.icon(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await _pickFromGallery();
                                },
                                icon: const Icon(Icons.photo),
                                label: const Text('Escolher da galeria'),
                              ),
                              const SizedBox(height: 10),
                              FilledButton.tonalIcon(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await _pickFromCamera();
                                },
                                icon: const Icon(Icons.photo_camera),
                                label: const Text('Tirar foto'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black26,
                    ),
                  ),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: ClipOval(
                      child: _photoBytes == null
                          ? Center(
                              child: Icon(
                                Icons.person,
                                size: 44,
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                              ),
                            )
                          : Image.memory(_photoBytes!, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                filled: true,
                border: OutlineInputBorder(),
                labelText: 'Nome',
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                filled: true,
                border: OutlineInputBorder(),
                labelText: 'Número (sem 55)',
                prefixText: '+55 ',
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text(
                'Salvar',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactAvatar extends StatelessWidget {
  final Uint8List? memoryBytes;

  const ContactAvatar({this.memoryBytes, super.key});

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white10 : Colors.black12,
        border: Border.all(color: isDark ? Colors.white12 : Colors.black26),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: memoryBytes == null
              ? Center(
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                )
              : Image.memory(memoryBytes!, width: size, height: size, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class PhotoCropperDialog extends StatefulWidget {
  final Uint8List bytes;

  const PhotoCropperDialog({required this.bytes, super.key});

  static Future<Uint8List?> crop(BuildContext context, Uint8List bytes) async {
    return await showDialog<Uint8List>(
      context: context,
      builder: (_) => PhotoCropperDialog(bytes: bytes),
    );
  }

  @override
  State<PhotoCropperDialog> createState() => _PhotoCropperDialogState();
}

class _PhotoCropperDialogState extends State<PhotoCropperDialog> {
  final _boundaryKey = GlobalKey();
  late final TransformationController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double delta) {
    final m = _controller.value;
    final scale = m.getMaxScaleOnAxis();
    final next = (scale + delta).clamp(1.0, 5.0);
    final center = const Offset(140, 140);
    final newM = Matrix4.identity();
    newM.setEntry(0, 0, next);
    newM.setEntry(1, 1, next);
    newM.setEntry(0, 3, center.dx * (1 - next));
    newM.setEntry(1, 3, center.dy * (1 - next));
    _controller.value = newM;
  }

  void _reset() {
    _controller.value = Matrix4.identity();
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (!mounted) return;
        Navigator.of(context).pop(null);
        return;
      }

      final img = await boundary.toImage(pixelRatio: 2);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        if (!mounted) return;
        Navigator.of(context).pop(null);
        return;
      }
      final raw = data.buffer.asUint8List();
      final resized = await _resizeToSquare(raw, 256);
      if (!mounted) return;
      Navigator.of(context).pop(resized);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Uint8List> _resizeToSquare(Uint8List pngBytes, int size) async {
    final codec = await ui.instantiateImageCodec(
      pngBytes,
      targetWidth: size,
      targetHeight: size,
    );
    final frame = await codec.getNextFrame();
    final out = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return out?.buffer.asUint8List() ?? pngBytes;
  }

  @override
  Widget build(BuildContext context) {
    const cropSize = 280.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: const Text(
        'Ajustar foto',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: cropSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : Colors.black12,
                ),
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: _boundaryKey,
                      child: SizedBox(
                        width: cropSize,
                        height: cropSize,
                        child: ClipRect(
                          child: InteractiveViewer(
                            transformationController: _controller,
                            minScale: 1,
                            maxScale: 5,
                            panEnabled: true,
                            scaleEnabled: true,
                            boundaryMargin: const EdgeInsets.all(80),
                            child: SizedBox(
                              width: cropSize,
                              height: cropSize,
                              child: Image.memory(
                                widget.bytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Container(
                        width: cropSize,
                        height: cropSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.black26,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _saving ? null : () => _zoom(-0.3),
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  onPressed: _saving ? null : _reset,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  onPressed: _saving ? null : () => _zoom(0.3),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _confirm,
          child: const Text('Usar'),
        ),
      ],
    );
  }
}

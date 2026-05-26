import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  final prefs = await SharedPreferences.getInstance();
  final configStore = HomeConfigStore(prefs);
  await configStore.load();
  final contactsStore = ContactsStore(prefs);
  await contactsStore.load();
  runApp(VelhoDoZapApp(configStore: configStore, contactsStore: contactsStore));
}

final class PlatformIntents {
  static const _channel = MethodChannel('velhodozap/platform_intents');

  static Future<bool> openApp({
    required String packageName,
    bool relaunch = false,
  }) async {
    final ok = await _channel.invokeMethod<bool>('openApp', {
      'packageName': packageName,
      'relaunch': relaunch,
    });
    return ok ?? false;
  }

  static Future<void> openSystemSettings() async {
    await _channel.invokeMethod<void>('openSystemSettings');
  }

  static Future<void> openVelhoDoZapSettings() async {
    await _channel.invokeMethod<void>('openVelhoDoZapSettings');
  }

  static Future<bool?> getBluetoothEnabled() async {
    return await _channel.invokeMethod<bool>('getBluetoothEnabled');
  }

  static Future<Map<Object?, Object?>?> getBluetoothInfo() async {
    return await _channel.invokeMethod<Map<Object?, Object?>>('getBluetoothInfo');
  }

  static Future<Map<Object?, Object?>?> getCellSignalInfo() async {
    return await _channel.invokeMethod<Map<Object?, Object?>>('getCellSignalInfo');
  }
}

enum AppThemeId {
  darkGreen,
  darkBlue,
  light,
}

enum StatusItemId {
  battery,
  wifi,
  cellular,
  bluetooth,
}

enum AppButtonId {
  phone,
  contacts,
  whatsapp,
  youtube,
}

class HomeConfig {
  final AppThemeId themeId;
  final List<StatusItemId> statusItems;
  final List<AppButtonId> appButtons;

  const HomeConfig({
    required this.themeId,
    required this.statusItems,
    required this.appButtons,
  });

  factory HomeConfig.defaults() {
    return const HomeConfig(
      themeId: AppThemeId.darkGreen,
      statusItems: [
        StatusItemId.battery,
        StatusItemId.wifi,
        StatusItemId.cellular,
        StatusItemId.bluetooth,
      ],
      appButtons: [
        AppButtonId.phone,
        AppButtonId.contacts,
        AppButtonId.whatsapp,
        AppButtonId.youtube,
      ],
    );
  }

  HomeConfig copyWith({
    AppThemeId? themeId,
    List<StatusItemId>? statusItems,
    List<AppButtonId>? appButtons,
  }) {
    return HomeConfig(
      themeId: themeId ?? this.themeId,
      statusItems: statusItems ?? this.statusItems,
      appButtons: appButtons ?? this.appButtons,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeId': themeId.name,
      'statusItems': statusItems.map((e) => e.name).toList(growable: false),
      'appButtons': appButtons.map((e) => e.name).toList(growable: false),
    };
  }

  factory HomeConfig.fromJson(Map<String, dynamic> json) {
    final themeName = json['themeId'] as String?;
    final themeId = AppThemeId.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => AppThemeId.darkGreen,
    );

    final statusNames = (json['statusItems'] as List?)?.whereType<String>().toList() ?? const <String>[];
    StatusItemId parseStatus(String name) {
      switch (name) {
        case 'battery':
          return StatusItemId.battery;
        case 'wifi':
          return StatusItemId.wifi;
        case 'cellular':
          return StatusItemId.cellular;
        case 'bluetooth':
          return StatusItemId.bluetooth;
        case 'network':
          return StatusItemId.wifi;
        case 'signal':
          return StatusItemId.cellular;
        default:
          return StatusItemId.battery;
      }
    }

    final statusItemsRaw = statusNames.map(parseStatus).toList(growable: false);
    final statusItems = <StatusItemId>[];
    for (final item in statusItemsRaw) {
      if (!statusItems.contains(item)) statusItems.add(item);
    }

    final appNames = (json['appButtons'] as List?)?.whereType<String>().toList() ?? const <String>[];
    AppButtonId parseApp(String name) {
      switch (name) {
        case 'phone':
          return AppButtonId.phone;
        case 'contacts':
          return AppButtonId.contacts;
        case 'whatsapp':
          return AppButtonId.whatsapp;
        case 'youtube':
          return AppButtonId.youtube;
        default:
          return AppButtonId.phone;
      }
    }

    final appButtonsRaw = appNames.map(parseApp).toList(growable: false);
    final appButtons = <AppButtonId>[];
    for (final item in appButtonsRaw) {
      if (!appButtons.contains(item)) appButtons.add(item);
    }

    final sanitizedStatus = statusItems.isEmpty ? const [StatusItemId.battery] : statusItems.take(4).toList();
    final sanitizedApps = appButtons.isEmpty ? const [AppButtonId.phone] : appButtons.take(8).toList();

    return HomeConfig(
      themeId: themeId,
      statusItems: sanitizedStatus,
      appButtons: sanitizedApps,
    );
  }
}

class HomeConfigStore extends ChangeNotifier {
  static const _prefsKey = 'home_config_v1';

  final SharedPreferences _prefs;
  HomeConfig _config = HomeConfig.defaults();

  HomeConfigStore(this._prefs);

  HomeConfig get config => _config;

  Future<void> load() async {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _config = HomeConfig.fromJson(decoded);
    } catch (_) {}
  }

  Future<void> _save() async {
    final raw = jsonEncode(_config.toJson());
    await _prefs.setString(_prefsKey, raw);
  }

  Future<void> setTheme(AppThemeId themeId) async {
    _config = _config.copyWith(themeId: themeId);
    await _save();
    notifyListeners();
  }

  Future<bool> setStatusEnabled(StatusItemId item, bool enabled) async {
    final list = _config.statusItems.toList(growable: true);
    if (enabled) {
      if (list.contains(item)) return true;
      if (list.length >= 4) return false;
      list.add(item);
    } else {
      list.remove(item);
      if (list.isEmpty) {
        list.add(StatusItemId.battery);
      }
    }

    _config = _config.copyWith(statusItems: list);
    await _save();
    notifyListeners();
    return true;
  }

  Future<bool> setAppEnabled(AppButtonId item, bool enabled) async {
    final list = _config.appButtons.toList(growable: true);
    if (enabled) {
      if (list.contains(item)) return true;
      if (list.length >= 8) return false;
      list.add(item);
    } else {
      list.remove(item);
      if (list.isEmpty) {
        list.add(AppButtonId.phone);
      }
    }

    _config = _config.copyWith(appButtons: list);
    await _save();
    notifyListeners();
    return true;
  }
}

class HomeConfigScope extends InheritedNotifier<HomeConfigStore> {
  const HomeConfigScope({
    required HomeConfigStore configStore,
    required super.child,
    super.key,
  }) : super(notifier: configStore);

  static HomeConfigStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HomeConfigScope>();
    return scope!.notifier!;
  }
}

class ContactEntry {
  final String id;
  final String name;
  final String nationalNumber;
  final bool isFavorite;
  final String? photoAsset;

  const ContactEntry({
    required this.id,
    required this.name,
    required this.nationalNumber,
    required this.isFavorite,
    this.photoAsset,
  });

  String get phoneE164 => '55$nationalNumber';

  ContactEntry copyWith({
    String? name,
    String? nationalNumber,
    bool? isFavorite,
    String? photoAsset,
  }) {
    return ContactEntry(
      id: id,
      name: name ?? this.name,
      nationalNumber: nationalNumber ?? this.nationalNumber,
      isFavorite: isFavorite ?? this.isFavorite,
      photoAsset: photoAsset ?? this.photoAsset,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nationalNumber': nationalNumber,
      'isFavorite': isFavorite,
      'photoAsset': photoAsset,
    };
  }

  factory ContactEntry.fromJson(Map<String, dynamic> json) {
    return ContactEntry(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      nationalNumber: (json['nationalNumber'] as String?) ?? '',
      isFavorite: (json['isFavorite'] as bool?) ?? true,
      photoAsset: json['photoAsset'] as String?,
    );
  }
}

class ContactsStore extends ChangeNotifier {
  static const _prefsKey = 'contacts_v1';

  final SharedPreferences _prefs;
  List<ContactEntry> _contacts = const [];

  ContactsStore(this._prefs);

  List<ContactEntry> get contacts => _contacts;

  Future<void> load() async {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _contacts = const [];
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _contacts = decoded
          .whereType<Map>()
          .map((e) => ContactEntry.fromJson(e.cast<String, dynamic>()))
          .where((c) => c.id.isNotEmpty && c.name.trim().isNotEmpty && c.nationalNumber.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {}
  }

  Future<void> _save() async {
    final raw = jsonEncode(_contacts.map((c) => c.toJson()).toList(growable: false));
    await _prefs.setString(_prefsKey, raw);
  }

  Future<void> addOrUpdate(ContactEntry entry) async {
    final list = _contacts.toList(growable: true);
    final idx = list.indexWhere((c) => c.id == entry.id);
    if (idx >= 0) {
      list[idx] = entry;
    } else {
      list.add(entry);
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _contacts = list.toList(growable: false);
    await _save();
    notifyListeners();
  }

  Future<void> deleteById(String id) async {
    final list = _contacts.where((c) => c.id != id).toList(growable: false);
    _contacts = list;
    await _save();
    notifyListeners();
  }
}

class ContactsScope extends InheritedNotifier<ContactsStore> {
  const ContactsScope({
    required ContactsStore contactsStore,
    required super.child,
    super.key,
  }) : super(notifier: contactsStore);

  static ContactsStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ContactsScope>();
    return scope!.notifier!;
  }
}

class VelhoDoZapApp extends StatelessWidget {
  final HomeConfigStore configStore;
  final ContactsStore contactsStore;

  const VelhoDoZapApp({
    required this.configStore,
    required this.contactsStore,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ContactsScope(
      contactsStore: contactsStore,
      child: HomeConfigScope(
        configStore: configStore,
        child: AnimatedBuilder(
          animation: configStore,
          builder: (context, _) {
            final config = configStore.config;
            final theme = _buildTheme(config);

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'VelhoDoZap',
              theme: theme,
              home: const HomeScreen(),
            );
          },
        ),
      ),
    );
  }
}

ThemeData _buildTheme(HomeConfig config) {
  switch (config.themeId) {
    case AppThemeId.darkGreen:
      return ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A7C4A),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      );
    case AppThemeId.darkBlue:
      return ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F5EFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF05070F),
        useMaterial3: true,
      );
    case AppThemeId.light:
      return ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A7C4A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F6F6),
        useMaterial3: true,
      );
  }
}

class Contact {
  final String name;
  final String phoneE164;
  final String? photoAsset;

  const Contact({
    required this.name,
    required this.phoneE164,
    this.photoAsset,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _battery = Battery();
  final _connectivity = Connectivity();

  int? _batteryLevel;
  BatteryState? _batteryState;
  String _networkLabel = 'Sem rede';
  String _bluetoothLabel = 'BT: —';
  String _cellLabel = 'Celular: —';

  StreamSubscription<dynamic>? _batteryStateSub;
  StreamSubscription<dynamic>? _connectivitySub;
  Timer? _batteryTimer;
  Timer? _bluetoothTimer;
  Timer? _cellTimer;

  @override
  void initState() {
    super.initState();
    _ensurePermissions();
    _initBattery();
    _initConnectivity();
    _initBluetooth();
    _initCellSignal();
  }

  Future<void> _ensurePermissions() async {
    if (!mounted) return;
    await [
      Permission.phone,
      Permission.bluetoothConnect,
    ].request();
  }

  Future<void> _initBattery() async {
    await _refreshBatteryLevel();

    _batteryStateSub = _battery.onBatteryStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _batteryState = state);
    });

    _batteryTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      await _refreshBatteryLevel();
    });
  }

  Future<void> _refreshBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (!mounted) return;
      setState(() => _batteryLevel = level);
    } catch (_) {}
  }

  void _initConnectivity() {
    final Stream connectivityStream = _connectivity.onConnectivityChanged;
    _connectivitySub = connectivityStream.listen((event) {
      final results = <ConnectivityResult>[];
      if (event is ConnectivityResult) {
        results.add(event);
      } else if (event is List<ConnectivityResult>) {
        results.addAll(event);
      }

      final isWifi = results.contains(ConnectivityResult.wifi);
      final isMobile = results.contains(ConnectivityResult.mobile);
      final isEthernet = results.contains(ConnectivityResult.ethernet);
      final isConnected = isWifi || isMobile || isEthernet;

      if (!mounted) return;
      setState(() {
        if (!isConnected) {
          _networkLabel = 'Sem rede';
          return;
        }

        if (isWifi) {
          _networkLabel = 'Wi‑Fi';
          return;
        }

        if (isMobile) {
          _networkLabel = 'Rede móvel';
          return;
        }

        if (isEthernet) {
          _networkLabel = 'Ethernet';
          return;
        }

        _networkLabel = 'Conectado';
      });
    });
  }

  void _initBluetooth() {
    _bluetoothTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final info = await PlatformIntents.getBluetoothInfo();
      if (!mounted) return;
      setState(() {
        if (info == null) {
          _bluetoothLabel = 'BT: —';
          return;
        }

        final enabled = info['enabled'] as bool?;
        final connected = info['connected'] as bool?;
        if (enabled == null) {
          _bluetoothLabel = 'BT: —';
          return;
        }
        if (!enabled) {
          _bluetoothLabel = 'BT: Desligado';
          return;
        }
        if (connected == true) {
          _bluetoothLabel = 'BT: Conectado';
          return;
        }
        _bluetoothLabel = 'BT: Ligado';
      });
    });
  }

  void _initCellSignal() {
    _cellTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final info = await PlatformIntents.getCellSignalInfo();
      if (!mounted) return;

      setState(() {
        if (_networkLabel != 'Rede móvel') {
          _cellLabel = 'Celular: Não';
          return;
        }
        if (info == null) {
          _cellLabel = 'Celular: —';
          return;
        }

        final level = info['level'] as int?;
        final dbm = info['dbm'] as int?;
        final networkType = info['networkType'] as int?;
        final type = _mapNetworkTypeToLabel(networkType);
        final bars = level == null ? '—' : '${level + 1}/5';
        final dbmText = dbm == null ? '' : ' ${dbm}dBm';

        _cellLabel = 'Celular: $type $bars$dbmText';
      });
    });
  }

  String _mapNetworkTypeToLabel(int? type) {
    if (type == null) return '—';
    switch (type) {
      case 20:
        return '5G';
      case 13:
        return '4G';
      case 3:
      case 8:
      case 9:
      case 10:
      case 15:
        return '3G';
      case 1:
      case 2:
      case 4:
      case 7:
      case 11:
        return '2G';
      default:
        return '—';
    }
  }

  @override
  void dispose() {
    _batteryStateSub?.cancel();
    _connectivitySub?.cancel();
    _batteryTimer?.cancel();
    _bluetoothTimer?.cancel();
    _cellTimer?.cancel();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    final ok = await PlatformIntents.openApp(
      packageName: 'com.whatsapp',
      relaunch: true,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp não instalado.')),
      );
    }
  }

  Future<void> _openYouTube() async {
    final ok = await PlatformIntents.openApp(
      packageName: 'com.google.android.youtube',
      relaunch: true,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('YouTube não instalado.')),
      );
    }
  }

  void _openDialer() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DialerScreen()),
    );
  }

  void _openContacts() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ContactsScreen()),
    );
  }

  void _openCustomization() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HomeCustomizationScreen()),
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Configurações',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openCustomization();
                  },
                  icon: const Icon(Icons.tune),
                  label: const Text('Personalizar tela inicial'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await PlatformIntents.openSystemSettings();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Abrir configurações do aparelho'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await PlatformIntents.openVelhoDoZapSettings();
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Configurações do app no Android'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _buildStatusItems(HomeConfig config, String batteryText, String charging) {
    final items = <String>[];
    final seen = <StatusItemId>{};
    for (final item in config.statusItems) {
      if (!seen.add(item)) continue;
      switch (item) {
        case StatusItemId.battery:
          items.add('$batteryText$charging');
        case StatusItemId.wifi:
          items.add('Wi‑Fi: ${_networkLabel == 'Wi‑Fi' ? 'Conectado' : 'Não'}');
        case StatusItemId.cellular:
          items.add(_cellLabel);
        case StatusItemId.bluetooth:
          items.add(_bluetoothLabel);
      }
    }
    return items.take(4).toList(growable: false);
  }

  List<_BigTile> _buildAppTiles(HomeConfig config) {
    final tiles = <_BigTile>[];
    for (final item in config.appButtons) {
      switch (item) {
        case AppButtonId.phone:
          tiles.add(_BigTile(label: 'Telefone', icon: Icons.phone, onTap: _openDialer));
        case AppButtonId.contacts:
          tiles.add(_BigTile(label: 'Contatos', icon: Icons.person, onTap: _openContacts));
        case AppButtonId.whatsapp:
          tiles.add(_BigTile(label: 'WhatsApp', icon: FontAwesomeIcons.whatsapp, onTap: _openWhatsApp));
        case AppButtonId.youtube:
          tiles.add(_BigTile(label: 'YouTube', icon: FontAwesomeIcons.youtube, onTap: _openYouTube));
      }
    }
    return tiles.take(8).toList(growable: false);
  }

  int _pickColumns({required int count, required double width}) {
    if (count <= 1) return 1;
    const minTileWidth = 140.0;
    final maxCols = (width / minTileWidth).floor().clamp(2, 4);
    if (count <= 4) return 2.clamp(2, maxCols);
    if (count <= 6) return 3.clamp(2, maxCols);
    return 4.clamp(2, maxCols);
  }

  @override
  Widget build(BuildContext context) {
    final config = HomeConfigScope.of(context).config;
    final batteryText = _batteryLevel == null ? 'Bateria: —' : 'Bateria: $_batteryLevel%';
    final charging = _batteryState == BatteryState.charging ? ' (carregando)' : '';
    final statusItems = _buildStatusItems(config, batteryText, charging);
    final appTiles = _buildAppTiles(config);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _BigStatusBar(
                    items: statusItems,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = constraints.maxHeight;
                        final count = appTiles.length;
                        final cols = _pickColumns(count: count, width: width);
                        final rows = (count / cols).ceil().clamp(1, 99);

                        const spacing = 16.0;
                        final tileWidth = (width - (cols - 1) * spacing) / cols;
                        final tileHeight = (height - (rows - 1) * spacing) / rows;
                        int indexFor(int row, int col) => row * cols + col;

                        return Column(
                          children: [
                            for (var r = 0; r < rows; r++) ...[
                              if (r > 0) const SizedBox(height: spacing),
                              Row(
                                children: [
                                  for (var c = 0; c < cols; c++) ...[
                                    if (c > 0) const SizedBox(width: spacing),
                                    SizedBox(
                                      width: tileWidth,
                                      height: tileHeight,
                                      child: () {
                                        final i = indexFor(r, c);
                                        if (i >= count) return const SizedBox.shrink();
                                        return appTiles[i];
                                      }(),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: IconButton(
                onPressed: _openSettingsSheet,
                icon: const Icon(Icons.settings),
                color: Colors.white70,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeCustomizationScreen extends StatelessWidget {
  const HomeCustomizationScreen({super.key});

  String _themeLabel(AppThemeId id) {
    return switch (id) {
      AppThemeId.darkGreen => 'Verde (padrão)',
      AppThemeId.darkBlue => 'Azul',
      AppThemeId.light => 'Claro',
    };
  }

  String _statusLabel(StatusItemId id) {
    return switch (id) {
      StatusItemId.battery => 'Bateria',
      StatusItemId.wifi => 'Wi‑Fi',
      StatusItemId.cellular => 'Celular',
      StatusItemId.bluetooth => 'Bluetooth',
    };
  }

  String _appLabel(AppButtonId id) {
    return switch (id) {
      AppButtonId.phone => 'Telefone',
      AppButtonId.contacts => 'Contatos',
      AppButtonId.whatsapp => 'WhatsApp',
      AppButtonId.youtube => 'YouTube',
    };
  }

  IconData _appIcon(AppButtonId id) {
    return switch (id) {
      AppButtonId.phone => Icons.phone,
      AppButtonId.contacts => Icons.person,
      AppButtonId.whatsapp => FontAwesomeIcons.whatsapp,
      AppButtonId.youtube => FontAwesomeIcons.youtube,
    };
  }

  @override
  Widget build(BuildContext context) {
    final store = HomeConfigScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Personalizar',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final config = store.config;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Tema',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AppThemeId>(
                initialValue: config.themeId,
                items: [
                  for (final theme in AppThemeId.values)
                    DropdownMenuItem(
                      value: theme,
                      child: Text(
                        _themeLabel(theme),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  await store.setTheme(v);
                },
                decoration: const InputDecoration(
                  filled: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Barra de status (${config.statusItems.length}/4)',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final item in StatusItemId.values)
                SwitchListTile(
                  value: config.statusItems.contains(item),
                  onChanged: (enabled) async {
                    final ok = await store.setStatusEnabled(item, enabled);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Máximo de 4 itens na barra de status.')),
                      );
                    }
                  },
                  title: Text(
                    _statusLabel(item),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Apps (${config.appButtons.length}/8)',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final item in AppButtonId.values)
                SwitchListTile(
                  value: config.appButtons.contains(item),
                  onChanged: (enabled) async {
                    final ok = await store.setAppEnabled(item, enabled);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Máximo de 8 apps na tela inicial.')),
                      );
                    }
                  },
                  title: Text(
                    _appLabel(item),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  secondary: Icon(_appIcon(item)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BigStatusBar extends StatelessWidget {
  final List<String> items;

  const _BigStatusBar({required this.items});

  Widget _cell(String text) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = items.take(4).toList(growable: false);
    final row1 = display.isEmpty ? const ['—'] : display.take(2).toList(growable: false);
    final row2 = display.length <= 2 ? const <String>[] : display.skip(2).take(2).toList(growable: false);

    Widget buildRow(List<String> row) {
      if (row.length == 1) {
        return Row(
          children: [
            Expanded(child: _cell(row[0])),
          ],
        );
      }

      return Row(
        children: [
          Expanded(child: _cell(row[0])),
          const SizedBox(width: 12),
          Expanded(child: _cell(row[1])),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            buildRow(row1),
            if (row2.isNotEmpty) ...[
              const SizedBox(height: 10),
              buildRow(row2.length == 1 ? [row2[0]] : row2),
            ],
          ],
        ),
      ),
    );
  }
}

class _BigTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _BigTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF121212),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 64, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  String _digits = '';

  void _append(String d) {
    setState(() => _digits = (_digits + d).replaceAll(RegExp(r'\D'), ''));
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void _clear() {
    setState(() => _digits = '');
  }

  Future<void> _call() async {
    if (_digits.isEmpty) return;
    final url = Uri.parse('tel:$_digits');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _openContacts() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ContactsScreen(initialQuery: _digits)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = _digits.isEmpty ? 'Digite o número' : _digits;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Telefone',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _digits.isEmpty ? null : _clear,
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          display,
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: _digits.isEmpty ? null : _backspace,
                        icon: const Icon(Icons.backspace_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    final cols = 3;
                    final rows = 4;
                    final cellW = (width - (cols - 1) * spacing) / cols;
                    final cellH = (height - (rows - 1) * spacing) / rows;
                    final fontSize = (cellH * 0.32).clamp(22.0, 40.0);

                    Widget key(String label, VoidCallback onTap) {
                      return Material(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: onTap,
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      );
                    }

                    final keys = <Widget>[
                      key('1', () => _append('1')),
                      key('2', () => _append('2')),
                      key('3', () => _append('3')),
                      key('4', () => _append('4')),
                      key('5', () => _append('5')),
                      key('6', () => _append('6')),
                      key('7', () => _append('7')),
                      key('8', () => _append('8')),
                      key('9', () => _append('9')),
                      key('Contatos', _openContacts),
                      key('0', () => _append('0')),
                      key('Ligar', _call),
                    ];

                    int indexFor(int row, int col) => row * cols + col;

                    return Column(
                      children: [
                        for (var r = 0; r < rows; r++) ...[
                          if (r > 0) const SizedBox(height: spacing),
                          Row(
                            children: [
                              for (var c = 0; c < cols; c++) ...[
                                if (c > 0) const SizedBox(width: spacing),
                                SizedBox(
                                  width: cellW,
                                  height: cellH,
                                  child: keys[indexFor(r, c)],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContactsScreen extends StatefulWidget {
  final String initialQuery;

  const ContactsScreen({this.initialQuery = '', super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late final TextEditingController _searchController;
  bool _showDeviceContacts = false;
  bool _loadingDeviceContacts = false;
  bool _deviceContactsPermissionDenied = false;
  List<fc.Contact> _deviceContacts = const [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _loadDeviceContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeForWaMe(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return digits;
    if (digits.startsWith('55')) return digits;
    if (digits.length == 11 || digits.length == 10) return '55$digits';
    return digits;
  }

  Future<void> _openWhatsAppChat(String nationalNumber) async {
    final number = _normalizeForWaMe(nationalNumber);
    final url = Uri.parse('https://wa.me/$number');
    await launchUrl(url, mode: LaunchMode.externalApplication);
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

    final list = await fc.FlutterContacts.getContacts(withProperties: true, withPhoto: false);
    if (!mounted) return;
    setState(() {
      _deviceContacts = list;
      _loadingDeviceContacts = false;
    });
  }

  Widget _contactsModeChips() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('Celular'),
            selected: _showDeviceContacts,
            onSelected: (v) {
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
            onSelected: (v) => setState(() => _showDeviceContacts = false),
          ),
        ),
      ],
    );
  }

  Future<void> _openDeviceEditor({fc.Contact? contact}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DeviceContactEditScreen(contact: contact)),
    );
    if (saved == true) {
      await _loadDeviceContacts();
    }
  }

  Future<fc.Contact?> _getContactForUpdate(String id) async {
    return await fc.FlutterContacts.getContact(
      id,
      withProperties: true,
      withAccounts: true,
      withPhoto: true,
    );
  }

  Future<void> _toggleStar(fc.Contact contact) async {
    final full = await _getContactForUpdate(contact.id);
    if (full == null) return;
    full.isStarred = !contact.isStarred;
    await full.update();
    await _loadDeviceContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contatos',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDeviceEditor(),
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (context) {
          final q = _searchController.text.trim().toLowerCase();
          final all = _deviceContacts.where((c) {
            if (q.isEmpty) return true;
            final name = c.displayName.toLowerCase();
            if (name.contains(q)) return true;
            final phone = c.phones.isEmpty ? '' : c.phones.first.number;
            final digits = phone.replaceAll(RegExp(r'\D'), '');
            return digits.contains(q.replaceAll(RegExp(r'\D'), ''));
          }).toList(growable: false);
          final favs = all.where((c) => c.isStarred).toList(growable: false);
          final list = _showDeviceContacts ? all : favs;

          return Column(
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
                child: _DeviceContactsList(
                  loading: _loadingDeviceContacts,
                  permissionDenied: _deviceContactsPermissionDenied,
                  contacts: list,
                  onRetry: _loadDeviceContacts,
                  onCall: (phone) async {
                    final digitsOrPlus = phone.replaceAll(RegExp(r'[^0-9+]'), '');
                    if (digitsOrPlus.isEmpty) return;
                    final url = Uri.parse('tel:$digitsOrPlus');
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  },
                  onWhatsApp: (phone) => _openWhatsAppChat(phone),
                  onToggleStar: (c) => _toggleStar(c),
                  onEdit: (c) async {
                    final full = await _getContactForUpdate(c.id);
                    if (!mounted || full == null) return;
                    await _openDeviceEditor(contact: full);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceContactsList extends StatelessWidget {
  final bool loading;
  final bool permissionDenied;
  final List<fc.Contact> contacts;
  final VoidCallback onRetry;
  final Future<void> Function(String phone) onCall;
  final Future<void> Function(String phone) onWhatsApp;
  final Future<void> Function(fc.Contact contact)? onToggleStar;
  final Future<void> Function(fc.Contact contact)? onEdit;

  const _DeviceContactsList({
    required this.loading,
    required this.permissionDenied,
    required this.contacts,
    required this.onRetry,
    required this.onCall,
    required this.onWhatsApp,
    this.onToggleStar,
    this.onEdit,
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemBuilder: (context, index) {
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
                _ContactAvatar(assetPath: null),
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
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: onToggleStar == null ? null : () => onToggleStar!(c),
                            icon: Icon(c.isStarred ? Icons.star : Icons.star_border),
                          ),
                          IconButton(
                            onPressed: onEdit == null ? null : () => onEdit!(c),
                            icon: const Icon(Icons.edit),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        phone.isEmpty ? 'Sem telefone' : phone,
                        style: const TextStyle(fontSize: 18, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: phone.isEmpty ? null : () => onCall(phone),
                              icon: const Icon(Icons.phone),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: const Text(
                                  'Ligar',
                                  maxLines: 1,
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: phone.isEmpty ? null : () => onWhatsApp(phone),
                              icon: const FaIcon(FontAwesomeIcons.whatsapp),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: const Text(
                                  'WhatsApp',
                                  maxLines: 1,
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.displayName ?? '');
    _numberController = TextEditingController(text: _initialNumber(widget.contact));
    _isStarred = widget.contact?.isStarred ?? true;
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

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final digits = _numberController.text.replaceAll(RegExp(r'\D'), '');
    if (name.isEmpty || digits.isEmpty) return;

    setState(() => _saving = true);
    try {
      final phone = '+55$digits';
      if (widget.contact == null) {
        final c = fc.Contact()
          ..displayName = name
          ..isStarred = _isStarred
          ..phones = [fc.Phone(phone)];
        await c.insert();
      } else {
        final c = widget.contact!;
        c.displayName = name;
        c.isStarred = _isStarred;
        c.phones = [fc.Phone(phone)];
        await c.update();
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final c = widget.contact;
    if (c == null) return;
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
    await c.delete();
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

class ContactEditScreen extends StatefulWidget {
  final ContactEntry? entry;

  const ContactEditScreen({this.entry, super.key});

  @override
  State<ContactEditScreen> createState() => _ContactEditScreenState();
}

class _ContactEditScreenState extends State<ContactEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry?.name ?? '');
    _numberController = TextEditingController(text: widget.entry?.nationalNumber ?? '');
    _isFavorite = widget.entry?.isFavorite ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = ContactsScope.of(context);
    final name = _nameController.text.trim();
    final digits = _numberController.text.replaceAll(RegExp(r'\D'), '');
    if (name.isEmpty || digits.isEmpty) return;

    final id = widget.entry?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final entry = ContactEntry(
      id: id,
      name: name,
      nationalNumber: digits,
      isFavorite: _isFavorite,
      photoAsset: widget.entry?.photoAsset,
    );
    await store.addOrUpdate(entry);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar contato' : 'Adicionar contato',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              onPressed: _save,
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

class _ContactAvatar extends StatelessWidget {
  final String? assetPath;

  const _ContactAvatar({this.assetPath});

  @override
  Widget build(BuildContext context) {
    const size = 72.0;

    final image = assetPath == null
        ? null
        : ClipOval(
            child: Image.asset(
              assetPath!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white10,
        border: Border.all(color: Colors.white12),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: image ?? const Icon(Icons.person, size: 40, color: Colors.white70),
        ),
      ),
    );
  }
}

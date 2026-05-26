import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:velhodozap/features/contacts/contacts_screen.dart';

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
    final perm = await Permission.phone.request();
    if (!perm.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permita chamadas para ligar direto.')),
      );
      final url = Uri.parse('tel:$_digits');
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }

    final ok = await FlutterPhoneDirectCaller.callNumber(_digits);
    if (ok == true) return;
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
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: _digits.isEmpty ? null : _backspace,
                        icon: const Icon(Icons.backspace_outlined, color: Colors.white),
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
                    const cols = 3;
                    const rows = 4;
                    final cellW = (width - (cols - 1) * spacing) / cols;
                    final cellH = (height - (rows - 1) * spacing) / rows;
                    final digitFontSize = (cellH * 0.32).clamp(22.0, 40.0);
                    final iconSize = (cellH * 0.42).clamp(26.0, 54.0);

                    Widget digit(String label, VoidCallback onTap) {
                      return _DialerKey(
                        onTap: onTap,
                        child: Text(
                          label,
                          style: TextStyle(fontSize: digitFontSize, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      );
                    }

                    Widget iconKey(IconData icon, VoidCallback onTap) {
                      return _DialerKey(
                        onTap: onTap,
                        child: Icon(icon, size: iconSize, color: Colors.white),
                      );
                    }

                    final keys = <Widget>[
                      digit('1', () => _append('1')),
                      digit('2', () => _append('2')),
                      digit('3', () => _append('3')),
                      digit('4', () => _append('4')),
                      digit('5', () => _append('5')),
                      digit('6', () => _append('6')),
                      digit('7', () => _append('7')),
                      digit('8', () => _append('8')),
                      digit('9', () => _append('9')),
                      iconKey(Icons.person, _openContacts),
                      digit('0', () => _append('0')),
                      iconKey(Icons.call, _call),
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

class _DialerKey extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _DialerKey({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF121212),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Center(child: child),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

enum StatusIconId {
  battery,
  wifi,
  cellular,
  bluetooth,
}

class StatusBar extends StatelessWidget {
  final List<({StatusIconId id, String summary, List<String> details, int? batteryLevel, bool charging})> items;
  final Future<void> Function(StatusIconId id)? onOpenSettings;

  const StatusBar({
    required this.items,
    this.onOpenSettings,
    super.key,
  });

  Widget _cell(
    BuildContext context, {
    required StatusIconId id,
    required String summary,
    required List<String> details,
    required int? batteryLevel,
    required bool charging,
  }) {
    final display = id == StatusIconId.cellular ? _withBars(summary) : summary;
    final leading = switch (id) {
      StatusIconId.battery => _BatteryGlyph(level: batteryLevel, charging: charging),
      StatusIconId.wifi => const Icon(Icons.wifi, size: 22, color: Colors.white),
      StatusIconId.cellular => const Icon(Icons.phone_android, size: 22, color: Colors.white),
      StatusIconId.bluetooth => const Icon(Icons.bluetooth, size: 22, color: Colors.white),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: _HoldToAction(
          holdDuration: const Duration(seconds: 2),
          onTap: () => _showDetails(context, id: id, details: details),
          onHold: () async {
            await onOpenSettings?.call(id);
          },
          child: Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    display.isEmpty ? '—' : display,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, {required StatusIconId id, required List<String> details}) {
    final title = switch (id) {
      StatusIconId.battery => 'Bateria',
      StatusIconId.wifi => 'Wi‑Fi',
      StatusIconId.cellular => 'Celular',
      StatusIconId.bluetooth => 'Bluetooth',
    };
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in (details.isEmpty ? const ['—'] : details))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      line,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  String _withBars(String text) {
    final m = RegExp(r'(\d)\/5').firstMatch(text);
    if (m == null) return text;
    final n = int.tryParse(m.group(1) ?? '') ?? 0;
    final filled = n.clamp(0, 5);
    final bars = '▂▄▆█▇'.substring(0, filled).padRight(5, '─');
    final cleaned = text.replaceAll(RegExp(r'\s*\d\/5\s*'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return '$bars  $cleaned';
  }

  @override
  Widget build(BuildContext context) {
    final padded = items.take(4).toList(growable: false);
    while (padded.length < 4) {
      padded.add((id: StatusIconId.battery, summary: '—', details: const [], batteryLevel: null, charging: false));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final w = constraints.maxWidth;
        final cellW = (w - gap) / 2;
        const cellH = 58.0;

        return Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: cellW,
                  height: cellH,
                  child: _cell(
                    context,
                    id: padded[0].id,
                    summary: padded[0].summary,
                    details: padded[0].details,
                    batteryLevel: padded[0].batteryLevel,
                    charging: padded[0].charging,
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: cellW,
                  height: cellH,
                  child: _cell(
                    context,
                    id: padded[1].id,
                    summary: padded[1].summary,
                    details: padded[1].details,
                    batteryLevel: padded[1].batteryLevel,
                    charging: padded[1].charging,
                  ),
                ),
              ],
            ),
            const SizedBox(height: gap),
            Row(
              children: [
                SizedBox(
                  width: cellW,
                  height: cellH,
                  child: _cell(
                    context,
                    id: padded[2].id,
                    summary: padded[2].summary,
                    details: padded[2].details,
                    batteryLevel: padded[2].batteryLevel,
                    charging: padded[2].charging,
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: cellW,
                  height: cellH,
                  child: _cell(
                    context,
                    id: padded[3].id,
                    summary: padded[3].summary,
                    details: padded[3].details,
                    batteryLevel: padded[3].batteryLevel,
                    charging: padded[3].charging,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HoldToAction extends StatefulWidget {
  final Duration holdDuration;
  final VoidCallback onTap;
  final Future<void> Function() onHold;
  final Widget child;

  const _HoldToAction({
    required this.holdDuration,
    required this.onTap,
    required this.onHold,
    required this.child,
  });

  @override
  State<_HoldToAction> createState() => _HoldToActionState();
}

class _HoldToActionState extends State<_HoldToAction> {
  Timer? _timer;
  bool _held = false;

  void _startHoldTimer() {
    _timer?.cancel();
    _held = false;
    _timer = Timer(widget.holdDuration, () async {
      _held = true;
      await widget.onHold();
    });
  }

  void _cancelHoldTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancelHoldTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startHoldTimer(),
      onTapCancel: _cancelHoldTimer,
      onTapUp: (_) {
        _cancelHoldTimer();
        if (_held) return;
        widget.onTap();
      },
      child: widget.child,
    );
  }
}

class _BatteryGlyph extends StatelessWidget {
  final int? level;
  final bool charging;

  const _BatteryGlyph({required this.level, required this.charging});

  @override
  Widget build(BuildContext context) {
    final pct = (level ?? 0).clamp(0, 100);
    final fill = pct / 100.0;
    final fillColor = pct <= 15 ? Colors.redAccent : Colors.white;

    return SizedBox(
      width: 28,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            painter: _BatteryPainter(fill: fill, fillColor: fillColor),
            size: const Size(28, 18),
          ),
          if (charging)
            const Icon(
              Icons.bolt,
              size: 16,
              color: Colors.white,
            ),
        ],
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final double fill;
  final Color fillColor;

  const _BatteryPainter({required this.fill, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, 2, size.width - 4, size.height - 4);
    final cap = Rect.fromLTWH(size.width - 4, size.height / 2 - 3, 4, 6);

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(body, const Radius.circular(3));
    canvas.drawRRect(rrect, strokePaint);
    canvas.drawRect(cap, strokePaint);

    final inner = Rect.fromLTWH(body.left + 2, body.top + 2, body.width - 4, body.height - 4);
    final filled = Rect.fromLTWH(inner.left, inner.top, inner.width * fill.clamp(0.0, 1.0), inner.height);
    canvas.drawRRect(RRect.fromRectAndRadius(filled, const Radius.circular(2)), fillPaint);
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.fillColor != fillColor;
  }
}

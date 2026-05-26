import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

final class CallFormats {
  static String digitsOnly(String input) => input.replaceAll(RegExp(r'\D'), '');

  static String brDddAndNumberWithNine(String input) {
    var digits = digitsOnly(input);
    if (digits.startsWith('55')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.replaceFirst(RegExp(r'^0+'), '');

    if (digits.length == 10) {
      final ddd = digits.substring(0, 2);
      final rest = digits.substring(2);
      return '$ddd' '9$rest';
    }

    if (digits.length == 11) return digits;
    return digits;
  }

  static List<String> waE164Candidates(String input) {
    var digits = digitsOnly(input);
    if (digits.isEmpty) return const [];
    if (digits.startsWith('55')) digits = digits.substring(2);
    digits = digits.replaceFirst(RegExp(r'^0+'), '');

    final candidatesLocal = <String>{digits};
    if (digits.length == 10) {
      final ddd = digits.substring(0, 2);
      final rest = digits.substring(2);
      candidatesLocal.add('$ddd' '9$rest');
    } else if (digits.length == 11 && digits.substring(2, 3) == '9') {
      final ddd = digits.substring(0, 2);
      final rest = digits.substring(3);
      candidatesLocal.add('$ddd$rest');
    }

    return candidatesLocal
        .map((d) => digitsOnly(d))
        .where((d) => d.isNotEmpty)
        .map((d) => d.startsWith('55') ? d : '55$d')
        .toSet()
        .toList();
  }

  static String brCarrierDial015(String input) {
    var digits = digitsOnly(input);
    if (digits.startsWith('015')) return digits;
    final dddAndNumber = brDddAndNumberWithNine(digits);
    return '015$dddAndNumber';
  }

  static String waJid(String input) {
    final dddAndNumber = brDddAndNumberWithNine(input);
    final digits = digitsOnly(dddAndNumber);
    if (digits.isEmpty) return '';
    final e164 = digits.startsWith('55') ? digits : '55$digits';
    return '$e164@s.whatsapp.net';
  }

  static String waMe(String input) {
    final dddAndNumber = brDddAndNumberWithNine(input);
    final digits = digitsOnly(dddAndNumber);
    if (digits.isEmpty) return '';
    final e164 = digits.startsWith('55') ? digits : '55$digits';
    return 'https://wa.me/$e164';
  }

  static String waE164Digits(String input) {
    final dddAndNumber = brDddAndNumberWithNine(input);
    final digits = digitsOnly(dddAndNumber);
    if (digits.isEmpty) return '';
    return digits.startsWith('55') ? digits : '55$digits';
  }
}

final class Calls {
  static const _channel = MethodChannel('velhodozap/platform_intents');

  static Future<void> openWhatsAppChat(BuildContext context, {required String phoneRaw}) async {
    await _openWhatsAppChat(context, phoneRaw);
  }

  static Future<void> showCallOptions(BuildContext context, {required String phoneRaw}) async {
    final phoneDigits = CallFormats.digitsOnly(phoneRaw);
    if (phoneDigits.isEmpty) return;

    final dialogWidth = min(MediaQuery.sizeOf(context).width - 48, 420.0);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(width: dialogWidth),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ligar',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  _BigActionButton(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        FaIcon(FontAwesomeIcons.whatsapp, size: 26),
                        SizedBox(width: 10),
                        Icon(Icons.phone, size: 26),
                      ],
                    ),
                    label: 'Voz',
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _whatsAppVoice(context, phoneRaw);
                    },
                  ),
                  const SizedBox(height: 10),
                  _BigActionButton(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        FaIcon(FontAwesomeIcons.whatsapp, size: 26),
                        SizedBox(width: 10),
                        Icon(Icons.videocam, size: 26),
                      ],
                    ),
                    label: 'Vídeo',
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _whatsAppVideo(context, phoneRaw);
                    },
                  ),
                  const SizedBox(height: 10),
                  _BigActionButton(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.signal_cellular_alt, size: 26),
                        SizedBox(width: 10),
                        Icon(Icons.phone, size: 26),
                      ],
                    ),
                    label: 'Vivo',
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _callPhoneDirect(phoneRaw);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> _callPhoneDirect(String raw) async {
    final status = await Permission.phone.request();
    final dial = CallFormats.brCarrierDial015(raw);
    if (!status.isGranted) {
      final url = Uri.parse('tel:$dial');
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }

    final ok = await FlutterPhoneDirectCaller.callNumber(dial);
    if (ok != true) {
      final url = Uri.parse('tel:$dial');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _whatsAppVoice(BuildContext context, String raw) async {
    if (!Platform.isAndroid) return;
    final contacts = await Permission.contacts.request();
    if (!contacts.isGranted) {
      await _openWhatsAppChat(context, raw);
      return;
    }

    final ok = await _channel.invokeMethod<bool>('startWhatsAppCall', {
      'phoneRaw': raw,
      'isVideo': false,
    });

    if (ok != true) {
      await _openWhatsAppChat(context, raw);
    }
  }

  static Future<void> _whatsAppVideo(BuildContext context, String raw) async {
    if (!Platform.isAndroid) return;
    final contacts = await Permission.contacts.request();
    if (!contacts.isGranted) {
      await _openWhatsAppChat(context, raw);
      return;
    }

    final ok = await _channel.invokeMethod<bool>('startWhatsAppCall', {
      'phoneRaw': raw,
      'isVideo': true,
    });

    if (ok != true) {
      await _openWhatsAppChat(context, raw);
    }
  }

  static Future<void> _openWhatsAppChat(BuildContext context, String raw) async {
    if (Platform.isAndroid) {
      final ok = await _channel.invokeMethod<bool>('openWhatsAppChat', {
        'phoneRaw': raw,
      });
      if (ok == true) return;

      final tried = CallFormats.waE164Candidates(raw).map((e) => '+$e').join('\n');
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('WhatsApp'),
            content: Text(
              tried.isEmpty
                  ? 'Não foi possível encontrar este contato no WhatsApp.'
                  : 'Não foi possível encontrar este contato no WhatsApp.\n\nNúmeros testados:\n$tried',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    final e164 = CallFormats.waE164Digits(raw);
    if (e164.isEmpty) return;
    final web = Uri.parse('https://wa.me/$e164');
    await launchUrl(web, mode: LaunchMode.externalApplication);
  }
}

class _BigActionButton extends StatelessWidget {
  final Widget leading;
  final String label;
  final VoidCallback onPressed;

  const _BigActionButton({
    required this.leading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

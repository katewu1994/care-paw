import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../widgets/paw_ui.dart';

class InvitationScannerPage extends StatefulWidget {
  const InvitationScannerPage({super.key});

  @override
  State<InvitationScannerPage> createState() => _InvitationScannerPageState();
}

class _InvitationScannerPageState extends State<InvitationScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: pawInk,
    appBar: AppBar(
      foregroundColor: Colors.white,
      title: const Text('Scan invitation'),
      // This screen is dark, so the app-wide dark status-bar glyphs would
      // disappear against it.
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          onDetect: (capture) {
            if (_handled || capture.barcodes.isEmpty) return;
            final value = capture.barcodes.first.rawValue;
            if (value == null || value.isEmpty) return;
            _handled = true;
            Navigator.pop(context, value);
          },
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(PawRadius.xxl),
              ),
            ),
          ),
        ),
        const Positioned(
          left: PawSpace.xxxl,
          right: PawSpace.xxxl,
          bottom: PawSpace.xxxl + PawSpace.lg,
          child: Text(
            'Point the camera at a copaw invitation QR code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

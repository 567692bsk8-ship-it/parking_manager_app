import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrDisplayDialog extends StatelessWidget {
  final String data;
  final String title;
  final String? managerCode;

  const QrDisplayDialog({
    super.key,
    required this.data,
    required this.title,
    this.managerCode,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        title,
        style: GoogleFonts.notoSansJp(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 300,
        height: 420, // Height increased for code
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            QrImageView(
              data: data,
              version: QrVersions.auto,
              size: 250.0,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            if (managerCode != null) ...[
              Text(
                '管理コード (手入力用)',
                style: GoogleFonts.notoSansJp(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              SelectableText(
                managerCode!,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const Text(
              '利用者にこの画面を読み取ってもらってください。\nカメラが動かない場合は上記の6桁コードを伝えてください。',
              style: TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

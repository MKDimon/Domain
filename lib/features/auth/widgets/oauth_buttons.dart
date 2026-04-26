import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';

class OAuthButtons extends StatelessWidget {
  final ColorSet c;
  const OAuthButtons({super.key, required this.c});

  void _oauthLogin(String provider) {
    final url = '${AppConfig.apiBase}/auth/oauth/$provider?client=native';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // VK — #0077ff
        _OAuthBtn(
          label: 'VK',
          color: const Color(0xFF0077FF),
          textColor: Colors.white,
          icon: _vkIcon(),
          onTap: () => _oauthLogin('vk'),
        ),
        const SizedBox(height: 10),
        // Yandex — #fc3f1d
        _OAuthBtn(
          label: 'Яндекс',
          color: const Color(0xFFFC3F1D),
          textColor: Colors.white,
          icon: _yandexIcon(),
          onTap: () => _oauthLogin('yandex'),
        ),
        const SizedBox(height: 10),
        // Google — surface alt with border
        _OAuthBtn(
          label: 'Google',
          color: c.surfaceAlt,
          textColor: c.text,
          border: c.border,
          icon: _googleIcon(),
          onTap: () => _oauthLogin('google'),
        ),
        const SizedBox(height: 24),
        // Divider "или"
        Row(
          children: [
            Expanded(child: Divider(color: c.border, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('или', style: TextStyle(fontSize: 13.1, color: c.textSecondary)),
            ),
            Expanded(child: Divider(color: c.border, height: 1)),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _vkIcon() => const _SvgIcon(
    child: Text('VK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
  );

  Widget _yandexIcon() => CustomPaint(
    size: const Size(20, 20),
    painter: _YandexPainter(),
  );

  Widget _googleIcon() => CustomPaint(
    size: const Size(20, 20),
    painter: _GooglePainter(),
  );
}

class _OAuthBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final Color? border;
  final Widget icon;
  final VoidCallback onTap;

  const _OAuthBtn({
    required this.label,
    required this.color,
    required this.textColor,
    this.border,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: border != null ? Border.all(color: border!) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              'Войти через $label',
              style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w500, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _SvgIcon extends StatelessWidget {
  final Widget child;
  const _SvgIcon({required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 20, height: 20, child: Center(child: child));
  }
}

class _YandexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(13.63 / 24 * size.width, 21.0 / 24 * size.height)
      ..lineTo(13.63 / 24 * size.width, 12.86 / 24 * size.height)
      ..lineTo(17.22 / 24 * size.width, 3.0 / 24 * size.height)
      ..lineTo(14.75 / 24 * size.width, 3.0 / 24 * size.height)
      ..lineTo(12.44 / 24 * size.width, 9.34 / 24 * size.height)
      ..cubicTo(12.01 / 24 * size.width, 10.52 / 24 * size.height, 11.7 / 24 * size.width, 11.44 / 24 * size.height, 11.39 / 24 * size.width, 12.56 / 24 * size.height)
      ..cubicTo(11.08 / 24 * size.width, 11.51 / 24 * size.height, 10.71 / 24 * size.width, 10.45 / 24 * size.height, 10.31 / 24 * size.width, 9.34 / 24 * size.height)
      ..lineTo(8.07 / 24 * size.width, 3.0 / 24 * size.height)
      ..lineTo(5.5 / 24 * size.width, 3.0 / 24 * size.height)
      ..lineTo(9.19 / 24 * size.width, 12.86 / 24 * size.height)
      ..lineTo(9.19 / 24 * size.width, 21.0 / 24 * size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    // Blue
    canvas.drawPath(Path()
      ..moveTo(22.56 * s, 12.25 * s)..cubicTo(22.56 * s, 11.47 * s, 22.49 * s, 10.72 * s, 22.36 * s, 10 * s)
      ..lineTo(12 * s, 10 * s)..lineTo(12 * s, 14.26 * s)..lineTo(17.92 * s, 14.26 * s)
      ..cubicTo(17.67 * s, 15.63 * s, 16.89 * s, 16.79 * s, 15.72 * s, 17.58 * s)
      ..lineTo(15.72 * s, 17.58 * s)..lineTo(19.29 * s, 20.35 * s)
      ..cubicTo(21.37 * s, 18.43 * s, 22.56 * s, 15.61 * s, 22.56 * s, 12.25 * s)..close(),
      Paint()..color = const Color(0xFF4285F4));
    // Green
    canvas.drawPath(Path()
      ..moveTo(12 * s, 23 * s)..cubicTo(14.97 * s, 23 * s, 17.46 * s, 22.02 * s, 19.28 * s, 20.34 * s)
      ..lineTo(15.71 * s, 17.57 * s)..cubicTo(14.73 * s, 18.23 * s, 13.48 * s, 18.63 * s, 12 * s, 18.63 * s)
      ..cubicTo(9.14 * s, 18.63 * s, 6.71 * s, 16.7 * s, 5.84 * s, 14.1 * s)
      ..lineTo(2.18 * s, 16.94 * s)..cubicTo(3.99 * s, 20.53 * s, 7.7 * s, 23 * s, 12 * s, 23 * s)..close(),
      Paint()..color = const Color(0xFF34A853));
    // Yellow
    canvas.drawPath(Path()
      ..moveTo(5.84 * s, 14.09 * s)..cubicTo(5.62 * s, 13.43 * s, 5.49 * s, 12.73 * s, 5.49 * s, 12 * s)
      ..cubicTo(5.49 * s, 11.27 * s, 5.62 * s, 10.57 * s, 5.84 * s, 9.91 * s)
      ..lineTo(2.18 * s, 7.07 * s)..cubicTo(1.43 * s, 8.55 * s, 1 * s, 10.22 * s, 1 * s, 12 * s)
      ..cubicTo(1 * s, 13.78 * s, 1.43 * s, 15.45 * s, 2.18 * s, 16.93 * s)
      ..lineTo(5.84 * s, 14.09 * s)..close(),
      Paint()..color = const Color(0xFFFBBC05));
    // Red
    canvas.drawPath(Path()
      ..moveTo(12 * s, 5.38 * s)..cubicTo(13.62 * s, 5.38 * s, 15.06 * s, 5.94 * s, 16.21 * s, 7.02 * s)
      ..lineTo(19.36 * s, 3.87 * s)..cubicTo(17.45 * s, 2.09 * s, 14.97 * s, 1 * s, 12 * s, 1 * s)
      ..cubicTo(7.7 * s, 1 * s, 3.99 * s, 3.47 * s, 2.18 * s, 7.07 * s)
      ..lineTo(5.84 * s, 9.91 * s)..cubicTo(6.71 * s, 7.31 * s, 9.14 * s, 5.38 * s, 12 * s, 5.38 * s)..close(),
      Paint()..color = const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

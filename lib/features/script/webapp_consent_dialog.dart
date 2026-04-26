import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

Future<bool> showWebAppConsentDialog(BuildContext context, {required String origin}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'consent',
    barrierColor: const Color(0x80000000),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (ctx, anim, secAnim, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (ctx, anim, secAnim) => _ConsentDialog(origin: origin),
  );
  return result ?? false;
}

class _ConsentDialog extends StatelessWidget {
  final String origin;
  const _ConsentDialog({required this.origin});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 32, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // h3 — 1.1rem = 17.6px
              Text('Запрос доступа к данным', style: TextStyle(
                fontSize: 17.6, fontWeight: FontWeight.w600, color: c.text,
              )),
              const SizedBox(height: 8),
              // origin — mono, accent
              Text(origin, style: TextStyle(
                fontSize: 13, fontFamily: 'monospace', color: c.accent,
              )),
              const SizedBox(height: 12),
              // desc
              Text(
                'Это приложение запрашивает доступ к следующим данным:',
                style: TextStyle(fontSize: 14, color: c.textSecondary),
              ),
              const SizedBox(height: 12),
              // data list
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _item('Имя пользователя', c),
                    const SizedBox(height: 4),
                    _item('ID пользователя', c),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // actions — flex end, gap 8
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Отклонить'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Разрешить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(String text, ColorSet c) {
    return Row(
      children: [
        Text('•', style: TextStyle(color: c.text, fontSize: 13)),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 13, color: c.text)),
      ],
    );
  }
}

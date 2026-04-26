import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LegalScreen extends StatelessWidget {
  final String type;
  const LegalScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final title = switch (type) {
      'privacy' => 'Политика конфиденциальности',
      'terms' => 'Условия использования',
      'offer' => 'Публичная оферта',
      _ => 'Правовая информация',
    };

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text('Содержимое загружается с сервера.', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
          ),
        ),
      ),
    );
  }
}

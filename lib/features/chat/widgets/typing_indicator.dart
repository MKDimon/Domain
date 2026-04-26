import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class TypingIndicator extends StatelessWidget {
  final List<String> usernames;
  const TypingIndicator({super.key, required this.usernames});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final text = switch (usernames.length) {
      1 => l.chatTypingOne(usernames[0]),
      2 => l.chatTypingTwo(usernames[0], usernames[1]),
      _ => l.chatTypingMany(usernames[0], usernames[1], usernames.length - 2),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      alignment: Alignment.centerLeft,
      child: Text(text, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: theme.textTheme.bodySmall?.color)),
    );
  }
}

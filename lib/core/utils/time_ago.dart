String timeAgo(DateTime date, {String locale = 'en'}) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (locale == 'ru') return _timeAgoRu(diff);
  return _timeAgoEn(diff);
}

String _timeAgoEn(Duration diff) {
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo ago';
  return '${diff.inDays ~/ 365}y ago';
}

String _timeAgoRu(Duration diff) {
  if (diff.inSeconds < 60) return 'только что';
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
  if (diff.inHours < 24) return '${diff.inHours} ч. назад';
  if (diff.inDays < 7) return '${diff.inDays} дн. назад';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7} нед. назад';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30} мес. назад';
  return '${diff.inDays ~/ 365} г. назад';
}

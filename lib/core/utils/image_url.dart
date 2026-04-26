import '../config/app_config.dart';

String fullImageUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${AppConfig.uploadBase}$url';
}

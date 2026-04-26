import 'dart:convert';
import 'dart:typed_data';
import '../../core/api/api_client.dart';

class UploadResult {
  final String url;
  final String filename;

  UploadResult({required this.url, required this.filename});

  factory UploadResult.fromJson(Map<String, dynamic> json) => UploadResult(
    url: json['url'] as String,
    filename: json['filename'] as String? ?? '',
  );
}

class UploadsApi {
  final ApiClient _client;
  static const _chunkSize = 1024 * 1024; // 1 MB

  UploadsApi(this._client);

  Future<UploadResult> upload({
    required Uint8List bytes,
    required String filename,
    required String contentType,
    void Function(int percent)? onProgress,
  }) async {
    if (bytes.length > _chunkSize) {
      return uploadChunked(bytes: bytes, filename: filename, contentType: contentType, onProgress: onProgress);
    }

    onProgress?.call(0);
    final base64Data = base64Encode(bytes);
    final data = await _client.post<Map<String, dynamic>>('/uploads', data: {
      'data': base64Data,
      'filename': filename,
      'content_type': contentType,
    });
    onProgress?.call(100);
    return UploadResult.fromJson(data);
  }

  Future<UploadResult> uploadChunked({
    required Uint8List bytes,
    required String filename,
    required String contentType,
    void Function(int percent)? onProgress,
  }) async {
    final totalChunks = (bytes.length / _chunkSize).ceil();

    final initData = await _client.post<Map<String, dynamic>>('/uploads/init', data: {
      'filename': filename,
      'content_type': contentType,
      'total_size': bytes.length,
      'total_chunks': totalChunks,
    });
    final uploadId = initData['upload_id'] as String;

    try {
      for (var i = 0; i < totalChunks; i++) {
        final start = i * _chunkSize;
        final end = (start + _chunkSize).clamp(0, bytes.length);
        final chunk = bytes.sublist(start, end);
        final base64Data = base64Encode(chunk);

        await _client.post('/uploads/$uploadId/chunk', data: {
          'index': i,
          'data': base64Data,
        });

        onProgress?.call(((i + 1) / totalChunks * 100).round());
      }

      final result = await _client.post<Map<String, dynamic>>('/uploads/$uploadId/complete');
      return UploadResult.fromJson(result);
    } catch (e) {
      _client.post('/uploads/$uploadId/cancel').catchError((_) {});
      rethrow;
    }
  }
}

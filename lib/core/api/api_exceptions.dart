class ApiException implements Exception {
  final String message;
  final String? code;
  final Map<String, dynamic>? details;
  final int? statusCode;

  ApiException({
    required this.message,
    this.code,
    this.details,
    this.statusCode,
  });

  bool get isBanned => code == 'user_banned';
  bool get isMuted => code == 'user_muted';
  bool get isSanctioned => isBanned || isMuted;

  @override
  String toString() => 'ApiException($code: $message)';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException() : super(message: 'Session expired', code: 'unauthorized', statusCode: 401);
}

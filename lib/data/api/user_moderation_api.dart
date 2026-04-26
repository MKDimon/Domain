import '../../core/api/api_client.dart';

class ModerationAction {
  final int id;
  final String actionType;
  final int? severity;
  final String reason;
  final String createdAt;
  final String? expiresAt;
  final String? revokedAt;
  final String? revokeReason;
  final int? communityId;
  final String? communityName;

  ModerationAction({
    required this.id,
    required this.actionType,
    this.severity,
    required this.reason,
    required this.createdAt,
    this.expiresAt,
    this.revokedAt,
    this.revokeReason,
    this.communityId,
    this.communityName,
  });

  bool get isActive {
    if (revokedAt != null) return false;
    if (expiresAt != null) {
      try {
        return DateTime.parse(expiresAt!).isAfter(DateTime.now());
      } catch (_) {}
    }
    return actionType != 'warning';
  }

  String get statusLabel {
    if (revokedAt != null) return 'снято';
    if (expiresAt != null) {
      try {
        if (DateTime.parse(expiresAt!).isBefore(DateTime.now())) return 'истекло';
      } catch (_) {}
    }
    if (actionType == 'warning') return 'предупреждение';
    return 'активно';
  }

  factory ModerationAction.fromJson(Map<String, dynamic> json) => ModerationAction(
    id: json['id'] as int,
    actionType: json['action_type'] as String? ?? 'warning',
    severity: json['severity'] as int?,
    reason: json['reason'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    expiresAt: json['expires_at'] as String?,
    revokedAt: json['revoked_at'] as String?,
    revokeReason: json['revoke_reason'] as String?,
    communityId: json['community_id'] as int?,
    communityName: json['community_name'] as String?,
  );
}

class UserModerationApi {
  final ApiClient _client;
  UserModerationApi(this._client);

  Future<List<ModerationAction>> listOwn() async {
    final data = await _client.get<List<dynamic>>('/users/me/moderation');
    return data.map((e) => ModerationAction.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> fileAppeal(int actionId, String message) =>
      _client.post('/moderation/actions/$actionId/appeal', data: {'message': message});
}

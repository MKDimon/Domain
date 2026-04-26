class User {
  final int id;
  final String username;
  final String? displayName;
  final String email;
  final String role;
  final String avatarUrl;
  final String bio;
  final bool emailVerified;
  final String createdAt;
  final Subscription? subscription;

  User({
    required this.id,
    required this.username,
    this.displayName,
    required this.email,
    this.role = 'user',
    this.avatarUrl = '',
    this.bio = '',
    this.emailVerified = false,
    this.createdAt = '',
    this.subscription,
  });

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';
  bool get isPro => subscription?.tier == 'pro';
  String get effectiveName => (displayName?.isNotEmpty == true) ? displayName! : username;

  String get initials {
    final src = (displayName?.isNotEmpty == true ? displayName : username) ?? '';
    if (src.isEmpty) return '?';
    final parts = src.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    username: json['username'] as String,
    displayName: json['display_name'] as String?,
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'user',
    avatarUrl: json['avatar_url'] as String? ?? '',
    bio: json['bio'] as String? ?? '',
    emailVerified: json['email_verified'] as bool? ?? false,
    createdAt: json['created_at'] as String? ?? '',
    subscription: json['subscription'] != null
        ? Subscription.fromJson(json['subscription'] as Map<String, dynamic>)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'email': email,
    'role': role,
    'avatar_url': avatarUrl,
    'bio': bio,
    'email_verified': emailVerified,
    'created_at': createdAt,
    if (subscription != null) 'subscription': subscription!.toJson(),
  };

  User copyWith({
    int? id,
    String? username,
    String? displayName,
    String? email,
    String? role,
    String? avatarUrl,
    String? bio,
    bool? emailVerified,
    String? createdAt,
    Subscription? subscription,
  }) => User(
    id: id ?? this.id,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    email: email ?? this.email,
    role: role ?? this.role,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    bio: bio ?? this.bio,
    emailVerified: emailVerified ?? this.emailVerified,
    createdAt: createdAt ?? this.createdAt,
    subscription: subscription ?? this.subscription,
  );
}

class Subscription {
  final String tier;
  final String status;
  final String? trialEndsAt;
  final String? currentPeriodEnd;

  Subscription({
    required this.tier,
    required this.status,
    this.trialEndsAt,
    this.currentPeriodEnd,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    tier: json['tier'] as String? ?? 'free',
    status: json['status'] as String? ?? 'active',
    trialEndsAt: json['trial_ends_at'] as String?,
    currentPeriodEnd: json['current_period_end'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'tier': tier,
    'status': status,
    'trial_ends_at': trialEndsAt,
    'current_period_end': currentPeriodEnd,
  };
}

class PublicProfile {
  final int id;
  final String username;
  final String? displayName;
  final String avatarUrl;
  final String bio;
  final String createdAt;
  final String? lastSeenAt;
  final List<dynamic> communities;

  PublicProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl = '',
    this.bio = '',
    this.createdAt = '',
    this.lastSeenAt,
    this.communities = const [],
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    id: json['id'] as int,
    username: json['username'] as String,
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String? ?? '',
    bio: json['bio'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    lastSeenAt: json['last_seen_at'] as String?,
    communities: json['communities'] as List<dynamic>? ?? [],
  );
}

class UserSession {
  final String id;
  final String userAgent;
  final String ipAddress;
  final String createdAt;
  final String? lastUsedAt;
  final String expiresAt;

  UserSession({
    required this.id,
    required this.userAgent,
    required this.ipAddress,
    required this.createdAt,
    this.lastUsedAt,
    required this.expiresAt,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    id: json['id'] as String,
    userAgent: json['user_agent'] as String? ?? '',
    ipAddress: json['ip_address'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    lastUsedAt: json['last_used_at'] as String?,
    expiresAt: json['expires_at'] as String? ?? '',
  );
}

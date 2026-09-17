class ProfileSummary {
  final String id;
  final String displayName;

  const ProfileSummary({required this.id, required this.displayName});

  factory ProfileSummary.fromJson(Map<String, dynamic> json) {
    return ProfileSummary(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?)?.trim().isNotEmpty == true
          ? json['display_name'] as String
          : 'Anonymous',
    );
  }
}

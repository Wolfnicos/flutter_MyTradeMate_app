class AppSettings {
  final bool useTestnet;
  final String? apiKey;
  final String? apiSecret;

  const AppSettings({required this.useTestnet, this.apiKey, this.apiSecret});

  factory AppSettings.empty() => const AppSettings(useTestnet: true);

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      useTestnet: (json['useTestnet'] as bool?) ?? true,
      apiKey: json['apiKey'] as String?,
      apiSecret: json['apiSecret'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
        'useTestnet': useTestnet,
        'apiKey': apiKey,
        'apiSecret': apiSecret,
      };
}

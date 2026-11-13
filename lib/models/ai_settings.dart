/// AI Assistant Configuration (BYO Google Gemini / OpenAI key)
class AiSettings {
  final int? id;
  final String provider; // 'gemini' or 'openai'
  final String apiKey;
  final String
      modelName; // 'gemini-1.5-flash', 'gemini-1.5-pro', 'gpt-4o-mini', 'gpt-4o'
  final bool isEnabled;
  final String preferredLanguage; // 'roman_urdu', 'urdu', 'english'
  final String systemPrompt;

  AiSettings({
    this.id,
    this.provider = 'gemini',
    this.apiKey = '',
    this.modelName = 'gemini-1.5-flash',
    this.isEnabled = false,
    this.preferredLanguage = 'roman_urdu',
    this.systemPrompt = '',
  });

  bool get hasValidKey => apiKey.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'provider': provider,
        'api_key': apiKey,
        'model_name': modelName,
        'is_enabled': isEnabled ? 1 : 0,
        'preferred_language': preferredLanguage,
        'system_prompt': systemPrompt,
      };

  factory AiSettings.fromMap(Map<String, dynamic> map) => AiSettings(
        id: map['id'] as int?,
        provider: map['provider'] as String? ?? 'gemini',
        apiKey: map['api_key'] as String? ?? '',
        modelName: map['model_name'] as String? ?? 'gemini-1.5-flash',
        isEnabled: (map['is_enabled'] as int? ?? 0) == 1,
        preferredLanguage: map['preferred_language'] as String? ?? 'roman_urdu',
        systemPrompt: map['system_prompt'] as String? ?? '',
      );

  AiSettings copyWith({
    int? id,
    String? provider,
    String? apiKey,
    String? modelName,
    bool? isEnabled,
    String? preferredLanguage,
    String? systemPrompt,
  }) {
    return AiSettings(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      isEnabled: isEnabled ?? this.isEnabled,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }
}

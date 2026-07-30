class CounselingQuestion {
  final String prompt;
  final String resReq;
  final List<String> options;
  final int numberOfDays;

  final bool streakEnabled;
  final String streakTitle;
  final String streakThreshold;

  final bool tokenEnabled;
  final String tokenTitle;
  final String tokenThreshold;
  final int tokenQuantity;

  const CounselingQuestion({
    required this.prompt,
    required this.resReq,
    required this.options,
    required this.numberOfDays,
    this.streakEnabled = false,
    this.streakTitle = '',
    this.streakThreshold = 'None',
    this.tokenEnabled = false,
    this.tokenTitle = '',
    this.tokenThreshold = 'None',
    this.tokenQuantity = 0,
  });

  CounselingQuestion copyWith({
    String? prompt,
    String? resReq,
    List<String>? options,
    int? numberOfDays,
    bool? streakEnabled,
    String? streakTitle,
    String? streakThreshold,
    bool? tokenEnabled,
    String? tokenTitle,
    String? tokenThreshold,
    int? tokenQuantity,
  }) {
    return CounselingQuestion(
      prompt: prompt ?? this.prompt,
      resReq: resReq ?? this.resReq,
      options: options ?? this.options,
      numberOfDays: numberOfDays ?? this.numberOfDays,
      streakEnabled: streakEnabled ?? this.streakEnabled,
      streakTitle: streakTitle ?? this.streakTitle,
      streakThreshold: streakThreshold ?? this.streakThreshold,
      tokenEnabled: tokenEnabled ?? this.tokenEnabled,
      tokenTitle: tokenTitle ?? this.tokenTitle,
      tokenThreshold: tokenThreshold ?? this.tokenThreshold,
      tokenQuantity: tokenQuantity ?? this.tokenQuantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'resReq': resReq,
      'options': options,
      'numberOfDays': numberOfDays,
      'streakEnabled': streakEnabled,
      'streakTitle': streakTitle,
      'streakThreshold': streakThreshold,
      'tokenEnabled': tokenEnabled,
      'tokenTitle': tokenTitle,
      'tokenThreshold': tokenThreshold,
      'tokenQuantity': tokenQuantity,
    };
  }

  factory CounselingQuestion.fromJson(Map<String, dynamic> json) {
    return CounselingQuestion(
      prompt: json['prompt']?.toString() ?? '',
      resReq: json['resReq']?.toString() ?? '',
      options: json['options'] is List
          ? (json['options'] as List)
              .map((item) => item.toString())
              .toList()
          : <String>[],
      numberOfDays: _readInt(json['numberOfDays']),
      streakEnabled: _readBool(json['streakEnabled']),
      streakTitle: json['streakTitle']?.toString() ?? '',
      streakThreshold:
          json['streakThreshold']?.toString().trim().isNotEmpty == true
              ? json['streakThreshold'].toString()
              : 'None',
      tokenEnabled: _readBool(json['tokenEnabled']),
      tokenTitle: json['tokenTitle']?.toString() ?? '',
      tokenThreshold:
          json['tokenThreshold']?.toString().trim().isNotEmpty == true
              ? json['tokenThreshold'].toString()
              : 'None',
      tokenQuantity: _readInt(json['tokenQuantity']),
    );
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();

    return normalized == 'true' ||
        normalized == 'yes' ||
        normalized == '1';
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
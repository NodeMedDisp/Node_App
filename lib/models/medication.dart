class Medication {
  final String name;
  final String dose;
  final String frequency;
  final String times;
  final int numDays;

  final bool streakEnabled;
  final String streakTitle;
  final String streakThreshold;

  final bool tokenEnabled;
  final String tokenTitle;
  final String tokenThreshold;
  final int tokenQuantity;

  const Medication({
    required this.name,
    required this.dose,
    required this.frequency,
    required this.times,
    required this.numDays,
    this.streakEnabled = false,
    this.streakTitle = '',
    this.streakThreshold = 'None',
    this.tokenEnabled = false,
    this.tokenTitle = '',
    this.tokenThreshold = 'None',
    this.tokenQuantity = 0,
  });

  Medication copyWith({
    String? name,
    String? dose,
    String? frequency,
    String? times,
    int? numDays,
    bool? streakEnabled,
    String? streakTitle,
    String? streakThreshold,
    bool? tokenEnabled,
    String? tokenTitle,
    String? tokenThreshold,
    int? tokenQuantity,
  }) {
    return Medication(
      name: name ?? this.name,
      dose: dose ?? this.dose,
      frequency: frequency ?? this.frequency,
      times: times ?? this.times,
      numDays: numDays ?? this.numDays,
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
      'name': name,
      'dose': dose,
      'frequency': frequency,
      'times': times,
      'numDays': numDays,
      'streakEnabled': streakEnabled,
      'streakTitle': streakTitle,
      'streakThreshold': streakThreshold,
      'tokenEnabled': tokenEnabled,
      'tokenTitle': tokenTitle,
      'tokenThreshold': tokenThreshold,
      'tokenQuantity': tokenQuantity,
    };
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      name: json['name']?.toString() ?? '',
      dose: json['dose']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      times: json['times']?.toString() ?? '',
      numDays: _readInt(json['numDays']),
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
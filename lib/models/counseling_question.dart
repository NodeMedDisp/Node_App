class CounselingQuestion {
  final String prompt;
  final String resReq;
  final List<String> options;
  final int numberOfDays;

  const CounselingQuestion({
    required this.prompt,
    required this.resReq,
    required this.options,
    required this.numberOfDays,
  });

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'resReq': resReq,
      'options': options,
      'numberOfDays': numberOfDays,
    };
  }

  factory CounselingQuestion.fromJson(Map<String, dynamic> json) {
    return CounselingQuestion(
      prompt: json['prompt']?.toString() ?? '',
      resReq: json['resReq']?.toString() ?? '',
      options: json['options'] is List
          ? (json['options'] as List).map((item) => item.toString()).toList()
          : <String>[],
      numberOfDays: json['numberOfDays'] is int
          ? json['numberOfDays'] as int
          : int.tryParse(json['numberOfDays']?.toString() ?? '') ?? 0,
    );
  }
}
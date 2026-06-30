class Medication {
  final String name;
  final String dose;
  final String frequency;
  final String times;
  final int numDays;

  const Medication({
    required this.name,
    required this.dose,
    required this.frequency,
    required this.times,
    required this.numDays,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dose': dose,
      'frequency': frequency,
      'times': times,
      'numDays': numDays,
    };
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      name: json['name']?.toString() ?? '',
      dose: json['dose']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      times: json['times']?.toString() ?? '',
      numDays: json['numDays'] is int
          ? json['numDays'] as int
          : int.tryParse(json['numDays']?.toString() ?? '') ?? 0,
    );
  }
}
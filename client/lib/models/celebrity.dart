class Celebrity {
  final String name;
  final String firstInitial;
  final String lastInitial;
  final String occupation;
  final int? birthYear;
  final double hpi;
  final String? wikiUrl;

  const Celebrity({
    required this.name,
    required this.firstInitial,
    required this.lastInitial,
    required this.occupation,
    this.birthYear,
    required this.hpi,
    this.wikiUrl,
  });

  factory Celebrity.fromJson(Map<String, dynamic> json) => Celebrity(
        name: json['name'] as String,
        firstInitial: json['firstInitial'] as String,
        lastInitial: json['lastInitial'] as String,
        occupation: json['occupation'] as String,
        birthYear: json['birthYear'] as int?,
        hpi: (json['hpi'] as num).toDouble(),
      );

  String get pairKey => '$firstInitial$lastInitial';

  @override
  String toString() => '$name ($pairKey)';

  @override
  bool operator ==(Object other) =>
      other is Celebrity &&
      other.name == name &&
      other.firstInitial == firstInitial &&
      other.lastInitial == lastInitial;

  @override
  int get hashCode => Object.hash(name, firstInitial, lastInitial);
}

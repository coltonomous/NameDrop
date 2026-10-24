class Celebrity {
  final String name;
  final String firstInitial;
  final String lastInitial;
  final String occupation;
  final int? birthYear;
  final double hpi;

  /// Average daily English Wikipedia page views (0 if unknown).
  final int views;
  final String? wikiUrl;

  const Celebrity({
    required this.name,
    required this.firstInitial,
    required this.lastInitial,
    required this.occupation,
    this.birthYear,
    required this.hpi,
    this.views = 0,
    this.wikiUrl,
  });

  factory Celebrity.fromJson(Map<String, dynamic> json) => Celebrity(
        name: json['name'] as String,
        firstInitial: json['firstInitial'] as String,
        lastInitial: json['lastInitial'] as String,
        occupation: json['occupation'] as String,
        birthYear: json['birthYear'] as int?,
        hpi: (json['hpi'] as num).toDouble(),
        views: (json['views'] as num?)?.toInt() ?? 0,
        wikiUrl: json['wikiUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'firstInitial': firstInitial,
        'lastInitial': lastInitial,
        'occupation': occupation,
        'birthYear': birthYear,
        'hpi': hpi,
        'views': views,
        'wikiUrl': wikiUrl,
      };

  String get pairKey => '$firstInitial$lastInitial';

  /// Has some measure of fame. Active-roster athletes from ESPN have neither
  /// score until the list is rebuilt with page views.
  bool get isWellKnown => views > 0 || hpi > 0;

  /// Most famous first: English Wikipedia views, then Pantheon's score.
  static int byFame(Celebrity a, Celebrity b) {
    final byViews = b.views.compareTo(a.views);
    return byViews != 0 ? byViews : b.hpi.compareTo(a.hpi);
  }

  Celebrity withWikiUrl(String url) => Celebrity(
        name: name,
        firstInitial: firstInitial,
        lastInitial: lastInitial,
        occupation: occupation,
        birthYear: birthYear,
        hpi: hpi,
        views: views,
        wikiUrl: url,
      );

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

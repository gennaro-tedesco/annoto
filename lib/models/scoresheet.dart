class Scoresheet {
  const Scoresheet({
    required this.id,
    required this.filename,
    required this.createdAt,
    required this.pgn,
    required this.gameCount,
  });

  final String id;
  final String filename;
  final DateTime createdAt;
  final String pgn;
  final int gameCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'filename': filename,
    'createdAt': createdAt.toIso8601String(),
    'gameCount': gameCount,
  };

  static Scoresheet fromJson(
    Map<String, dynamic> json,
    String pgn,
    int gameCount,
  ) => Scoresheet(
    id: json['id'] as String,
    filename: json['filename'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    pgn: pgn,
    gameCount: gameCount,
  );
}

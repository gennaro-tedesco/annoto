class Scoresheet {
  const Scoresheet({
    required this.id,
    required this.filename,
    required this.createdAt,
    required this.pgn,
  });

  final String id;
  final String filename;
  final DateTime createdAt;
  final String pgn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'filename': filename,
    'createdAt': createdAt.toIso8601String(),
  };

  static Scoresheet fromJson(Map<String, dynamic> json, String pgn) =>
      Scoresheet(
        id: json['id'] as String,
        filename: json['filename'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        pgn: pgn,
      );
}

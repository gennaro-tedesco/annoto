class ExplorerMove {
  const ExplorerMove({
    required this.uci,
    required this.san,
    required this.white,
    required this.draws,
    required this.black,
    required this.averageRating,
  });

  final String uci;
  final String san;
  final int white;
  final int draws;
  final int black;
  final int averageRating;

  factory ExplorerMove.fromJson(Map<String, dynamic> json) => ExplorerMove(
    uci: json['uci'] as String? ?? '',
    san: json['san'] as String? ?? '',
    white: (json['white'] as num?)?.toInt() ?? 0,
    draws: (json['draws'] as num?)?.toInt() ?? 0,
    black: (json['black'] as num?)?.toInt() ?? 0,
    averageRating: (json['averageRating'] as num?)?.toInt() ?? 0,
  );
}

class ExplorerGame {
  const ExplorerGame({
    required this.id,
    required this.winner,
    required this.white,
    required this.black,
    required this.year,
    required this.month,
  });

  final String id;
  final String? winner;
  final ({String name, int rating}) white;
  final ({String name, int rating}) black;
  final int year;
  final String month;

  factory ExplorerGame.fromJson(Map<String, dynamic> json) {
    final w = json['white'] as Map<String, dynamic>? ?? const {};
    final b = json['black'] as Map<String, dynamic>? ?? const {};
    return ExplorerGame(
      id: json['id'] as String? ?? '',
      winner: json['winner'] as String?,
      white: (
        name: w['name'] as String? ?? '',
        rating: (w['rating'] as num?)?.toInt() ?? 0,
      ),
      black: (
        name: b['name'] as String? ?? '',
        rating: (b['rating'] as num?)?.toInt() ?? 0,
      ),
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: json['month'] as String? ?? '',
    );
  }
}

class ExplorerResult {
  const ExplorerResult({
    required this.white,
    required this.draws,
    required this.black,
    required this.moves,
    required this.topGames,
    this.opening,
  });

  final int white;
  final int draws;
  final int black;
  final List<ExplorerMove> moves;
  final List<ExplorerGame> topGames;
  final ({String eco, String name})? opening;

  factory ExplorerResult.fromJson(Map<String, dynamic> json) {
    final openingJson = json['opening'] as Map<String, dynamic>?;
    return ExplorerResult(
      white: (json['white'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      black: (json['black'] as num?)?.toInt() ?? 0,
      moves: (json['moves'] as List? ?? const [])
          .map((m) => ExplorerMove.fromJson(m as Map<String, dynamic>))
          .where((m) => m.uci.isNotEmpty && m.san.isNotEmpty)
          .toList(),
      topGames: (json['topGames'] as List? ?? const [])
          .map((g) => ExplorerGame.fromJson(g as Map<String, dynamic>))
          .toList(),
      opening: openingJson != null
          ? (
              eco: openingJson['eco'] as String? ?? '',
              name: openingJson['name'] as String? ?? '',
            )
          : null,
    );
  }
}

import 'package:dartchess/dartchess.dart';

List<bool> validateMoves(List<String> sans) {
  var position = Chess.initial;
  final validity = <bool>[];
  var foundInvalidMove = false;

  for (final san in sans) {
    if (foundInvalidMove) {
      validity.add(false);
      continue;
    }

    final move = position.parseSan(san);
    if (move == null) {
      validity.add(false);
      foundInvalidMove = true;
      continue;
    }

    validity.add(true);
    position = position.play(move);
  }

  return validity;
}

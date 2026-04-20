import 'package:dartchess/dartchess.dart';

List<bool> validateMoves(List<String> sans) {
  Position<Chess> position = Chess.initial;
  final validity = <bool>[];
  var foundInvalidMove = false;

  for (final san in sans) {
    if (foundInvalidMove || san.isEmpty) {
      validity.add(false);
      foundInvalidMove = true;
      continue;
    }

    final Move? move;
    try {
      move = position.parseSan(san);
    } catch (_) {
      validity.add(false);
      foundInvalidMove = true;
      continue;
    }
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

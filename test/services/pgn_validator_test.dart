import 'package:annoto/services/pgn_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateMoves', () {
    test('marks all legal plies as valid', () {
      final validity = validateMoves(['e4', 'e5', 'Nf3', 'Nc6']);

      expect(validity, [true, true, true, true]);
    });

    test('marks first invalid ply and all following plies as invalid', () {
      final validity = validateMoves(['e4', 'e5', 'InvalidMove', 'Nc6']);

      expect(validity, [true, true, false, false]);
    });
  });
}

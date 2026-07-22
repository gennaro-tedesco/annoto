import 'dart:typed_data';

import 'package:annoto/services/gif_export_service.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('mainlineFens', () {
    test('includes the starting position followed by one FEN per move', () {
      final fens = mainlineFens(Chess.initial, ['e4', 'e5', 'Nf3']);
      expect(fens.length, 4);
      expect(
        fens.first,
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );
      expect(fens[1], startsWith('rnbqkbnr/pppppppp/8/8/4P3/8'));
    });

    test('stops at the first illegal move', () {
      final fens = mainlineFens(Chess.initial, ['e4', 'Nz9', 'Nf3']);
      expect(fens.length, 2);
    });

    test('stops at the first empty move', () {
      final fens = mainlineFens(Chess.initial, ['e4', '', 'Nf3']);
      expect(fens.length, 2);
    });

    test('returns just the starting position for no moves', () {
      final fens = mainlineFens(Chess.initial, []);
      expect(fens.length, 1);
    });

    test(
      'honors a custom starting position instead of assuming Chess.initial',
      () {
        const customFen =
            'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';
        final start = Chess.fromSetup(Setup.parseFen(customFen));

        final fens = mainlineFens(start, ['Nf3', 'Nc6']);

        expect(fens.length, 3);
        expect(fens.first, start.fen);
        expect(fens[1], isNot(startsWith('rnbqkbnr/pppppppp')));
      },
    );
  });

  group('capGifFrames', () {
    test('returns the list unchanged when within the limit', () {
      final fens = List.generate(5, (i) => 'fen-$i');
      expect(capGifFrames(fens, maxFrames: 10), fens);
    });

    test('subsamples down to maxFrames, keeping the first and last', () {
      final fens = List.generate(1000, (i) => 'fen-$i');
      final capped = capGifFrames(fens, maxFrames: 200);

      expect(capped.length, 200);
      expect(capped.first, fens.first);
      expect(capped.last, fens.last);
    });

    test('returns just the last frame when maxFrames is 1', () {
      final fens = List.generate(5, (i) => 'fen-$i');
      expect(capGifFrames(fens, maxFrames: 1), [fens.last]);
    });
  });

  group('encodeGifFrames', () {
    Uint8List framePng() {
      final image = img.Image(width: 4, height: 4);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      return img.encodePng(image);
    }

    test('encodes a valid animated GIF from PNG frames', () {
      final frames = [framePng(), framePng()];
      final gif = encodeGifFrames((frames: frames, frameDuration: 60));
      expect(gif, isNotNull);
      expect(String.fromCharCodes(gif!.take(3)), 'GIF');
    });

    test('returns null when given no frames', () {
      expect(encodeGifFrames((frames: [], frameDuration: 60)), isNull);
    });

    test('preserves every input frame, including the first', () {
      final frames = [framePng(), framePng(), framePng()];
      final gif = encodeGifFrames((frames: frames, frameDuration: 60));
      final decoded = img.decodeGif(gif!)!;
      expect(decoded.numFrames, frames.length);
    });
  });
}

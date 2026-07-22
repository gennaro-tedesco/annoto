import 'dart:typed_data';

import 'package:annoto/services/gif_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('mainlineFens', () {
    test('includes the starting position followed by one FEN per move', () {
      final fens = mainlineFens(['e4', 'e5', 'Nf3']);
      expect(fens.length, 4);
      expect(
        fens.first,
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );
      expect(fens[1], startsWith('rnbqkbnr/pppppppp/8/8/4P3/8'));
    });

    test('stops at the first illegal move', () {
      final fens = mainlineFens(['e4', 'Nz9', 'Nf3']);
      expect(fens.length, 2);
    });

    test('stops at the first empty move', () {
      final fens = mainlineFens(['e4', '', 'Nf3']);
      expect(fens.length, 2);
    });

    test('returns just the starting position for no moves', () {
      final fens = mainlineFens([]);
      expect(fens.length, 1);
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
  });
}

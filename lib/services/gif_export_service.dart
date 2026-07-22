import 'dart:typed_data';

import 'package:dartchess/dartchess.dart';
import 'package:image/image.dart' as img;

List<String> mainlineFens(List<String> sans) {
  Position position = Chess.initial;
  final fens = <String>[position.fen];

  for (final san in sans) {
    if (san.isEmpty) break;

    final Move? move;
    try {
      move = position.parseSan(san);
    } catch (_) {
      break;
    }
    if (move == null) break;

    position = position.play(move);
    fens.add(position.fen);
  }

  return fens;
}

typedef GifEncodeInput = ({List<Uint8List> frames, int frameDuration});

Uint8List? encodeGifFrames(GifEncodeInput input) {
  final images = input.frames
      .map(img.decodePng)
      .whereType<img.Image>()
      .toList();
  if (images.isEmpty) return null;

  final quantizer = img.NeuralQuantizer(images.first);
  final encoder = img.GifEncoder(repeat: 0);
  for (final image in images) {
    final paletted = img.ditherImage(image, quantizer: quantizer);
    encoder.addFrame(paletted, duration: input.frameDuration);
  }
  return encoder.finish();
}

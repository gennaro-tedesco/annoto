import 'dart:typed_data';

import 'package:dartchess/dartchess.dart';
import 'package:image/image.dart' as img;

List<String> mainlineFens(Position start, List<String> sans) {
  Position position = start;
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

const maxGifFrames = 200;

List<String> capGifFrames(List<String> fens, {int maxFrames = maxGifFrames}) {
  if (fens.length <= maxFrames) return fens;
  if (maxFrames <= 1) return [fens.last];

  return [
    for (var i = 0; i < maxFrames; i++)
      fens[(i * (fens.length - 1) / (maxFrames - 1)).round()],
  ];
}

typedef GifEncodeInput = ({List<Uint8List> frames, int frameDuration});

Uint8List? encodeGifFrames(GifEncodeInput input) {
  if (input.frames.isEmpty) return null;

  final firstImage = img.decodePng(input.frames.first);
  if (firstImage == null) return null;

  final quantizer = img.NeuralQuantizer(firstImage);
  final encoder = img.GifEncoder(repeat: 0);
  encoder.addFrame(
    img.ditherImage(firstImage, quantizer: quantizer),
    duration: input.frameDuration,
  );

  for (final png in input.frames.skip(1)) {
    final image = img.decodePng(png);
    if (image == null) continue;
    encoder.addFrame(
      img.ditherImage(image, quantizer: quantizer),
      duration: input.frameDuration,
    );
  }
  return encoder.finish();
}

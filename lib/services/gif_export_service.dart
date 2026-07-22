import 'dart:isolate';
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

typedef GifEncodeRequest = ({
  SendPort progressPort,
  List<Uint8List> frames,
  int frameDuration,
});

/// Isolate entry point. Sends a `double` (0..1) after each encoded frame,
/// then sends the final `Uint8List?` result once encoding is complete.
void runGifEncoding(GifEncodeRequest request) {
  final frames = request.frames;
  final total = frames.length;

  if (total == 0) {
    request.progressPort.send(null);
    return;
  }

  final firstImage = img.decodePng(frames.first);
  if (firstImage == null) {
    request.progressPort.send(null);
    return;
  }

  final quantizer = img.NeuralQuantizer(firstImage);
  final encoder = img.GifEncoder(repeat: 0);
  encoder.addFrame(
    img.ditherImage(firstImage, quantizer: quantizer),
    duration: request.frameDuration,
  );
  request.progressPort.send(1 / total);

  for (var i = 1; i < total; i++) {
    final image = img.decodePng(frames[i]);
    if (image != null) {
      encoder.addFrame(
        img.ditherImage(image, quantizer: quantizer),
        duration: request.frameDuration,
      );
    }
    request.progressPort.send((i + 1) / total);
  }

  request.progressPort.send(encoder.finish());
}

import 'package:annoto/app/app_state.dart';

enum UploadSource { camera, gallery, fileSystem }

enum JobStatus { uploaded, processing, needsReview, validated, failed }

class UploadItem {
  const UploadItem({
    required this.id,
    required this.fileName,
    required this.source,
    required this.status,
  });

  final String id;
  final String fileName;
  final UploadSource source;
  final JobStatus status;
}

class ValidationContext {
  const ValidationContext({required this.moveNumber, required this.side});

  final int moveNumber;
  final String side;
}

class ValidationResult {
  const ValidationResult({
    required this.valid,
    this.firstInvalidPly,
    this.message,
    this.context,
  });

  final bool valid;
  final int? firstInvalidPly;
  final String? message;
  final ValidationContext? context;
}

class ExtractionJob {
  const ExtractionJob({
    required this.id,
    required this.status,
    required this.provider,
    required this.upload,
    this.validationResult,
  });

  final String id;
  final JobStatus status;
  final AiProvider provider;
  final UploadItem upload;
  final ValidationResult? validationResult;
}

class GameRecord {
  const GameRecord({
    required this.id,
    required this.title,
    required this.pgn,
    required this.status,
  });

  final String id;
  final String title;
  final String pgn;
  final JobStatus status;
}

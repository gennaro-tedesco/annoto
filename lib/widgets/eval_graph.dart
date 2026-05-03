import 'package:annoto/services/chess_engine_service.dart';
import 'package:flutter/material.dart';

class EvalGraph extends StatelessWidget {
  const EvalGraph({
    super.key,
    required this.evaluations,
    required this.totalPlies,
    required this.activePly,
    required this.onTapPly,
  });

  final List<EngineEvaluation?> evaluations;
  final int totalPlies;
  final int activePly;
  final void Function(int ply) onTapPly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (details) {
        if (totalPlies == 0) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final localX = details.localPosition.dx;
        final maxPly = totalPlies < evaluations.length
            ? totalPlies
            : evaluations.length;
        if (maxPly == 0) return;
        final step = box.size.width / totalPlies;
        int? nearestPly;
        double? nearestDistance;
        for (int i = 0; i < maxPly; i++) {
          if (evaluations[i] == null) continue;
          final x = i * step + step / 2;
          final distance = (localX - x).abs();
          if (nearestDistance == null || distance < nearestDistance) {
            nearestPly = i;
            nearestDistance = distance;
          }
        }
        if (nearestPly == null) return;
        onTapPly(nearestPly);
      },
      child: CustomPaint(
        painter: _EvalGraphPainter(
          evaluations: evaluations,
          totalPlies: totalPlies,
          activePly: activePly,
          theme: theme,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _EvalGraphPainter extends CustomPainter {
  _EvalGraphPainter({
    required this.evaluations,
    required this.totalPlies,
    required this.activePly,
    required this.theme,
  });

  final List<EngineEvaluation?> evaluations;
  final int totalPlies;
  final int activePly;
  final ThemeData theme;

  static const int _maxCp = 700;
  static const double _padding = 4.0;
  static const double _labelPaddingHorizontal = 6.0;
  static const double _labelPaddingVertical = 3.0;
  static const double _labelBorderRadius = 6.0;
  static const double _labelPointGap = 6.0;
  static const double _labelFontSize = 11.0;
  static const double _activePointRadius = 3.0;

  double _cpToY(double height, int? cp, int? mate, int scaleRange) {
    final mid = height / 2;
    final usableHeight = height / 2 - _padding;
    if (mate != null) {
      return mate > 0 ? _padding : height - _padding;
    }
    if (cp != null) {
      final clamped = cp.clamp(-scaleRange, scaleRange);
      return mid - (clamped / scaleRange) * usableHeight;
    }
    return mid;
  }

  String? _evaluationText(EngineEvaluation? eval) {
    if (eval == null) return null;
    final mate = eval.mate;
    if (mate != null) return '#$mate';
    final cp = eval.cp;
    if (cp == null) return null;
    final pawns = cp / 100.0;
    return pawns >= 0
        ? '+${pawns.toStringAsFixed(2)}'
        : pawns.toStringAsFixed(2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (totalPlies == 0) return;

    final width = size.width;
    final height = size.height;
    final mid = height / 2;
    final step = width / totalPlies;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = theme.scaffoldBackgroundColor,
    );

    int maxAbsCp = 0;
    for (final eval in evaluations) {
      if (eval == null) continue;
      if (eval.mate != null) {
        maxAbsCp = _maxCp;
        break;
      }
      if (eval.cp != null) {
        maxAbsCp = maxAbsCp > eval.cp!.abs() ? maxAbsCp : eval.cp!.abs();
      }
    }
    final scaleRange = maxAbsCp < 300
        ? 300
        : (maxAbsCp > _maxCp ? _maxCp : maxAbsCp);

    canvas.drawLine(
      Offset(0, mid),
      Offset(width, mid),
      Paint()
        ..color = theme.colorScheme.outline.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );

    final points = <(int ply, Offset point, bool isWhite)>[];
    for (int i = 0; i < totalPlies; i++) {
      final eval = i < evaluations.length ? evaluations[i] : null;
      if (eval == null) continue;
      final x = i * step + step / 2;
      final y = _cpToY(height, eval.cp, eval.mate, scaleRange);
      points.add((i, Offset(x, y), y < mid));
    }

    if (points.isEmpty) return;

    final whitePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final blackPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      final (ply1, p1, isWhite1) = points[i];
      final (ply2, p2, isWhite2) = points[i + 1];
      if (ply2 != ply1 + 1) continue;

      if (isWhite1 == isWhite2) {
        canvas.drawLine(p1, p2, isWhite1 ? whitePaint : blackPaint);
      } else {
        final t = (p1.dy - mid) / (p1.dy - p2.dy);
        final crossPoint = Offset(p1.dx + t * (p2.dx - p1.dx), mid);
        canvas.drawLine(p1, crossPoint, isWhite1 ? whitePaint : blackPaint);
        canvas.drawLine(crossPoint, p2, isWhite2 ? whitePaint : blackPaint);
      }
    }

    final pointPaint = Paint();
    for (final (_, p, isWhite) in points) {
      pointPaint.color = isWhite ? Colors.white : Colors.black87;
      canvas.drawCircle(p, 1.5, pointPaint);
    }

    final whiteFill = Path();
    final blackFill = Path();

    for (int i = 0; i < points.length - 1; i++) {
      final (ply1, p1, isWhite1) = points[i];
      final (ply2, p2, isWhite2) = points[i + 1];
      if (ply2 != ply1 + 1) continue;

      if (isWhite1 == isWhite2) {
        final path = isWhite1 ? whiteFill : blackFill;
        path.moveTo(p1.dx, mid);
        path.lineTo(p1.dx, p1.dy);
        path.lineTo(p2.dx, p2.dy);
        path.lineTo(p2.dx, mid);
        path.close();
      } else {
        final t = (p1.dy - mid) / (p1.dy - p2.dy);
        final crossPoint = Offset(p1.dx + t * (p2.dx - p1.dx), mid);

        final path1 = isWhite1 ? whiteFill : blackFill;
        path1.moveTo(p1.dx, mid);
        path1.lineTo(p1.dx, p1.dy);
        path1.lineTo(crossPoint.dx, crossPoint.dy);
        path1.close();

        final path2 = isWhite2 ? whiteFill : blackFill;
        path2.moveTo(crossPoint.dx, mid);
        path2.lineTo(crossPoint.dx, crossPoint.dy);
        path2.lineTo(p2.dx, p2.dy);
        path2.lineTo(p2.dx, mid);
        path2.close();
      }
    }

    canvas.drawPath(
      whiteFill,
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
    canvas.drawPath(
      blackFill,
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );

    if (activePly >= 0 && activePly < totalPlies) {
      final cursorX = activePly * step + step / 2;
      final eval = activePly < evaluations.length
          ? evaluations[activePly]
          : null;
      canvas.drawLine(
        Offset(cursorX, 0),
        Offset(cursorX, height),
        Paint()
          ..color = theme.colorScheme.primary
          ..strokeWidth = 2,
      );

      if (eval != null) {
        final point = Offset(
          cursorX,
          _cpToY(height, eval.cp, eval.mate, scaleRange),
        );
        canvas.drawCircle(
          point,
          _activePointRadius,
          Paint()..color = theme.colorScheme.primary,
        );

        final label = _evaluationText(eval);
        if (label != null) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontSize: _labelFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final labelWidth = textPainter.width + _labelPaddingHorizontal * 2;
          final labelHeight = textPainter.height + _labelPaddingVertical * 2;
          final preferredLeft = point.dx + _labelPointGap;
          final left = preferredLeft + labelWidth <= width - _padding
              ? preferredLeft
              : point.dx - _labelPointGap - labelWidth;
          final top = (point.dy - labelHeight / 2).clamp(
            _padding,
            height - labelHeight - _padding,
          );
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, labelWidth, labelHeight),
            const Radius.circular(_labelBorderRadius),
          );
          canvas.drawRRect(rect, Paint()..color = theme.colorScheme.primary);
          textPainter.paint(
            canvas,
            Offset(left + _labelPaddingHorizontal, top + _labelPaddingVertical),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_EvalGraphPainter old) =>
      old.evaluations != evaluations ||
      old.totalPlies != totalPlies ||
      old.activePly != activePly ||
      old.theme != theme;
}

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
        final ply = ((localX / box.size.width) * totalPlies).floor().clamp(
          0,
          totalPlies - 1,
        );
        onTapPly(ply);
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

  @override
  void paint(Canvas canvas, Size size) {
    if (totalPlies == 0) return;

    final width = size.width;
    final height = size.height;
    final mid = height / 2;
    final step = width / totalPlies;

    final bgPaint = Paint()..color = theme.scaffoldBackgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // Find the actual max evaluation in this game for dynamic scaling
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
    // Use at least 300cp range so small evaluations are still visible
    final scaleRange = maxAbsCp < 300 ? 300 : (maxAbsCp > _maxCp ? _maxCp : maxAbsCp);

    final centerLinePaint = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, mid), Offset(width, mid), centerLinePaint);

    // Build list of valid (ply, point) pairs
    final points = <(int ply, Offset point, bool isWhite)>[];
    for (int i = 0; i < totalPlies; i++) {
      final eval = i < evaluations.length ? evaluations[i] : null;
      if (eval == null) continue;

      final x = i * step + step / 2;
      final y = _cpToY(height, eval.cp, eval.mate, scaleRange);
      points.add((i, Offset(x, y), y < mid));
    }

    if (points.isEmpty) return;

    // Draw line segments - split at center line when crossing
    for (int i = 0; i < points.length - 1; i++) {
      final (ply1, p1, isWhite1) = points[i];
      final (ply2, p2, isWhite2) = points[i + 1];

      // Only connect consecutive plies
      if (ply2 != ply1 + 1) continue;

      if (isWhite1 == isWhite2) {
        // Same color - draw single segment
        final linePaint = Paint()
          ..color = isWhite1 ? Colors.white : Colors.black87
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p1, p2, linePaint);
      } else {
        // Crossing the center - find intersection point and draw two segments
        final t = (p1.dy - mid) / (p1.dy - p2.dy);
        final crossX = p1.dx + t * (p2.dx - p1.dx);
        final crossPoint = Offset(crossX, mid);

        final firstPaint = Paint()
          ..color = isWhite1 ? Colors.white : Colors.black87
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        final secondPaint = Paint()
          ..color = isWhite2 ? Colors.white : Colors.black87
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(p1, crossPoint, firstPaint);
        canvas.drawLine(crossPoint, p2, secondPaint);
      }
    }

    // Draw points
    final pointPaint = Paint();
    for (final (_, p, isWhite) in points) {
      pointPaint.color = isWhite ? Colors.white : Colors.black87;
      canvas.drawCircle(p, 1.5, pointPaint);
    }

    // Fill area under the graph - split at center when crossing
    for (int i = 0; i < points.length - 1; i++) {
      final (ply1, p1, isWhite1) = points[i];
      final (ply2, p2, isWhite2) = points[i + 1];

      if (ply2 != ply1 + 1) continue;

      if (isWhite1 == isWhite2) {
        // Same color - single fill
        final fillPaint = Paint()
          ..color = (isWhite1 ? Colors.white : Colors.black).withValues(alpha: 0.15);

        final fillPath = Path();
        fillPath.moveTo(p1.dx, mid);
        fillPath.lineTo(p1.dx, p1.dy);
        fillPath.lineTo(p2.dx, p2.dy);
        fillPath.lineTo(p2.dx, mid);
        fillPath.close();

        canvas.drawPath(fillPath, fillPaint);
      } else {
        // Crossing the center - find intersection and split fill
        final t = (p1.dy - mid) / (p1.dy - p2.dy);
        final crossX = p1.dx + t * (p2.dx - p1.dx);
        final crossPoint = Offset(crossX, mid);

        // First segment fill
        final fillPaint1 = Paint()
          ..color = (isWhite1 ? Colors.white : Colors.black).withValues(alpha: 0.15);
        final fillPath1 = Path();
        fillPath1.moveTo(p1.dx, mid);
        fillPath1.lineTo(p1.dx, p1.dy);
        fillPath1.lineTo(crossPoint.dx, crossPoint.dy);
        fillPath1.close();
        canvas.drawPath(fillPath1, fillPaint1);

        // Second segment fill
        final fillPaint2 = Paint()
          ..color = (isWhite2 ? Colors.white : Colors.black).withValues(alpha: 0.15);
        final fillPath2 = Path();
        fillPath2.moveTo(crossPoint.dx, mid);
        fillPath2.lineTo(crossPoint.dx, crossPoint.dy);
        fillPath2.lineTo(p2.dx, p2.dy);
        fillPath2.lineTo(p2.dx, mid);
        fillPath2.close();
        canvas.drawPath(fillPath2, fillPaint2);
      }
    }

    if (activePly >= 0 && activePly < totalPlies) {
      final cursorX = activePly * step + step / 2;
      final cursorPaint = Paint()
        ..color = theme.colorScheme.primary
        ..strokeWidth = 2;
      canvas.drawLine(Offset(cursorX, 0), Offset(cursorX, height), cursorPaint);
    }
  }

  @override
  bool shouldRepaint(_EvalGraphPainter old) =>
      old.evaluations != evaluations ||
      old.totalPlies != totalPlies ||
      old.activePly != activePly;
}

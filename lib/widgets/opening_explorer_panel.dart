import 'package:annoto/models/opening_explorer.dart';
import 'package:flutter/material.dart';

class OpeningExplorerPanel extends StatelessWidget {
  const OpeningExplorerPanel({super.key, required this.result, this.onMoveTap});

  final ExplorerResult result;
  final void Function(ExplorerMove move)? onMoveTap;

  static const _pieceSymbols = {
    'N': '♘',
    'B': '♗',
    'R': '♖',
    'Q': '♕',
    'K': '♔',
  };

  String _toFigurine(String san) {
    if (san.isEmpty) return san;
    final symbol = _pieceSymbols[san[0]];
    return symbol != null ? '$symbol${san.substring(1)}' : san;
  }

  String _formatGames(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).round()}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moves = result.moves;
    if (moves.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(theme),
        for (final move in moves) _buildMoveRow(theme, move),
        _buildTotalRow(theme),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text('Move', style: style)),
          SizedBox(width: 52, child: Text('Games', style: style)),
          Expanded(
            child: Text(
              'White / Draw / Black',
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveRow(ThemeData theme, ExplorerMove move) {
    final total = move.white + move.draws + move.black;
    if (total == 0) return const SizedBox.shrink();
    return InkWell(
      onTap: onMoveTap != null ? () => onMoveTap!(move) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                _toFigurine(move.san),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                _formatGames(total),
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: _buildBar(move.white, move.draws, move.black, total),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(ThemeData theme) {
    final total = result.white + result.draws + result.black;
    if (total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              'Σ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              _formatGames(total),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: _buildBar(result.white, result.draws, result.black, total),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(int white, int draws, int black, int total) {
    final wRatio = white / total;
    final dRatio = draws / total;
    final bRatio = black / total;

    final wFlex = (wRatio * 1000).round();
    final dFlex = (dRatio * 1000).round();
    final bFlex = (bRatio * 1000).round();

    final labelStyle = const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      height: 1,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 22,
        child: Row(
          children: [
            if (wFlex > 0)
              Expanded(
                flex: wFlex,
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: wRatio >= 0.1
                      ? Text(
                          '${(wRatio * 100).round()}%',
                          style: labelStyle.copyWith(color: Colors.black87),
                        )
                      : null,
                ),
              ),
            if (dFlex > 0)
              Expanded(
                flex: dFlex,
                child: Container(
                  color: Colors.grey.shade500,
                  alignment: Alignment.center,
                  child: dRatio >= 0.1
                      ? Text(
                          '${(dRatio * 100).round()}%',
                          style: labelStyle.copyWith(color: Colors.white),
                        )
                      : null,
                ),
              ),
            if (bFlex > 0)
              Expanded(
                flex: bFlex,
                child: Container(
                  color: Colors.grey.shade900,
                  alignment: Alignment.center,
                  child: bRatio >= 0.1
                      ? Text(
                          '${(bRatio * 100).round()}%',
                          style: labelStyle.copyWith(color: Colors.white),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

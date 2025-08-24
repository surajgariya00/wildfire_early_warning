import 'package:flutter/material.dart';

enum RiskLevel { veryLow, low, moderate, high, extreme }

class FireRiskBadge extends StatelessWidget {
  final RiskLevel level;
  final int score; // 0-100
  const FireRiskBadge({super.key, required this.level, required this.score});

  Color _colorFor(RiskLevel l, ColorScheme s) {
    switch (l) {
      case RiskLevel.veryLow: return s.primaryContainer;
      case RiskLevel.low: return s.secondaryContainer;
      case RiskLevel.moderate: return s.tertiaryContainer;
      case RiskLevel.high: return Colors.orange.shade400;
      case RiskLevel.extreme: return Colors.red.shade400;
    }
  }

  String _label(RiskLevel l) {
    switch (l) {
      case RiskLevel.veryLow: return 'Very Low';
      case RiskLevel.low: return 'Low';
      case RiskLevel.moderate: return 'Moderate';
      case RiskLevel.high: return 'High';
      case RiskLevel.extreme: return 'Extreme';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: _colorFor(level, scheme),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$score', style: Theme.of(context).textTheme.headlineSmall),
            Text(_label(level), style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

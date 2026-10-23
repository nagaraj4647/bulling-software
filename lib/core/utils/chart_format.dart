import 'dart:math' as math;

/// Compact Indian-style axis label: 950 -> "950", 1200 -> "1.2k",
/// 250000 -> "2.5L".
String compactAmount(double value) {
  if (value >= 100000) {
    final v = value / 100000;
    return '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}L';
  }
  if (value >= 1000) {
    final v = value / 1000;
    return '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}k';
  }
  return value.toInt().toString();
}

/// Smallest "nice" axis maximum at least ~20% above [maxValue], so the
/// highest point never touches the chart's top edge. Always > 0.
double niceCeil(double maxValue) {
  const steps = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 7.5, 10.0];
  final target = maxValue * 1.2;
  if (target <= 0) return 1;
  final magnitude = math
      .pow(10, (math.log(target) / math.ln10).floor())
      .toDouble();
  final normalized = target / magnitude;
  for (final step in steps) {
    if (normalized <= step) return step * magnitude;
  }
  return 10 * magnitude;
}

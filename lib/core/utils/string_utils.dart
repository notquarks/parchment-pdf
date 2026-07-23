String formatBytes(int bytes, int decimals) {
  if (bytes <= 0) return '0 B';

  const units = ['B', 'kB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;

  while (value >= 1000 && unitIndex < units.length - 1) {
    value /= 1000;
    unitIndex++;
  }

  final shownDecimals = unitIndex == 0 ? 0 : decimals;
  return '${value.toStringAsFixed(shownDecimals)} ${units[unitIndex]}';
}

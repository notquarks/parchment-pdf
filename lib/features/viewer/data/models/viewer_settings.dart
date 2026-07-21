enum ReadingDirection {
  vertical('Continuous vertical'),
  horizontalLtr('Paged left to right'),
  horizontalRtl('Paged right to left');

  const ReadingDirection(this.label);
  final String label;

  bool get isPaged => this != ReadingDirection.vertical;
}

enum BackgroundTheme {
  light('White'),
  gray('Gray'),
  dark('Black'),
  sepia('Sepia');

  const BackgroundTheme(this.label);
  final String label;
}

enum ScaleType {
  smart('Smart fit'),
  fitScreen('Fit page'),
  fitWidth('Fit width'),
  fitHeight('Fit height'),
  original('Original size');

  const ScaleType(this.label);
  final String label;
}

enum TapZoneMode {
  pagedOnly('Paged modes only'),
  always('All reading modes'),
  off('Off');

  const TapZoneMode(this.label);
  final String label;
}

enum ViewerContentFilter { original, grayscale, sepia, invert }

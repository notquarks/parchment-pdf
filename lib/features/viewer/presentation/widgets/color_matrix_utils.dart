import 'dart:ui' as ui;

enum ViewerContentFilter { original, grayscale, sepia, invert }

ui.ColorFilter? viewerColorFilter({
  required ViewerContentFilter filter,
  required double brightness,
  required double contrast,
  required double saturation,
}) {
  final normalizedBrightness = brightness.clamp(-1.0, 1.0).toDouble();
  final normalizedContrast = contrast.clamp(0.5, 1.5).toDouble();
  final normalizedSaturation = saturation.clamp(0.0, 2.0).toDouble();

  var matrix = _identityMatrix;

  matrix = _multiplyMatrices(
    _filterMatrix(filter),
    matrix,
  );
  matrix = _multiplyMatrices(
    _saturationMatrix(normalizedSaturation),
    matrix,
  );
  matrix = _multiplyMatrices(
    _contrastMatrix(normalizedContrast),
    matrix,
  );
  matrix = _multiplyMatrices(
    _brightnessMatrix(normalizedBrightness),
    matrix,
  );

  if (_isIdentity(matrix)) return null;
  return ui.ColorFilter.matrix(matrix);
}

List<double> _filterMatrix(ViewerContentFilter filter) {
  return switch (filter) {
    ViewerContentFilter.original => _identityMatrix,
    ViewerContentFilter.grayscale => _grayscaleMatrix,
    ViewerContentFilter.sepia => _sepiaMatrix,
    ViewerContentFilter.invert => _invertMatrix,
  };
}

List<double> _brightnessMatrix(double brightness) {
  final offset = brightness * 255;
  return [
    1, 0, 0, 0, offset,
    0, 1, 0, 0, offset,
    0, 0, 1, 0, offset,
    0, 0, 0, 1, 0,
  ];
}

List<double> _contrastMatrix(double contrast) {
  final offset = 128 * (1 - contrast);
  return [
    contrast, 0, 0, 0, offset,
    0, contrast, 0, 0, offset,
    0, 0, contrast, 0, offset,
    0, 0, 0, 1, 0,
  ];
}

List<double> _saturationMatrix(double saturation) {
  const red = 0.2126;
  const green = 0.7152;
  const blue = 0.0722;
  final inverse = 1 - saturation;

  return [
    inverse * red + saturation,
    inverse * green,
    inverse * blue,
    0,
    0,
    inverse * red,
    inverse * green + saturation,
    inverse * blue,
    0,
    0,
    inverse * red,
    inverse * green,
    inverse * blue + saturation,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _multiplyMatrices(List<double> outer, List<double> inner) {
  final result = List<double>.filled(20, 0);

  for (var row = 0; row < 4; row++) {
    for (var column = 0; column < 4; column++) {
      var value = 0.0;
      for (var index = 0; index < 4; index++) {
        value += outer[row * 5 + index] * inner[index * 5 + column];
      }
      result[row * 5 + column] = value;
    }

    var offset = outer[row * 5 + 4];
    for (var index = 0; index < 4; index++) {
      offset += outer[row * 5 + index] * inner[index * 5 + 4];
    }
    result[row * 5 + 4] = offset;
  }

  return result;
}

bool _isIdentity(List<double> matrix) {
  const tolerance = 0.0001;
  for (var index = 0; index < matrix.length; index++) {
    if ((matrix[index] - _identityMatrix[index]).abs() > tolerance) {
      return false;
    }
  }
  return true;
}

const List<double> _identityMatrix = [
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

const List<double> _grayscaleMatrix = [
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

const List<double> _sepiaMatrix = [
  0.393, 0.769, 0.189, 0, 0,
  0.349, 0.686, 0.168, 0, 0,
  0.272, 0.534, 0.131, 0, 0,
  0, 0, 0, 1, 0,
];

const List<double> _invertMatrix = [
  -1, 0, 0, 0, 255,
  0, -1, 0, 0, 255,
  0, 0, -1, 0, 255,
  0, 0, 0, 1, 0,
];

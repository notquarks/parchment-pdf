import 'dart:ui' as ui;

ui.ColorFilter grayscaleFilter() {
  return ui.ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

ui.ColorFilter brightnessFilter(double brightness) {
  final b = brightness.clamp(-1.0, 1.0);
  return ui.ColorFilter.matrix([
    1, 0, 0, 0, b,
    0, 1, 0, 0, b,
    0, 0, 1, 0, b,
    0, 0, 0, 1, 0,
  ]);
}

ui.ColorFilter saturationFilter(double saturation) {
  final s = saturation.clamp(0.0, 2.0);
  final grayWeight = 1 - s;
  return ui.ColorFilter.matrix([
    grayWeight + s * 0.2126, grayWeight * 0.7152, grayWeight * 0.0722, 0, 0,
    grayWeight * 0.2126, grayWeight + s * 0.7152, grayWeight * 0.0722, 0, 0,
    grayWeight * 0.2126, grayWeight * 0.7152, grayWeight + s * 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

ui.ColorFilter sepiaFilter() {
  return ui.ColorFilter.matrix([
    0.393, 0.769, 0.189, 0, 0,
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

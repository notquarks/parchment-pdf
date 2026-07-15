import 'package:flutter/material.dart';

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier(super.value);

  void toggleDark(bool isDark) {
    value = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}

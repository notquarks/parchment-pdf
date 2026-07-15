import 'package:flutter/material.dart';
import 'package:pdf_tools/features/compression/presentation/screens/compress_screen.dart';
import 'package:pdf_tools/features/merge/presentation/screens/merge_screen.dart';
import 'package:pdf_tools/features/split/presentation/screens/split_screen.dart';
import 'package:pdf_tools/features/rearrange/rearrange.dart';
import 'package:pdf_tools/features/settings/presentation/screens/settings_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String compress = '/compress';
  static const String merge = '/merge';
  static const String split = '/split';
  static const String rearrange = '/rearrange';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> get routes => {
    compress: (context) => const CompressScreen(),
    merge: (context) => const MergeScreen(),
    split: (context) => const SplitScreen(),
    rearrange: (context) => const RearrangeScreen(),
    settings: (context) => const SettingsScreen(),
  };
}

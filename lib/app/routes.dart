import 'package:flutter/material.dart';
import 'package:pdf_tools/features/compression/presentation/screens/compress_screen.dart';
import 'package:pdf_tools/features/merge/presentation/screens/merge_screen.dart';
import 'package:pdf_tools/features/settings/presentation/screens/advanced_screen.dart';
import 'package:pdf_tools/features/settings/presentation/screens/viewersett_screen.dart';
import 'package:pdf_tools/features/split/presentation/screens/split_screen.dart';
import 'package:pdf_tools/features/rearrange/rearrange.dart';
import 'package:pdf_tools/features/settings/presentation/screens/settings_screen.dart';
import 'package:pdf_tools/features/trim/presentation/screens/trim_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String compress = '/compress';
  static const String merge = '/merge';
  static const String split = '/split';
  static const String trim = '/trim';
  static const String rearrange = '/rearrange';
  static const String settings = '/settings';
  static const String viewerSettings = '/viewer_settings';
  static const String advancedSettings = '/advanced_settings';

  static Map<String, WidgetBuilder> get routes => {
    compress: (context) => const CompressScreen(),
    merge: (context) => const MergeScreen(),
    split: (context) => const SplitScreen(),
    rearrange: (context) => const RearrangeScreen(),
    trim: (context) => const TrimPageScreen(),
    settings: (context) => const SettingsScreen(),
    viewerSettings: (context) => const ViewerSettingsScreen(),
    advancedSettings: (context) => const AdvancedSettingsScreen(),
  };
}

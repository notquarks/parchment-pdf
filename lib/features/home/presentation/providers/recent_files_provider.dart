import 'package:flutter/material.dart';
import 'package:pdf_tools/features/home/data/services/recent_files_service.dart';

class RecentFilesProvider extends InheritedWidget {
  final RecentFilesService service;

  const RecentFilesProvider({
    super.key,
    required this.service,
    required super.child,
  });

  static RecentFilesService of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<RecentFilesProvider>();
    assert(provider != null, 'No RecentFilesProvider found in context');
    return provider!.service;
  }

  @override
  bool updateShouldNotify(RecentFilesProvider oldWidget) =>
      service != oldWidget.service;
}
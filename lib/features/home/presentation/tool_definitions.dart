import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ToolDefinition {
  const ToolDefinition({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

const toolDefinitions = [
  ToolDefinition(
    title: 'Merge',
    subtitle: 'Combine multiple pdf`s into one.',
    icon: Icons.merge,
    route: '/merge',
  ),
  ToolDefinition(
    title: 'Split',
    subtitle: 'Extract pages or split docs.',
    icon: Icons.insert_page_break_outlined,
    route: '/split',
  ),
  ToolDefinition(
    title: 'Compress',
    subtitle: 'Reduce file size quickly.',
    icon: Icons.compress_outlined,
    route: '/compress',
  ),
  ToolDefinition(
    title: 'Rearrange',
    subtitle: 'Rearrange pages in a pdf file.',
    icon: Symbols.low_priority,
    route: '/rearrange',
  ),
  ToolDefinition(
    title: 'Trim',
    subtitle: 'Remove unwanted pages of a pdf.',
    icon: Symbols.scan_delete,
    route: '/trim',
  ),
];

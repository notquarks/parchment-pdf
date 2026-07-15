import 'package:flutter/material.dart';
import 'package:pdf_tools/features/rearrange/presentation/models/rearrange_enums.dart';

class RearrangeMoveMenu extends StatelessWidget {
  final int selectedPageIndex;
  final int pageOrderLength;
  final VoidCallback onMoveEarlier;
  final VoidCallback onMoveLater;
  final VoidCallback onMoveToStart;
  final VoidCallback onMoveToEnd;
  final VoidCallback onMoveToPosition;
  final Function(String command, int index) onRunCommand;
  
  const RearrangeMoveMenu({
    super.key,
    required this.selectedPageIndex,
    required this.pageOrderLength,
    required this.onMoveEarlier,
    required this.onMoveLater,
    required this.onMoveToStart,
    required this.onMoveToEnd,
    required this.onMoveToPosition,
    required this.onRunCommand,
  });
  
  List<Widget> buildMoveMenuItems() {
    return [
      MenuItemButton(
        onPressed: selectedPageIndex > 0 ? onMoveEarlier : null,
        leadingIcon: const Icon(Icons.arrow_back),
        child: const Text('Move earlier'),
      ),
      MenuItemButton(
        onPressed: selectedPageIndex < pageOrderLength - 1
            ? onMoveLater
            : null,
        leadingIcon: const Icon(Icons.arrow_forward),
        child: const Text('Move later'),
      ),
      MenuItemButton(
        onPressed: selectedPageIndex > 0 ? onMoveToStart : null,
        leadingIcon: const Icon(Icons.first_page),
        child: const Text('Move to beginning'),
      ),
      MenuItemButton(
        onPressed: selectedPageIndex < pageOrderLength - 1
            ? onMoveToEnd
            : null,
        leadingIcon: const Icon(Icons.last_page),
        child: const Text('Move to end'),
      ),
      MenuItemButton(
        onPressed: onMoveToPosition,
        leadingIcon: const Icon(Icons.pin),
        child: const Text('Move to position…'),
      ),
    ];
  }
  
  List<PopupMenuEntry<String>> buildPopupItems(int index) {
    return [
      PopupMenuItem(
        value: PageCommand.earlier.name,
        enabled: index > 0,
        child: const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.arrow_back),
          title: Text('Move earlier'),
        ),
      ),
      PopupMenuItem(
        value: PageCommand.later.name,
        enabled: index < pageOrderLength - 1,
        child: const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.arrow_forward),
          title: Text('Move later'),
        ),
      ),
      PopupMenuItem(
        value: PageCommand.start.name,
        enabled: index > 0,
        child: const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.first_page),
          title: Text('Move to beginning'),
        ),
      ),
      PopupMenuItem(
        value: PageCommand.end.name,
        enabled: index < pageOrderLength - 1,
        child: const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.last_page),
          title: Text('Move to end'),
        ),
      ),
      PopupMenuItem(
        value: PageCommand.position.name,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.pin),
          title: Text('Move to position…'),
        ),
      ),
    ];
  }
  
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
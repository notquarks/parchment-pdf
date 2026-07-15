import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_tools/core/utils/snackbar_utils.dart';
import 'package:pdf_tools/features/rearrange/rearrange.dart';

class RearrangeScreen extends StatefulWidget {
  const RearrangeScreen({super.key});

  @override
  State<RearrangeScreen> createState() => _RearrangeScreenState();
}

class _RearrangeScreenState extends State<RearrangeScreen> {
  late final _state = RearrangeState(
    isMounted: () => mounted,
    onError: (message) => showErrorSnackBar(context, message),
  );

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (!await _confirmDiscardChanges()) return;
    await _state.pickFile();
  }

  Future<bool> _confirmDiscardChanges() async {
    return RearrangeOperations.confirmDiscardChanges(
      context,
      isDirty: _state.isDirty,
    );
  }

  void _announceMove() {
    RearrangeOperations.announceMove(
      context: context,
      state: _state,
    );
  }

  Future<void> _doRearrange() async {
    await RearrangeOperations.performRearrange(
      context: context,
      state: _state,
    );
  }

  Future<bool> _onWillPop() => _confirmDiscardChanges();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _state.undo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): _state.redo,
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ): _state.redo,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _doRearrange,
          const SingleActivator(
            LogicalKeyboardKey.arrowLeft,
            control: true,
          ): () =>
              _state.moveSelectedBy(-1),
          const SingleActivator(
            LogicalKeyboardKey.arrowUp,
            control: true,
          ): () =>
              _state.moveSelectedBy(-1),
          const SingleActivator(
            LogicalKeyboardKey.arrowRight,
            control: true,
          ): () =>
              _state.moveSelectedBy(1),
          const SingleActivator(
            LogicalKeyboardKey.arrowDown,
            control: true,
          ): () =>
              _state.moveSelectedBy(1),
          const SingleActivator(LogicalKeyboardKey.home, control: true):
              _state.moveSelectedToStart,
          const SingleActivator(LogicalKeyboardKey.end, control: true):
              _state.moveSelectedToEnd,
        },
        child: Focus(
          autofocus: true,
          child: ListenableBuilder(
            listenable: _state,
            builder: (context, child) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final compact = width < RearrangeConstants.compactBreakpoint;
                  final expanded = width >= RearrangeConstants.expandedBreakpoint;

                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('Rearrange pages'),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHigh,
                      actions: compact || !_state.isReady
                          ? null
                          : [
                              IconButton(
                                tooltip: 'Undo',
                                onPressed: _state.canUndo ? _state.undo : null,
                                icon: const Icon(Icons.undo),
                              ),
                              IconButton(
                                tooltip: 'Redo',
                                onPressed: _state.canRedo ? _state.redo : null,
                                icon: const Icon(Icons.redo),
                              ),
                              IconButton(
                                tooltip: 'Reset order',
                                onPressed: _state.isDirty ? _state.resetOrder : null,
                                icon: const Icon(Icons.restart_alt),
                              ),
                              const SizedBox(width: RearrangeConstants.compactPadding),
                            ],
                    ),
                    body: _buildBody(context, compact: compact, expanded: expanded),
                    bottomNavigationBar: compact && _state.hasDocument
                        ? _buildCompactCommandBar(context)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool compact,
    required bool expanded,
  }) {
    if (!_state.hasDocument) return _buildEmptyState(context);
    if (!_state.isReady || _state.documentRef == null) {
      return _buildLoadingState(context);
    }

    return Column(
      children: [
        if (!compact) _buildDesktopCommandBar(context, expanded: expanded),
        Expanded(
          child: _buildGrid(context, compact: compact, expanded: expanded),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return RearrangeEmptyState(
      onPickFile: _pickFile,
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return RearrangeLoadingState(
      filePath: _state.filePicked!.path,
      onPickFile: _pickFile,
    );
  }

  Widget _buildDesktopCommandBar(
    BuildContext context, {
    required bool expanded,
  }) {
    final moveMenu = RearrangeMoveMenu(
      selectedPageIndex: _state.selectedPageIndex,
      pageOrderLength: _state.pageOrder.length,
      onMoveEarlier: () => _state.moveSelectedBy(-1),
      onMoveLater: () => _state.moveSelectedBy(1),
      onMoveToStart: _state.moveSelectedToStart,
      onMoveToEnd: _state.moveSelectedToEnd,
      onMoveToPosition: _moveSelectedToPosition,
      onRunCommand: (command, index) {
        _runPageCommand(PageCommand.values.byName(command), index);
      },
    );
    
    return RearrangeDesktopCommandBar(
      fileName: p.basename(_state.filePicked!.path),
      pageCount: _state.pageOrder.length,
      isDirty: _state.isDirty,
      hasSelection: _state.hasSelection,
      selectedPageIndex: _state.selectedPageIndex,
      onPickFile: _pickFile,
      onMoveSelected: () {},
      onSave: _doRearrange,
      moveMenuItems: moveMenu.buildMoveMenuItems(),
    );
  }

  Widget _buildCompactCommandBar(BuildContext context) {
    return RearrangeCompactCommandBar(
      canUndo: _state.canUndo,
      canRedo: _state.canRedo,
      isDirty: _state.isDirty,
      onPickFile: _pickFile,
      onUndo: _state.undo,
      onRedo: _state.redo,
      onSave: _doRearrange,
    );
  }

  Widget _buildGrid(
    BuildContext context, {
    required bool compact,
    required bool expanded,
  }) {
    return RearrangeGrid(
      pageOrder: _state.pageOrder,
      compact: compact,
      expanded: expanded,
      onMovePage: (fromIndex, toIndex) {
        _state.movePage(fromIndex, toIndex);
        _announceMove();
      },
      pageCardBuilder: (index, compact) => _buildDropTarget(context, index: index, compact: compact),
    );
  }

  Widget _buildDropTarget(
    BuildContext context, {
    required int index,
    required bool compact,
  }) {
    return DragTarget<int>(
      onWillAccept: (sourceIndex) =>
          sourceIndex != null && sourceIndex != index,
      onAccept: (sourceIndex) {
        _state.movePage(sourceIndex, index);
        _announceMove();
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        final card = _buildPageCard(
          context,
          index: index,
          compact: compact,
          isDropTarget: isDropTarget,
        );

        if (Platform.isWindows) {
          return Draggable<int>(
            data: index,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: _buildDragFeedback(context, index),
            childWhenDragging: Opacity(opacity: RearrangeConstants.disabledOpacity, child: card),
            child: card,
          );
        }

        return LongPressDraggable<int>(
          data: index,
          hapticFeedbackOnStart: true,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _buildDragFeedback(context, index),
          childWhenDragging: Opacity(opacity: RearrangeConstants.disabledOpacity, child: card),
          child: card,
        );
      },
    );
  }

  Widget _buildDragFeedback(BuildContext context, int index) {
    return RearrangePageCard.buildDragFeedback(
      context,
      index,
      _state.documentRef!,
      _state.pageOrder.length,
    );
  }

  Widget _buildPageCard(
    BuildContext context, {
    required int index,
    required bool compact,
    required bool isDropTarget,
    bool interactive = true,
  }) {
    final pageNumber = _state.pageOrder[index];
    final selected = index == _state.selectedPageIndex;
    
    return RearrangePageCard(
      index: index,
      pageNumber: pageNumber,
      isSelected: selected,
      isDropTarget: isDropTarget,
      compact: compact,
      interactive: interactive,
      documentRef: _state.documentRef!,
      onTap: () => _state.selectPage(index),
      onMoveEarlier: () {
        _state.movePage(index, index - 1);
        _announceMove();
      },
      onMoveLater: () {
        _state.movePage(index, index + 1);
        _announceMove();
      },
      onContextMenu: (position) => _showPageContextMenu(
        context,
        index: index,
        position: position,
      ),
      totalPageCount: _state.pageOrder.length,
      onRunCommand: (command, index) {
        _runPageCommand(PageCommand.values.byName(command), index);
      },
      popupItemsBuilder: (index) => _buildPopupItems(index),
    );
  }

  Future<void> _moveSelectedToPosition() async {
    await RearrangeOperations.moveToPosition(
      context: context,
      state: _state,
    );
    _announceMove();
  }

  List<PopupMenuEntry<String>> _buildPopupItems(int index) {
    return RearrangeOperations.buildPopupItems(
      index: index,
      pageOrderLength: _state.pageOrder.length,
    );
  }

  Future<void> _showPageContextMenu(
    BuildContext context, {
    required int index,
    required Offset position,
  }) async {
    await RearrangeOperations.showPageContextMenu(
      context: context,
      state: _state,
      index: index,
      position: position,
    );
  }

  void _runPageCommand(PageCommand command, int index) {
    RearrangeOperations.runPageCommand(
      state: _state,
      command: command,
      index: index,
    );
    _announceMove();
  }
}
import 'dart:io';

import 'package:pdf_tools/core/utils/pdf_pick_controller.dart';
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:pdf_tools/features/rearrange/presentation/constants/rearrange_constants.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter/foundation.dart';

class RearrangeState extends ChangeNotifier {
  final bool Function() isMounted;
  final void Function(String message) onError;

  File? _filePicked;
  int? _pageCount;
  int _selectedPageIndex = -1;
  List<int> _pageOrder = [];
  List<int> _initialPageOrder = [];
  final List<List<int>> _undoStack = [];
  final List<List<int>> _redoStack = [];
  PdfDocumentRef? _documentRef;
  VoidCallback? _removeDocListener;
  late final PdfPickController _controller;

  RearrangeState({required this.isMounted, required this.onError}) {
    _controller = PdfPickController(
      isMounted: isMounted,
      onEvent: _applyEvent,
      onError: onError,
    );
  }

  bool get hasDocument => _filePicked != null;
  bool get isReady => hasDocument && _pageCount != null;
  bool get hasSelection => _selectedPageIndex >= 0 && _selectedPageIndex < _pageOrder.length;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isDirty => !_listsEqual(_pageOrder, _initialPageOrder);
  int? get selectedPageNumber => hasSelection ? _pageOrder[_selectedPageIndex] : null;

  File? get filePicked => _filePicked;
  int? get pageCount => _pageCount;
  int get selectedPageIndex => _selectedPageIndex;
  List<int> get pageOrder => _pageOrder;
  List<int> get initialPageOrder => _initialPageOrder;
  PdfDocumentRef? get documentRef => _documentRef;

  void _applyEvent(PdfFileEvent event) {
    switch (event) {
      case PdfFileAdded(:final info):
        _filePicked = info.file;
        _pageCount = null;
        _pageOrder = [];
        _initialPageOrder = [];
        _selectedPageIndex = -1;
        _undoStack.clear();
        _redoStack.clear();
        _preloadDocument(info.file.path);
        notifyListeners();
      case PdfFileResolved(:final info):
        final count = info.pageCount ?? 0;
        final order = List<int>.generate(count, (index) => index + 1);
        _pageCount = count;
        _pageOrder = List<int>.from(order);
        _initialPageOrder = List<int>.from(order);
        _selectedPageIndex = count > 0 ? 0 : -1;
        _undoStack.clear();
        _redoStack.clear();
        notifyListeners();
      case PdfFileFailed(:final error):
        _pageCount = null;
        _pageOrder = [];
        _initialPageOrder = [];
        _selectedPageIndex = -1;
        onError('${error.fileName}: ${error.error}');
        notifyListeners();
    }
  }

  void _preloadDocument(String path) {
    _removeDocListener?.call();
    _documentRef = PdfDocumentRefFile(path);
    final listenable = _documentRef!.resolveListenable();
    _removeDocListener = listenable.addListener(() {});
    listenable.load();
  }

  void selectPage(int index) {
    if (index < 0 || index >= _pageOrder.length) return;
    _selectedPageIndex = _selectedPageIndex == index ? -1 : index;
    notifyListeners();
  }

  void recordHistory() {
    _undoStack.add(List<int>.from(_pageOrder));
    if (_undoStack.length > RearrangeConstants.historyLimit) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void movePage(int fromIndex, int toIndex) {
    if (fromIndex < 0 ||
        fromIndex >= _pageOrder.length ||
        toIndex < 0 ||
        toIndex >= _pageOrder.length ||
        fromIndex == toIndex) {
      return;
    }

    recordHistory();
    final page = _pageOrder.removeAt(fromIndex);
    _pageOrder.insert(toIndex, page);
    _selectedPageIndex = toIndex;
    notifyListeners();
  }

  void moveSelectedBy(int offset) {
    if (!hasSelection) return;
    final target = (_selectedPageIndex + offset).clamp(
      0,
      _pageOrder.length - 1,
    );
    movePage(_selectedPageIndex, target);
  }

  void moveSelectedToStart() {
    if (hasSelection) movePage(_selectedPageIndex, 0);
  }

  void moveSelectedToEnd() {
    if (hasSelection) {
      movePage(_selectedPageIndex, _pageOrder.length - 1);
    }
  }

  void undo() {
    if (!canUndo) return;
    _redoStack.add(List<int>.from(_pageOrder));
    _pageOrder = _undoStack.removeLast();
    _restoreSelection();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _undoStack.add(List<int>.from(_pageOrder));
    _pageOrder = _redoStack.removeLast();
    _restoreSelection();
    notifyListeners();
  }

  void resetOrder() {
    if (!isDirty) return;
    recordHistory();
    final selectedPage = selectedPageNumber;
    _pageOrder = List<int>.from(_initialPageOrder);
    _selectedPageIndex = selectedPage == null
        ? -1
        : _pageOrder.indexOf(selectedPage);
    notifyListeners();
  }

  void _restoreSelection() {
    if (_pageOrder.isEmpty) {
      _selectedPageIndex = -1;
      return;
    }
    _selectedPageIndex = _selectedPageIndex.clamp(0, _pageOrder.length - 1);
  }

  void updateSelection(int index) {
    _selectedPageIndex = index;
    notifyListeners();
  }

  static bool _listsEqual(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _removeDocListener?.call();
    super.dispose();
  }

  Future<void> pickFile() async {
    await _controller.pickAndProcess(
      allowMultiple: false,
      failurePrefix: 'Failed to load file',
    );
  }

  PdfPickController get controller => _controller;
}
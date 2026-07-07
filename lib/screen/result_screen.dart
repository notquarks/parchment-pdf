import 'dart:io';

import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdf_tools/components/loading_spinner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_tools/model/task_messages.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.messages,
    required this.fileCount,
    this.filePath,
    this.fileName,
    this.mergeFuture,
    this.onCancel,
  });

  final TaskMessages messages;
  final int fileCount;
  final String? filePath;
  final String? fileName;
  final Future<String>? mergeFuture;
  final Future<void> Function()? onCancel;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String? _filePath;
  String? _fileName;
  bool _completed = false;
  String? _error;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _filePath = widget.filePath;
    _fileName = widget.fileName;
    _completed = widget.mergeFuture == null;

    if (widget.mergeFuture != null) {
      _listenToFuture(widget.mergeFuture!);
    }
  }

  void _listenToFuture(Future<String> future) {
    future.then(_onSuccess).catchError(_onError);
  }

  void _onSuccess(String path) {
    if (!mounted) return;
    setState(() {
      _filePath = path;
      _fileName = path.split(Platform.pathSeparator).last;
      _completed = true;
    });
  }

  void _onError(Object e) {
    if (!mounted) return;
    if (e is PdfCancelled) {
      setState(() => _cancelled = true);
    } else {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(title: Text(widget.messages.title)),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _statusIndicator(shortest),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FilterChip(
                        onSelected: ((e) {}),
                        showCheckmark: false,
                        selected: true,
                        shape: StadiumBorder(),
                        label: Text(
                          '${widget.fileCount} files',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                      if (_fileName != null)
                        Text(
                          _fileName!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          softWrap: true,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          _statusMessage,
                          style: Theme.of(context).textTheme.displaySmall,
                          softWrap: true,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18.0),
                          child: Text(
                            _error!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                            softWrap: true,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _statusIndicator(double shortest) {
    if (_cancelled) {
      return _statusBox(
        key: 'cancelled',
        color: Theme.of(context).colorScheme.secondaryContainer,
        icon: Icons.cancel_outlined,
        iconColor: Theme.of(context).colorScheme.secondary,
        shortest: shortest,
      );
    }
    if (_error != null) {
      return _statusBox(
        key: 'error',
        color: Theme.of(context).colorScheme.errorContainer,
        icon: Icons.error_outline,
        iconColor: Theme.of(context).colorScheme.error,
        shortest: shortest,
      );
    }
    if (_completed) {
      return _statusBox(
        key: 'success',
        color: Theme.of(context).colorScheme.primaryContainer,
        icon: Icons.check,
        iconColor: null,
        shortest: shortest,
      );
    }
    return KeyedSubtree(
      key: const ValueKey('loading'),
      child: LoadingSpinner(size: 0.5),
    );
  }

  Widget _statusBox({
    required String key,
    required Color color,
    required IconData icon,
    required double shortest,
    Color? iconColor,
  }) {
    return KeyedSubtree(
      key: ValueKey(key),
      child: M3EContainer.verySunny(
        color: color,
        width: shortest * 0.6,
        height: shortest * 0.6,
        child: Icon(icon, size: shortest * 0.3, color: iconColor),
      ),
    );
  }

  String get _statusMessage {
    if (_cancelled) return 'Cancelled';
    if (_error != null) return widget.messages.failure;
    if (_completed) return widget.messages.success;
    return widget.messages.progress;
  }

  Widget? _bottomBar() {
    if ((_completed && _filePath != null) || _error != null) {
      return _resultActionsBar();
    }
    if (_cancelled || widget.onCancel != null) {
      return _cancelBar();
    }
    return null;
  }

  Widget _resultActionsBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        spacing: 8.0,
        children: [
          M3EFilledButton.tonalIcon(
            size: M3EButtonSize.md,
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back),
            label: Text('Back'),
          ),
          if (_filePath != null) ...[
            M3EFilledButton.icon(
              size: M3EButtonSize.md,
              onPressed: () => SharePlus.instance.share(
                ShareParams(files: [XFile(_filePath!)]),
              ),
              icon: Icon(Icons.share),
              label: Text('Share'),
            ),
            Expanded(
              child: M3EFilledButton(
                size: M3EButtonSize.md,
                onPressed: () => OpenFilex.open(_filePath!),
                child: Text('Open'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cancelBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: M3EFilledButton(
              decoration: M3EButtonDecoration.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
              size: M3EButtonSize.md,
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

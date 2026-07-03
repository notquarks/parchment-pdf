import 'dart:io';

import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.taskTitle,
    required this.fileCount,
    this.filePath,
    this.fileName,
    this.mergeFuture,
  });

  final String taskTitle;
  final int fileCount;
  final String? filePath;
  final String? fileName;
  final Future<String>? mergeFuture;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String? _filePath;
  String? _fileName;
  bool _completed = false;
  String? _error;

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
    future.then((path) {
      if (!mounted) return;
      setState(() {
        _filePath = path;
        _fileName = path.split(Platform.pathSeparator).last;
        _completed = true;
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(title: Text(widget.taskTitle)),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _error != null
                        ? KeyedSubtree(
                            key: const ValueKey('error'),
                            child: M3EContainer.verySunny(
                              color: Theme.of(context).colorScheme.errorContainer,
                              width: shortest * 0.6,
                              height: shortest * 0.6,
                              child: Icon(
                                Icons.error_outline,
                                size: shortest * 0.3,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          )
                        : _completed
                            ? KeyedSubtree(
                                key: const ValueKey('success'),
                                child: M3EContainer.verySunny(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  width: shortest * 0.6,
                                  height: shortest * 0.6,
                                  child: Icon(Icons.check, size: shortest * 0.3),
                                ),
                              )
                            : KeyedSubtree(
                                key: const ValueKey('loading'),
                                child: SizedBox(
                                  width: shortest * 0.6,
                                  height: shortest * 0.6,
                                  child: LoadingIndicatorM3E(
                                    variant: LoadingIndicatorM3EVariant.contained,
                                  ),
                                ),
                              ),
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
                          _error != null
                              ? 'Merge failed'
                              : _completed
                              ? 'Successfully ${widget.taskTitle}d!'
                              : 'Merging…',
                          style: Theme.of(context).textTheme.displaySmall,
                          softWrap: true,
                          maxLines: 2,
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
      bottomNavigationBar: (_completed && _filePath != null) || _error != null
          ? Padding(
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
            )
          : null,
    );
  }
}

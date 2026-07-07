import 'dart:async';
import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

class ViewScreen extends StatefulWidget {
  const ViewScreen({super.key, required this.documentRef});

  final PdfDocumentRef documentRef;

  @override
  State<ViewScreen> createState() => _ViewScreenState();
}

class _ViewScreenState extends State<ViewScreen> {
  int pageNumber = 1;
  int pageCount = 0;
  late final PdfDocumentListenable _listenable;
  StreamSubscription<PdfDocumentEvent>? _eventsSub;

  @override
  void initState() {
    super.initState();
    _listenable = widget.documentRef.resolveListenable();
    _listenable.addListener(_onDocumentChanged);
    _attachEvents();
    final doc = _listenable.document;
    if (doc != null) pageCount = doc.pages.length;
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _listenable.removeListener(_onDocumentChanged);
    super.dispose();
  }

  void _attachEvents() {
    _eventsSub?.cancel();
    final doc = _listenable.document;
    if (doc != null) _eventsSub = doc.events.listen(_onDocumentEvent);
  }

  void _onDocumentChanged() {
    if (!mounted) return;
    _attachEvents();
    final doc = _listenable.document;
    setState(() {
      pageCount = doc?.pages.length ?? 0;
      if (pageCount < 1) {
        pageNumber = 1;
      } else if (pageNumber > pageCount) {
        pageNumber = pageCount;
      }
    });
  }

  void _onDocumentEvent(PdfDocumentEvent event) {
    if (!mounted) return;
    if (event.type == PdfDocumentEventType.pageStatusChanged ||
        event.type == PdfDocumentEventType.documentLoadComplete) {
      final doc = _listenable.document;
      if (doc != null && doc.pages.length != pageCount) {
        setState(() {
          pageCount = doc.pages.length;
          if (pageCount < 1) {
            pageNumber = 1;
          } else if (pageNumber > pageCount) {
            pageNumber = pageCount;
          }
        });
      }
    }
  }

  String get filePath => p.basename(widget.documentRef.key.sourceName);

  @override
  Widget build(BuildContext context) {
    final maxPage = pageCount > 1 ? pageCount.toDouble() : 1.0;
    return Scaffold(
      appBar: AppBar(title: Text(filePath)),
      body: PdfDocumentViewBuilder(
        documentRef: widget.documentRef,
        builder: (context, document) {
          if (document == null) {
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Icons.description_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.outline,
              ),
            );
          }

          return SafeArea(
            child: Stack(
              children: [
                PdfPageView(
                  document: document,
                  pageNumber: pageNumber,
                  alignment: Alignment.center,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: .max,
                  children: [
                    InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      splashFactory: NoSplash.splashFactory,
                      onTap: pageNumber > 1
                          ? () => setState(() => pageNumber--)
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(0),
                        ),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width / 3,
                          height: MediaQuery.of(context).size.height,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(color: Colors.red.withAlpha(0)),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        overlayColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),

                        splashFactory: NoSplash.splashFactory,
                        onTap: pageNumber < pageCount
                            ? () => setState(() => pageNumber++)
                            : null,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width / 3,
                          height: MediaQuery.of(context).size.height,
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: kBottomNavigationBarHeight,
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).highlightColor,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      mainAxisSize: .max,
                      children: [
                        M3EFilledButton(
                          onPressed: pageNumber > 1
                              ? () => setState(() => pageNumber--)
                              : null,
                          child: const Icon(Icons.arrow_back),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 12.0),
                                child: Text(pageNumber.toString()),
                              ),
                              Expanded(
                                child: Slider(
                                  value: pageNumber.toDouble(),
                                  min: 1,
                                  max: maxPage,
                                  divisions: pageCount > 1
                                      ? pageCount - 1
                                      : null,
                                  onChanged: pageCount > 1
                                      ? (v) => setState(
                                          () => pageNumber = v.round(),
                                        )
                                      : null,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Text(pageCount.toString()),
                              ),
                            ],
                          ),
                        ),
                        M3EFilledButton(
                          onPressed: pageNumber < pageCount
                              ? () => setState(() => pageNumber++)
                              : null,
                          child: const Icon(Icons.arrow_forward),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

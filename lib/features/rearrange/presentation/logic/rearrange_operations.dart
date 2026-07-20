import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf_manipulator/io.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdf_tools/features/compression/data/models/task_messages.dart';
import 'package:pdf_tools/core/utils/pdf_output.dart';
import 'package:pdf_tools/features/result/presentation/screens/result_screen.dart';
import 'package:pdf_tools/features/settings/presentation/widgets/settings_provider.dart';
import 'package:pdf_tools/core/utils/snackbar_utils.dart';
import 'package:pdf_tools/features/rearrange/presentation/models/rearrange_enums.dart';
import 'package:pdf_tools/features/rearrange/presentation/state/rearrange_state.dart';

class RearrangeOperations {
  RearrangeOperations._();

  static Future<bool> confirmDiscardChanges(
    BuildContext context, {
    required bool isDirty,
  }) async {
    if (!isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard page order changes?'),
        content: const Text(
          'Your current page order has not been saved. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> performRearrange({
    required BuildContext context,
    required RearrangeState state,
  }) async {
    if (!state.isReady || !state.isDirty) return;

    final settingsService = SettingsProvider.of(context).settingsService;
    final pdf = Pdf();
    final savedName = pdfOutputName(
      sourcePath: state.filePicked!.path,
      suffix: 'rearranged_',
    );
    final pdfOutput = await createPdfOutput(
      settingsService: settingsService,
      fileName: savedName,
    );
    final saveFile = pdfOutput.file;
    final output = pdfOutput.sink;
    final source = FileSource(state.filePicked!);

    PdfTask<void>? rearrangeTask;
    try {
      final mergeFuture = () async {
        try {
          rearrangeTask = pdf.extractPages(
            source,
            output,
            pages: state.pageOrder.map((page) => page - 1).toList(),
          );
          await rearrangeTask;
          await pdfOutput.commit();
          return saveFile.path;
        } catch (_) {
          await pdfOutput.discard();
          rethrow;
        } finally {
          await pdf.dispose();
        }
      }();

      if (!context.mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            messages: TaskMessages.rearrange,
            fileCount: state.pageOrder.length,
            mergeFuture: mergeFuture,
            onCancel: () async {
              rearrangeTask?.cancel();
              try {
                await mergeFuture;
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (error) {
      await pdfOutput.discard();
      await pdf.dispose();
      if (context.mounted) {
        showErrorSnackBar(context, 'Rearrange failed: $error');
      }
    }
  }

  static Future<void> moveToPosition({
    required BuildContext context,
    required RearrangeState state,
  }) async {
    if (!state.hasSelection) return;
    final controller = TextEditingController(
      text: '${state.selectedPageIndex + 1}',
    );
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move original page ${state.selectedPageNumber}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Position',
            helperText: 'Enter a value from 1 to ${state.pageOrder.length}',
          ),
          onSubmitted: (value) {
            final position = int.tryParse(value);
            if (position != null &&
                position >= 1 &&
                position <= state.pageOrder.length) {
              Navigator.pop(context, position - 1);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final position = int.tryParse(controller.text);
              if (position != null &&
                  position >= 1 &&
                  position <= state.pageOrder.length) {
                Navigator.pop(context, position - 1);
              }
            },
            child: const Text('Move'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (target != null) {
      state.movePage(state.selectedPageIndex, target);
    }
  }

  static Future<void> showPageContextMenu({
    required BuildContext context,
    required RearrangeState state,
    required int index,
    required Offset position,
  }) async {
    state.selectPage(index);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final command = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Offset.zero & overlay.size,
      ),
      items: buildPopupItems(
        index: index,
        pageOrderLength: state.pageOrder.length,
      ),
    );
    if (command != null) {
      final pageCommand = PageCommand.values.byName(command);
      state.selectPage(index);
      _executeCommand(state: state, command: pageCommand);
    }
  }

  static void runPageCommand({
    required RearrangeState state,
    required PageCommand command,
    required int index,
  }) {
    state.selectPage(index);
    _executeCommand(state: state, command: command);
  }

  static void _executeCommand({
    required RearrangeState state,
    required PageCommand command,
  }) {
    switch (command) {
      case PageCommand.earlier:
        state.moveSelectedBy(-1);
        return;
      case PageCommand.later:
        state.moveSelectedBy(1);
        return;
      case PageCommand.start:
        state.moveSelectedToStart();
        return;
      case PageCommand.end:
        state.moveSelectedToEnd();
        return;
      case PageCommand.position:
        return;
    }
  }

  static void announceMove({
    required BuildContext context,
    required RearrangeState state,
  }) {
    final page = state.selectedPageNumber;
    if (page == null || !context.mounted) return;

    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery?.supportsAnnounce != true) return;

    SemanticsService.sendAnnouncement(
      View.of(context),
      'Original page $page moved to position ${state.selectedPageIndex + 1}',
      Directionality.of(context),
    );
  }

  static List<PopupMenuEntry<String>> buildPopupItems({
    required int index,
    required int pageOrderLength,
  }) {
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
}

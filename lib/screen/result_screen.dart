import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.taskTitle,
    required this.fileCount,
    this.fileName,
  });

  final String taskTitle;
  final int fileCount;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(title: Text(taskTitle)),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: M3EContainer.verySunny(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    width: MediaQuery.of(context).size.shortestSide * 0.6,
                    height: MediaQuery.of(context).size.shortestSide * 0.6,
                    child: Icon(
                      Icons.check,
                      size: MediaQuery.of(context).size.shortestSide * 0.3,
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
                          '$fileCount files',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                      if (fileName != null)
                        Text(
                          fileName!,
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
                          'Successfully ${taskTitle}d!',
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: M3EFilledButton(
          size: .md,
          onPressed: () => Navigator.pop(context),
          child: Text('Done'),
        ),
      ),
    );
  }
}

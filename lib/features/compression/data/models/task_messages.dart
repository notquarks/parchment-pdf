class TaskMessages {
  const TaskMessages({
    required this.title,
    required this.progress,
    required this.success,
    String? failure,
  }) : failure = failure ?? '$title failed';

  final String title;
  final String progress;
  final String success;
  final String failure;

  static const split = TaskMessages(
    title: 'Split',
    progress: 'Splitting…',
    success: 'Successfully Split!',
  );

  static const rearrange = TaskMessages(
    title: 'Rearrange',
    progress: 'Rearranging…',
    success: 'Successfully Rearranged!',
  );

  static const merge = TaskMessages(
    title: 'Merge',
    progress: 'Merging…',
    success: 'Successfully Merged!',
  );

  static const compress = TaskMessages(
    title: 'Compress',
    progress: 'Compressing…',
    success: 'Successfully Compressed!',
  );

  static const trim = TaskMessages(
    title: 'Trim',
    progress: 'Trimming…',
    success: 'Successfully Trimmed!',
  );
}

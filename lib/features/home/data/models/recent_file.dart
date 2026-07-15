class RecentFile {
  final int? id;
  final String filePath;
  final String fileName;
  final String operationType;
  final int inputFileCount;
  final int timestamp;

  const RecentFile({
    this.id,
    required this.filePath,
    required this.fileName,
    required this.operationType,
    required this.inputFileCount,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'fileName': fileName,
      'operationType': operationType,
      'inputFileCount': inputFileCount,
      'timestamp': timestamp,
    };
  }

  factory RecentFile.fromMap(Map<String, dynamic> map) {
    return RecentFile(
      id: map['id'] as int?,
      filePath: map['filePath'] as String,
      fileName: map['fileName'] as String,
      operationType: map['operationType'] as String,
      inputFileCount: map['inputFileCount'] as int,
      timestamp: map['timestamp'] as int,
    );
  }
}
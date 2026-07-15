import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pdf_tools/features/home/data/models/recent_file.dart';

class RecentFilesService {
  static const _dbName = 'recent_files.db';
  static const _table = 'recent_files';
  static const _maxFiles = 50;

  late Database _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, _dbName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filePath TEXT NOT NULL,
            fileName TEXT NOT NULL,
            operationType TEXT NOT NULL,
            inputFileCount INTEGER NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<List<RecentFile>> getRecentFiles() async {
    final maps = await _db.query(_table, orderBy: 'timestamp DESC');
    return maps.map((map) => RecentFile.fromMap(map)).toList();
  }

  Future<void> addRecentFile(RecentFile file) async {
    final files = await getRecentFiles();
    if (files.length >= _maxFiles) {
      final toDelete = files.sublist(_maxFiles - 1);
      for (final old in toDelete) {
        await _db.delete(_table, where: 'id = ?', whereArgs: [old.id]);
      }
    }
    await _db.insert(_table, file.toJson());
  }

  Future<void> clearRecentFiles() async {
    await _db.delete(_table);
  }
}
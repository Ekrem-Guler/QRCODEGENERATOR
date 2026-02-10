import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class QRHistoryItem {
  final int? id;
  final String type;
  final String content;
  final Uint8List imageBytes;
  final DateTime createdAt;

  QRHistoryItem({
    this.id,
    required this.type,
    required this.content,
    required this.imageBytes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'content': content,
      'imageBytes': imageBytes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory QRHistoryItem.fromMap(Map<String, dynamic> map) {
    return QRHistoryItem(
      id: map['id'],
      type: map['type'],
      content: map['content'],
      imageBytes: map['imageBytes'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'qr_history.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            content TEXT NOT NULL,
            imageBytes BLOB NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> insertHistory(QRHistoryItem item) async {
    final db = await database;
    await db.insert('history', item.toMap());
    
    // Keep only last 50 items
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM history'));
    if (count != null && count > 50) {
      // Delete oldest
      await db.execute('DELETE FROM history WHERE id IN (SELECT id FROM history ORDER BY createdAt ASC LIMIT ${count - 50})');
    }
  }

  Future<List<QRHistoryItem>> getHistory() async {
    final db = await database;
    final maps = await db.query('history', orderBy: 'createdAt DESC');
    return maps.map((e) => QRHistoryItem.fromMap(e)).toList();
  }

  Future<void> deleteHistory(int id) async {
    final db = await database;
    await db.delete('history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('history');
  }
}

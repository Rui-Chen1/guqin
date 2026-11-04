import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'seed_data.dart';

/// SQLite 本地存储封装：单机离线可用的资料库与学习进度。
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<void> init() async {
    await database;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'guqin_zhishangzhiyin.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 种子资料库随版本整表重建即可（用户进度与收藏不受影响）。
        await db.execute('DROP TABLE IF EXISTS pieces');
        await db.execute('DROP TABLE IF EXISTS articles');
        await _createTables(db);
        await _seed(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pieces(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        slug TEXT,
        title TEXT NOT NULL,
        dynasty TEXT, author TEXT, mode TEXT,
        difficulty TEXT, duration_sec INTEGER,
        intro TEXT, background TEXT, tags TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS articles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        slug TEXT,
        category TEXT, title TEXT, summary TEXT, content TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites(
        item_type TEXT NOT NULL,
        item_id INTEGER NOT NULL,
        PRIMARY KEY(item_type, item_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS progress(
        key TEXT PRIMARY KEY,
        value INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _seed(Database db) async {
    final batch = db.batch();
    for (final piece in SeedData.pieces) {
      batch.insert('pieces', piece.toMap()..remove('id'));
    }
    for (final article in SeedData.articles) {
      batch.insert('articles', article.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  // ---------------- 琴曲资料 ----------------

  Future<List<GuqinPiece>> queryPieces({String? keyword, String? difficulty}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (keyword != null && keyword.trim().isNotEmpty) {
      where.add('(title LIKE ? OR author LIKE ? OR tags LIKE ?)');
      final like = '%${keyword.trim()}%';
      args..add(like)..add(like)..add(like);
    }
    if (difficulty != null && difficulty != '全部') {
      where.add('difficulty = ?');
      args.add(difficulty);
    }
    final rows = await db.query(
      'pieces',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'id ASC',
    );
    return rows.map(GuqinPiece.fromMap).toList();
  }

  Future<GuqinPiece?> findPiece(int id) async {
    final db = await database;
    final rows = await db.query('pieces', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return GuqinPiece.fromMap(rows.first);
  }

  // ---------------- 文化资料 ----------------

  Future<List<CultureArticle>> queryArticles({String? category, String? keyword}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (category != null && category != '全部') {
      where.add('category = ?');
      args.add(category);
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      where.add('(title LIKE ? OR summary LIKE ? OR content LIKE ?)');
      final like = '%${keyword.trim()}%';
      args..add(like)..add(like)..add(like);
    }
    final rows = await db.query(
      'articles',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'id ASC',
    );
    return rows.map(CultureArticle.fromMap).toList();
  }

  Future<List<String>> articleCategories() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT DISTINCT category FROM articles ORDER BY id ASC');
    return rows.map((e) => e['category'] as String).toList();
  }

  // ---------------- 收藏 ----------------

  Future<bool> isFavorite(String type, int id) async {
    final db = await database;
    final rows = await db.query(
      'favorites',
      where: 'item_type = ? AND item_id = ?',
      whereArgs: [type, id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> toggleFavorite(String type, int id) async {
    final db = await database;
    if (await isFavorite(type, id)) {
      await db.delete('favorites',
          where: 'item_type = ? AND item_id = ?', whereArgs: [type, id]);
      return false;
    }
    await db.insert('favorites', {'item_type': type, 'item_id': id});
    return true;
  }

  Future<Set<int>> favoriteIds(String type) async {
    final db = await database;
    final rows = await db.query('favorites',
        columns: ['item_id'], where: 'item_type = ?', whereArgs: [type]);
    return rows.map((e) => e['item_id'] as int).toSet();
  }

  // ---------------- 学习进度 ----------------

  Future<int> readProgress(String key) async {
    final db = await database;
    final rows = await db.query('progress', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return 0;
    return (rows.first['value'] as int?) ?? 0;
  }

  Future<void> bumpProgress(String key, [int delta = 1]) async {
    final current = await readProgress(key);
    final db = await database;
    await db.insert(
      'progress',
      {'key': key, 'value': current + delta},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, int>> allProgress() async {
    final db = await database;
    final rows = await db.query('progress');
    return {
      for (final r in rows) (r['key'] as String): (r['value'] as int?) ?? 0,
    };
  }
}

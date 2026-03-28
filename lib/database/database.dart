import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class AppDatabase extends DatabaseConnectionUser {
  AppDatabase._(super.executor);

  static const defaultHouseholdId = 'household-default';
  static const defaultUserId = 'user-default';
  static const defaultInviteCode = 'WH0001';

  final StreamController<int> _changeController =
      StreamController<int>.broadcast();
  int _revision = 0;

  Stream<int> get changes => _changeController.stream;
  int get revision => _revision;

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'wherehouse.sqlite'));
    final executor = NativeDatabase.createInBackground(file);
    final database = AppDatabase._(executor);
    await database._initialize();
    return database;
  }

  static Future<AppDatabase> inMemory() async {
    final database = AppDatabase._(NativeDatabase.memory());
    await database._initialize();
    return database;
  }

  Future<void> _initialize() async {
    await customStatement('PRAGMA foreign_keys = ON');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS households (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        invite_code TEXT NOT NULL,
        member_ids_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        household_ids_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        household_id TEXT NOT NULL,
        name TEXT NOT NULL,
        usage_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_used_at TEXT NOT NULL,
        UNIQUE (household_id, name)
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS things (
        id TEXT PRIMARY KEY,
        household_id TEXT NOT NULL,
        name TEXT NOT NULL,
        contained_in TEXT,
        location_name TEXT,
        expiry TEXT,
        notes TEXT,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        thing_type TEXT NOT NULL DEFAULT 'item',
        FOREIGN KEY (contained_in) REFERENCES things(id) ON DELETE SET NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS thing_photos (
        thing_id TEXT NOT NULL,
        photo_url TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (thing_id, photo_url),
        FOREIGN KEY (thing_id) REFERENCES things(id) ON DELETE CASCADE
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS thing_tags (
        thing_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (thing_id, tag_id),
        FOREIGN KEY (thing_id) REFERENCES things(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_things_household_updated '
      'ON things(household_id, updated_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_things_contained_in '
      'ON things(contained_in)',
    );
    await _seedDefaults();
  }

  Future<void> _seedDefaults() async {
    final existing = await customSelect(
      'SELECT id FROM households WHERE id = ? LIMIT 1',
      variables: [
        Variable.withString(defaultHouseholdId),
      ],
    ).getSingleOrNull();

    if (existing != null) {
      return;
    }

    final now = DateTime.now().toIso8601String();
    final uuid = const Uuid();
    await transaction(() async {
      await customInsert(
        '''
          INSERT INTO households (
            id, name, invite_code, member_ids_json, created_at, updated_at
          )
          VALUES (?, ?, ?, ?, ?, ?)
        ''',
        variables: [
          Variable.withString(defaultHouseholdId),
          Variable.withString('我家'),
          Variable.withString(defaultInviteCode),
          Variable.withString('["$defaultUserId"]'),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      await customInsert(
        '''
          INSERT INTO users (
            id, name, household_ids_json, created_at, updated_at
          )
          VALUES (?, ?, ?, ?, ?)
        ''',
        variables: [
          Variable.withString(defaultUserId),
          Variable.withString('我'),
          Variable.withString('["$defaultHouseholdId"]'),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );

      const defaults = <String>[
        '药品',
        '止痛',
        '感冒常备',
        '儿童用药',
        '食品',
        '清洁',
        '衣物',
        '换季',
        '数码',
        '工具',
      ];

      for (final tag in defaults) {
        await customInsert(
          '''
            INSERT INTO tags (
              id, household_id, name, usage_count, status, created_at, last_used_at
            )
            VALUES (?, ?, ?, 0, 'active', ?, ?)
          ''',
          variables: [
            Variable.withString(uuid.v4()),
            Variable.withString(defaultHouseholdId),
            Variable.withString(tag),
            Variable.withString(now),
            Variable.withString(now),
          ],
        );
      }
    });
    notifyChanged();
  }

  void notifyChanged() {
    _revision += 1;
    if (!_changeController.isClosed) {
      _changeController.add(_revision);
    }
  }

  @override
  void close() {
    _changeController.close();
    super.close();
  }
}


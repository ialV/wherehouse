import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/household.dart';
import '../../models/thing.dart';
import '../database.dart';

class ThingDao {
  ThingDao(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Stream<List<Thing>> watchRecentThings() {
    return _watch(() => searchThings(limit: 8, includeLocations: false));
  }

  Stream<List<Thing>> watchItems() {
    return _watch(() => searchThings());
  }

  Stream<List<Thing>> watchSearchResults(String query) {
    return _watch(() => searchThings(query: query));
  }

  Stream<List<Tag>> watchTags() {
    return _watch(loadTags);
  }

  Stream<List<Thing>> watchLocations() {
    return _watch(() => loadLocations());
  }

  Future<List<Tag>> loadTags() async {
    final rows = await _database.customSelect(
      '''
        SELECT * FROM tags
        WHERE household_id = ? AND status = 'active'
        ORDER BY usage_count DESC, last_used_at DESC, name COLLATE NOCASE
      ''',
      variables: [
        Variable.withString(AppDatabase.defaultHouseholdId),
      ],
    ).get();

    return rows.map(_mapTag).toList();
  }

  Future<List<Thing>> loadLocations() async {
    final rows = await _database.customSelect(
      '''
        SELECT * FROM things
        WHERE household_id = ? AND thing_type = 'location'
        ORDER BY updated_at DESC, name COLLATE NOCASE
      ''',
      variables: [
        Variable.withString(AppDatabase.defaultHouseholdId),
      ],
    ).get();
    return Future.wait(rows.map(_hydrateThing));
  }

  Future<List<Thing>> searchThings({
    String query = '',
    int? limit,
    bool includeLocations = true,
  }) async {
    final variables = <Variable>[
      Variable.withString(AppDatabase.defaultHouseholdId),
    ];
    final buffer = StringBuffer('''
      SELECT * FROM things
      WHERE household_id = ?
    ''');

    if (!includeLocations) {
      buffer.write(" AND thing_type != 'location' ");
    }

    if (query.trim().isNotEmpty) {
      final like = '%${query.trim().toLowerCase()}%';
      buffer.write('''
        AND (
          LOWER(name) LIKE ?
          OR LOWER(COALESCE(notes, '')) LIKE ?
          OR LOWER(COALESCE(location_name, '')) LIKE ?
          OR id IN (
            SELECT tt.thing_id
            FROM thing_tags tt
            JOIN tags t ON t.id = tt.tag_id
            WHERE LOWER(t.name) LIKE ?
          )
        )
      ''');
      variables.addAll([
        Variable.withString(like),
        Variable.withString(like),
        Variable.withString(like),
        Variable.withString(like),
      ]);
    }

    buffer.write(' ORDER BY updated_at DESC ');

    if (limit != null) {
      buffer.write(' LIMIT ? ');
      variables.add(Variable.withInt(limit));
    }

    final rows = await _database.customSelect(
      buffer.toString(),
      variables: variables,
    ).get();

    return Future.wait(rows.map(_hydrateThing));
  }

  Future<Thing?> getThing(String id) async {
    final row = await _database.customSelect(
      'SELECT * FROM things WHERE id = ? LIMIT 1',
      variables: [
        Variable.withString(id),
      ],
    ).getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _hydrateThing(row);
  }

  Future<List<Thing>> getLocationChain(String thingId) async {
    final chain = <Thing>[];
    var current = await getThing(thingId);
    final visited = <String>{};

    while (current?.containedIn != null &&
        current != null &&
        !visited.contains(current.containedIn)) {
      visited.add(current.id);
      final parent = await getThing(current.containedIn!);
      if (parent == null) {
        break;
      }
      chain.add(parent);
      current = parent;
    }

    return chain;
  }

  Future<Tag?> findTagByName(String name) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    final row = await _database.customSelect(
      '''
        SELECT * FROM tags
        WHERE household_id = ? AND LOWER(name) = ?
        LIMIT 1
      ''',
      variables: [
        Variable.withString(AppDatabase.defaultHouseholdId),
        Variable.withString(normalized),
      ],
    ).getSingleOrNull();

    return row == null ? null : _mapTag(row);
  }

  Future<Tag> createTag(String name) async {
    final existing = await findTagByName(name);
    if (existing != null) {
      return existing;
    }

    final now = DateTime.now().toIso8601String();
    final tag = Tag(
      id: _uuid.v4(),
      householdId: AppDatabase.defaultHouseholdId,
      name: name.trim(),
      usageCount: 0,
      status: 'active',
      createdAt: DateTime.now(),
      lastUsedAt: DateTime.now(),
    );

    await _database.customInsert(
      '''
        INSERT INTO tags (
          id, household_id, name, usage_count, status, created_at, last_used_at
        )
        VALUES (?, ?, ?, 0, 'active', ?, ?)
      ''',
      variables: [
        Variable.withString(tag.id),
        Variable.withString(tag.householdId),
        Variable.withString(tag.name),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    _database.notifyChanged();
    return tag;
  }

  Future<String?> ensureLocationThing(String? locationName) async {
    final normalized = locationName?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    final existing = await _database.customSelect(
      '''
        SELECT id FROM things
        WHERE household_id = ?
          AND thing_type = 'location'
          AND LOWER(name) = ?
        LIMIT 1
      ''',
      variables: [
        Variable.withString(AppDatabase.defaultHouseholdId),
        Variable.withString(normalized.toLowerCase()),
      ],
    ).getSingleOrNull();

    if (existing != null) {
      return existing.data['id'] as String?;
    }

    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await _database.customInsert(
      '''
        INSERT INTO things (
          id, household_id, name, contained_in, location_name, expiry, notes,
          created_by, created_at, updated_at, thing_type
        )
        VALUES (?, ?, ?, NULL, NULL, NULL, ?, ?, ?, ?, 'location')
      ''',
      variables: [
        Variable.withString(id),
        Variable.withString(AppDatabase.defaultHouseholdId),
        Variable.withString(normalized),
        Variable.withString('自动创建的位置节点'),
        Variable.withString(AppDatabase.defaultUserId),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    _database.notifyChanged();
    return id;
  }

  Future<String> saveDraft(ThingDraft draft) async {
    final containedInId =
        draft.containedInId ?? await ensureLocationThing(draft.locationName);
    final now = DateTime.now().toIso8601String();
    final thingId = draft.id ?? _uuid.v4();

    await _database.transaction(() async {
      if (draft.id == null) {
        await _database.customInsert(
          '''
            INSERT INTO things (
              id, household_id, name, contained_in, location_name, expiry, notes,
              created_by, created_at, updated_at, thing_type
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          variables: [
            Variable.withString(thingId),
            Variable.withString(draft.householdId),
            Variable.withString(draft.itemName.trim()),
            Variable<String>(containedInId),
            Variable<String>(_nullableTrim(draft.locationName)),
            Variable<String>(draft.expiry?.toIso8601String()),
            Variable<String>(_nullableTrim(draft.notes)),
            Variable.withString(draft.createdBy),
            Variable.withString(now),
            Variable.withString(now),
            Variable.withString(draft.thingType),
          ],
        );
      } else {
        await _database.customUpdate(
          '''
            UPDATE things
            SET name = ?, contained_in = ?, location_name = ?, expiry = ?,
                notes = ?, updated_at = ?, thing_type = ?
            WHERE id = ?
          ''',
          variables: [
            Variable.withString(draft.itemName.trim()),
            Variable<String>(containedInId),
            Variable<String>(_nullableTrim(draft.locationName)),
            Variable<String>(draft.expiry?.toIso8601String()),
            Variable<String>(_nullableTrim(draft.notes)),
            Variable.withString(now),
            Variable.withString(draft.thingType),
            Variable.withString(thingId),
          ],
          updates: const {},
        );
        await _database.customStatement(
          'DELETE FROM thing_photos WHERE thing_id = ?',
          [thingId],
        );
        await _database.customStatement(
          'DELETE FROM thing_tags WHERE thing_id = ?',
          [thingId],
        );
      }

      for (var index = 0; index < draft.imagePaths.length; index += 1) {
        await _database.customInsert(
          '''
            INSERT INTO thing_photos (thing_id, photo_url, sort_order)
            VALUES (?, ?, ?)
          ''',
          variables: [
            Variable.withString(thingId),
            Variable.withString(draft.imagePaths[index]),
            Variable.withInt(index),
          ],
        );
      }

      for (final tag in draft.selectedTags) {
        await _database.customInsert(
          '''
            INSERT OR IGNORE INTO thing_tags (thing_id, tag_id)
            VALUES (?, ?)
          ''',
          variables: [
            Variable.withString(thingId),
            Variable.withString(tag.id),
          ],
        );
      }

      await _recalculateTagHealth();
    });

    _database.notifyChanged();
    return thingId;
  }

  Future<void> deleteThing(String id) async {
    await _database.transaction(() async {
      await _database.customStatement(
        'DELETE FROM thing_photos WHERE thing_id = ?',
        [id],
      );
      await _database.customStatement(
        'DELETE FROM thing_tags WHERE thing_id = ?',
        [id],
      );
      await _database.customStatement(
        'UPDATE things SET contained_in = NULL WHERE contained_in = ?',
        [id],
      );
      await _database.customStatement(
        'DELETE FROM things WHERE id = ?',
        [id],
      );
      await _recalculateTagHealth();
    });
    _database.notifyChanged();
  }

  Future<void> _recalculateTagHealth() async {
    final usageRows = await _database.customSelect('''
      SELECT tag_id, COUNT(*) AS usage_count
      FROM thing_tags
      GROUP BY tag_id
    ''').get();

    final usageByTagId = <String, int>{
      for (final row in usageRows)
        row.data['tag_id'] as String: (row.data['usage_count'] as int?) ?? 0,
    };

    final allTags = await _database.customSelect('SELECT id FROM tags').get();
    final now = DateTime.now().toIso8601String();

    for (final row in allTags) {
      final id = row.data['id'] as String;
      final usageCount = usageByTagId[id] ?? 0;
      final status = usageCount == 0 ? 'archived' : 'active';
      await _database.customUpdate(
        '''
          UPDATE tags
          SET usage_count = ?, status = ?, last_used_at = ?
          WHERE id = ?
        ''',
        variables: [
          Variable.withInt(usageCount),
          Variable.withString(status),
          Variable.withString(now),
          Variable.withString(id),
        ],
        updates: const {},
      );
    }
  }

  Stream<T> _watch<T>(Future<T> Function() loader) async* {
    yield await loader();
    yield* _database.changes.asyncMap((_) => loader());
  }

  Future<Thing> _hydrateThing(QueryRow row) async {
    final id = row.data['id'] as String;
    final photoRows = await _database.customSelect(
      '''
        SELECT photo_url FROM thing_photos
        WHERE thing_id = ?
        ORDER BY sort_order ASC, photo_url ASC
      ''',
      variables: [
        Variable.withString(id),
      ],
    ).get();
    final tagRows = await _database.customSelect(
      '''
        SELECT t.*
        FROM thing_tags tt
        JOIN tags t ON t.id = tt.tag_id
        WHERE tt.thing_id = ?
        ORDER BY t.name COLLATE NOCASE
      ''',
      variables: [
        Variable.withString(id),
      ],
    ).get();

    String? containerName;
    final containedIn = row.data['contained_in'] as String?;
    if (containedIn != null) {
      final containerRow = await _database.customSelect(
        'SELECT name FROM things WHERE id = ? LIMIT 1',
        variables: [
          Variable.withString(containedIn),
        ],
      ).getSingleOrNull();
      containerName = containerRow?.data['name'] as String?;
    }

    return Thing(
      id: id,
      householdId: row.data['household_id'] as String,
      name: row.data['name'] as String,
      photoUrls:
          photoRows.map((entry) => entry.data['photo_url'] as String).toList(),
      tags: tagRows.map(_mapTag).toList(),
      containedIn: containedIn,
      expiry: _parseDate(row.data['expiry'] as String?),
      notes: row.data['notes'] as String?,
      createdBy: row.data['created_by'] as String,
      createdAt: DateTime.parse(row.data['created_at'] as String),
      updatedAt: DateTime.parse(row.data['updated_at'] as String),
      thingType: row.data['thing_type'] as String? ?? 'item',
      containerName: containerName ?? row.data['location_name'] as String?,
    );
  }

  Tag _mapTag(QueryRow row) {
    return Tag(
      id: row.data['id'] as String,
      householdId: row.data['household_id'] as String,
      name: row.data['name'] as String,
      usageCount: (row.data['usage_count'] as int?) ?? 0,
      status: row.data['status'] as String,
      createdAt: DateTime.parse(row.data['created_at'] as String),
      lastUsedAt: DateTime.parse(row.data['last_used_at'] as String),
    );
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<void> importSampleThing({
    required String name,
    required String locationName,
    required List<String> photoUrls,
    List<String> tagNames = const [],
  }) async {
    final tags = <Tag>[];
    for (final tagName in tagNames) {
      tags.add(await createTag(tagName));
    }

    await saveDraft(
      ThingDraft(
        itemName: name,
        imagePaths: photoUrls,
        selectedTags: tags,
        proposedTags: const [],
        householdId: AppDatabase.defaultHouseholdId,
        createdBy: AppDatabase.defaultUserId,
        locationName: locationName,
        notes: '示例导入',
      ),
    );
  }

  String encodeStringList(List<String> values) {
    return jsonEncode(values);
  }
}

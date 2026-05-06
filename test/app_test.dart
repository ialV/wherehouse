import 'package:flutter_test/flutter_test.dart';

import 'package:wherehouse/database/database.dart';
import 'package:wherehouse/database/daos/thing_dao.dart';
import 'package:wherehouse/models/thing.dart';

void main() {
  test('saves and retrieves a thing locally', () async {
    final database = await AppDatabase.inMemory();
    final dao = ThingDao(database);
    final tag = await dao.createTag('测试标签');

    final id = await dao.saveDraft(
      ThingDraft(
        itemName: '布洛芬',
        imagePaths: const ['/tmp/ibuprofen.jpg'],
        selectedTags: [tag],
        proposedTags: const [],
        householdId: AppDatabase.defaultHouseholdId,
        createdBy: AppDatabase.defaultUserId,
        locationName: '客厅药箱',
        notes: '测试数据',
        barcode: '6901234567890',
      ),
    );

    final saved = await dao.getThing(id);
    final searchResults = await dao.searchThings(query: '6901234567890');

    expect(saved, isNotNull);
    expect(saved!.name, '布洛芬');
    expect(saved.containerName, '客厅药箱');
    expect(saved.barcode, '6901234567890');
    expect(saved.tags.single.name, '测试标签');
    expect(searchResults.single.id, id);
  });
}

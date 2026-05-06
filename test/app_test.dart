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

  test('loads and watches container children', () async {
    final database = await AppDatabase.inMemory();
    final dao = ThingDao(database);
    const containerName = '客厅药箱';
    const firstChildName = '创可贴';
    const secondChildName = '体温计';

    final containerId = await dao.ensureLocationThing(containerName);
    expect(containerId, isNotNull);

    final firstChildId = await dao.saveDraft(
      ThingDraft(
        itemName: '退烧药',
        imagePaths: const [],
        selectedTags: const [],
        proposedTags: const [],
        householdId: AppDatabase.defaultHouseholdId,
        createdBy: AppDatabase.defaultUserId,
        containedInId: containerId,
        thingType: 'item',
      ),
    );

    final secondChildId = await dao.saveDraft(
      ThingDraft(
        itemName: firstChildName,
        imagePaths: const [],
        selectedTags: const [],
        proposedTags: const [],
        householdId: AppDatabase.defaultHouseholdId,
        createdBy: AppDatabase.defaultUserId,
        containedInId: containerId,
        thingType: 'item',
      ),
    );

    final nestedLocationId = await dao.saveDraft(
      ThingDraft(
        itemName: '药箱内隔层',
        imagePaths: const [],
        selectedTags: const [],
        proposedTags: const [],
        householdId: AppDatabase.defaultHouseholdId,
        createdBy: AppDatabase.defaultUserId,
        containedInId: containerId,
        thingType: 'location',
      ),
    );

    final children = await dao.loadContainerChildren(containerId);
    expect(
      children.map((child) => child.id),
      unorderedEquals([firstChildId, secondChildId]),
    );
    expect(children.every((child) => child.containedIn == containerId), isTrue);
    expect(children.every((child) => child.containerName == containerName), isTrue);
    expect(children.any((child) => child.id == nestedLocationId), isFalse);

    final includeLocationChildren = await dao.loadContainerChildren(
      containerId,
      includeLocations: true,
    );
    expect(includeLocationChildren, hasLength(3));

    final watchFuture = expectLater(
      dao.watchContainerChildren(containerId).take(2),
      emitsInOrder([
        predicate<List<Thing>>(
          (items) =>
              items.length == 2 &&
              items.every((item) => item.containedIn == containerId) &&
              items.every((item) => item.containerName == containerName),
        ),
        predicate<List<Thing>>(
          (items) =>
              items.length == 3 &&
              items.every((item) => item.containedIn == containerId) &&
              items.any((item) => item.name == secondChildName) &&
              items.any((item) => item.name == firstChildName),
        ),
      ]),
    );

    await dao.saveDraft(
      ThingDraft(
        itemName: secondChildName,
        imagePaths: const [],
        selectedTags: const [],
        proposedTags: const [],
        householdId: AppDatabase.defaultHouseholdId,
        createdBy: AppDatabase.defaultUserId,
        containedInId: containerId,
        thingType: 'item',
      ),
    );

    await watchFuture;
  });
}

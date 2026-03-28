import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../database/daos/thing_dao.dart';
import '../models/household.dart';
import '../models/thing.dart';
import '../services/asr_service.dart';
import '../services/llm_service.dart';
import '../services/storage_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase must be provided from main().');
});

final thingDaoProvider = Provider<ThingDao>((ref) {
  return ThingDao(ref.watch(appDatabaseProvider));
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final llmServiceProvider = Provider<LlmService>((ref) {
  return LlmService(
    apiKey: dotenv.maybeGet('DASHSCOPE_API_KEY'),
  );
});

final asrServiceProvider = Provider<AsrService>((ref) {
  return const AsrService();
});

final recentThingsProvider = StreamProvider.autoDispose<List<Thing>>((ref) {
  return ref.watch(thingDaoProvider).watchRecentThings();
});

final browseThingsProvider = StreamProvider.autoDispose<List<Thing>>((ref) {
  return ref.watch(thingDaoProvider).watchItems();
});

final searchThingsProvider =
    StreamProvider.autoDispose.family<List<Thing>, String>((ref, query) {
  return ref.watch(thingDaoProvider).watchSearchResults(query);
});

final tagsProvider = StreamProvider.autoDispose<List<Tag>>((ref) {
  return ref.watch(thingDaoProvider).watchTags();
});

final thingProvider = FutureProvider.autoDispose.family<Thing?, String>((ref, id) {
  return ref.watch(thingDaoProvider).getThing(id);
});

final locationChainProvider =
    FutureProvider.autoDispose.family<List<Thing>, String>((ref, id) {
  return ref.watch(thingDaoProvider).getLocationChain(id);
});

final locationsProvider = StreamProvider.autoDispose<List<Thing>>((ref) {
  return ref.watch(thingDaoProvider).watchLocations();
});

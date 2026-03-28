import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/thing.dart';
import '../providers/app_providers.dart';
import '../widgets/thing_card.dart';
import 'detail_screen.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

enum BrowseMode { location, tag, all }

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  BrowseMode _mode = BrowseMode.location;

  @override
  Widget build(BuildContext context) {
    final thingsAsync = ref.watch(browseThingsProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final locationsAsync = ref.watch(locationsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '浏览',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '按位置、标签或全部物品快速扫一遍。',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<BrowseMode>(
              segments: const [
                ButtonSegment(
                  value: BrowseMode.location,
                  icon: Icon(Icons.place_outlined),
                  label: Text('位置'),
                ),
                ButtonSegment(
                  value: BrowseMode.tag,
                  icon: Icon(Icons.label_outline),
                  label: Text('标签'),
                ),
                ButtonSegment(
                  value: BrowseMode.all,
                  icon: Icon(Icons.apps_outlined),
                  label: Text('全部'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() {
                  _mode = selection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: switch (_mode) {
                BrowseMode.location =>
                  _LocationBrowse(thingsAsync: thingsAsync, locationsAsync: locationsAsync),
                BrowseMode.tag =>
                  _TagBrowse(thingsAsync: thingsAsync, tagsAsync: tagsAsync),
                BrowseMode.all => _AllBrowse(thingsAsync: thingsAsync),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AllBrowse extends StatelessWidget {
  const _AllBrowse({
    required this.thingsAsync,
  });

  final AsyncValue<List<Thing>> thingsAsync;

  @override
  Widget build(BuildContext context) {
    return thingsAsync.when(
      data: (things) {
        if (things.isEmpty) {
          return const _EmptyBrowseState(message: '还没有物品可浏览。');
        }

        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisExtent: 170,
            mainAxisSpacing: 12,
          ),
          itemCount: things.length,
          itemBuilder: (context, index) {
            final thing = things[index];
            return ThingCard(
              compact: true,
              thing: thing,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DetailScreen(thingId: thing.id),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('加载失败：$error')),
    );
  }
}

class _LocationBrowse extends StatelessWidget {
  const _LocationBrowse({
    required this.thingsAsync,
    required this.locationsAsync,
  });

  final AsyncValue<List<Thing>> thingsAsync;
  final AsyncValue<List<Thing>> locationsAsync;

  @override
  Widget build(BuildContext context) {
    return switch ((locationsAsync, thingsAsync)) {
      (AsyncData<List<Thing>> locations, AsyncData<List<Thing>> items) =>
        _LocationList(locations: locations.value, items: items.value),
      (AsyncError(:final error), _) => Center(child: Text('加载失败：$error')),
      (_, AsyncError(:final error)) => Center(child: Text('加载失败：$error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _LocationList extends StatelessWidget {
  const _LocationList({
    required this.locations,
    required this.items,
  });

  final List<Thing> locations;
  final List<Thing> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyBrowseState(message: '还没有录入任何物品。');
    }

    final grouped = <String?, List<Thing>>{};
    for (final item in items.where((thing) => !thing.isLocation)) {
      grouped.putIfAbsent(item.containedIn, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        for (final location in locations)
          if ((grouped[location.id] ?? const []).isNotEmpty)
            Card(
              child: ExpansionTile(
                title: Text(location.name),
                subtitle: Text('${grouped[location.id]!.length} 个物品'),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  for (final item in grouped[location.id]!)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ThingCard(
                        thing: item,
                        compact: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => DetailScreen(thingId: item.id),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        if ((grouped[null] ?? const []).isNotEmpty)
          Card(
            child: ExpansionTile(
              initiallyExpanded: true,
              title: const Text('未归位'),
              subtitle: Text('${grouped[null]!.length} 个物品'),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                for (final item in grouped[null]!)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ThingCard(
                      thing: item,
                      compact: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DetailScreen(thingId: item.id),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TagBrowse extends StatelessWidget {
  const _TagBrowse({
    required this.thingsAsync,
    required this.tagsAsync,
  });

  final AsyncValue<List<Thing>> thingsAsync;
  final AsyncValue<List<dynamic>> tagsAsync;

  @override
  Widget build(BuildContext context) {
    return switch ((tagsAsync, thingsAsync)) {
      (AsyncData<List<dynamic>> tags, AsyncData<List<Thing>> items) =>
        _TagList(tags: tags.value, items: items.value),
      (AsyncError(:final error), _) => Center(child: Text('加载失败：$error')),
      (_, AsyncError(:final error)) => Center(child: Text('加载失败：$error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _TagList extends StatelessWidget {
  const _TagList({
    required this.tags,
    required this.items,
  });

  final List<dynamic> tags;
  final List<Thing> items;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const _EmptyBrowseState(message: '还没有活跃标签。');
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        for (final dynamic tag in tags)
          Builder(
            builder: (context) {
              final matches =
                  items.where((item) => item.tags.any((entry) => entry.id == tag.id)).toList();
              if (matches.isEmpty) {
                return const SizedBox.shrink();
              }

              return Card(
                child: ExpansionTile(
                  title: Text(tag.name as String),
                  subtitle: Text('${matches.length} 个物品'),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    for (final item in matches)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ThingCard(
                          thing: item,
                          compact: true,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => DetailScreen(thingId: item.id),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _EmptyBrowseState extends StatelessWidget {
  const _EmptyBrowseState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}


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

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  bool _gridMode = true;

  @override
  Widget build(BuildContext context) {
    final thingsAsync = ref.watch(browseThingsProvider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '全部物品',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF2F241E),
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '按最近更新时间排序，适合整体翻找。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6E5748),
                            ),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.grid_view_rounded),
                      label: Text('网格'),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.view_agenda_rounded),
                      label: Text('列表'),
                    ),
                  ],
                  selected: {_gridMode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _gridMode = selection.first;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: thingsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const _BrowseEmptyState();
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _gridMode
                      ? _ThingGridView(items: items)
                      : _ThingListView(items: items),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('加载失败：$error'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThingGridView extends StatelessWidget {
  const _ThingGridView({required this.items});

  final List<Thing> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const ValueKey('grid'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final thing = items[index];
        return ThingCard(
          thing: thing,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DetailScreen(thingId: thing.id),
            ),
          ),
        );
      },
    );
  }
}

class _ThingListView extends StatelessWidget {
  const _ThingListView({required this.items});

  final List<Thing> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey('list'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final thing = items[index];
        return SizedBox(
          height: 132,
          child: ThingCard(
            thing: thing,
            compact: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DetailScreen(thingId: thing.id),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrowseEmptyState extends StatelessWidget {
  const _BrowseEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Color(0xFFB98268),
            ),
            const SizedBox(height: 12),
            Text(
              '还没有任何物品',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '点右下角拍一张照，先把第一件物品记进来。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6E5748),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

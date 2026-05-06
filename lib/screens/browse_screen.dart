import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/thing.dart';
import '../providers/app_providers.dart';
import '../widgets/thing_card.dart';
import 'add_screen.dart';
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
    final locationsAsync = ref.watch(locationsProvider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                const SizedBox(height: 14),
                _BatchAddPanel(
                  locationsAsync: locationsAsync,
                  onOpenContainer: _openBatchAddForContainer,
                  onCreateContainer: _openBatchAddForNewContainer,
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

  Future<void> _openBatchAddForContainer(Thing container) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddScreen(
          initialContainerId: container.id,
          initialContainerName: container.name,
        ),
      ),
    );
  }

  Future<void> _openBatchAddForNewContainer() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建位置并添加'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '输入新位置名称，比如“客厅储物柜”',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = nameController.text.trim();
                if (value.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入位置名称')),
                  );
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('开始添加'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddScreen(initialContainerName: name),
      ),
    );
  }
}

class _BatchAddPanel extends StatelessWidget {
  const _BatchAddPanel({
    required this.locationsAsync,
    required this.onOpenContainer,
    required this.onCreateContainer,
  });

  final AsyncValue<List<Thing>> locationsAsync;
  final ValueChanged<Thing> onOpenContainer;
  final VoidCallback onCreateContainer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.playlist_add, color: Color(0xFFB05F3B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '按位置入库',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onCreateContainer,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text('新建位置'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            locationsAsync.when(
              loading: () => const SizedBox(
                height: 28,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (error, _) => Text('加载位置失败：$error'),
              data: (locations) {
                if (locations.isEmpty) {
                  return const Text('还没有位置，先新建一个再开始批量添加。');
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final location in locations)
                      ActionChip(
                        label: Text(location.name),
                        onPressed: () => onOpenContainer(location),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
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

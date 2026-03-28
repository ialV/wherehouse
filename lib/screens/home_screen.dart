import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/thing.dart';
import '../providers/app_providers.dart';
import '../widgets/thing_card.dart';
import 'detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SafeArea(
      child: _HomeScreenBody(),
    );
  }
}

class _HomeScreenBody extends ConsumerStatefulWidget {
  const _HomeScreenBody();

  @override
  ConsumerState<_HomeScreenBody> createState() => _HomeScreenBodyState();
}

class _HomeScreenBodyState extends ConsumerState<_HomeScreenBody> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = _query.trim();
    final thingsAsync = trimmedQuery.isEmpty
        ? ref.watch(recentThingsProvider)
        : ref.watch(searchThingsProvider(trimmedQuery));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wherehouse',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2F241E),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  trimmedQuery.isEmpty
                      ? '最近放进去的物品，先从这里找。'
                      : '实时搜索中，输入名称、备注、位置或标签都可以。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6E5748),
                      ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '搜物品、位置、备注、标签',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: trimmedQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空搜索',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      trimmedQuery.isEmpty ? '最近录入' : '搜索结果',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2F241E),
                          ),
                    ),
                    const SizedBox(width: 10),
                    thingsAsync.maybeWhen(
                      data: (items) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE8D8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${items.length} 条',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF9C542F),
                                  ),
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        thingsAsync.when(
          data: (items) => _ThingGridSliver(
            items: items,
            query: trimmedQuery,
          ),
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => SliverFillRemaining(
            hasScrollBody: false,
            child: _MessageState(
              icon: Icons.error_outline_rounded,
              title: '加载失败',
              subtitle: '$error',
            ),
          ),
        ),
      ],
    );
  }
}

class _ThingGridSliver extends StatelessWidget {
  const _ThingGridSliver({
    required this.items,
    required this.query,
  });

  final List<Thing> items;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _MessageState(
          icon: Icons.search_off_rounded,
          title: query.isEmpty ? '还没有物品' : '没搜到结果',
          subtitle: query.isEmpty ? '点右下角“放”，先记一件进去。' : '换个关键词，或者试试标签和位置名称。',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
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
          childCount: items.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: const Color(0xFFB98268)),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6E5748),
            ),
          ),
        ],
      ),
    );
  }
}

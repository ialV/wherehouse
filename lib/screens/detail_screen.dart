import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/household.dart';
import '../models/thing.dart';
import '../providers/app_providers.dart';
import '../widgets/confirm_card.dart';
import '../widgets/location_chain.dart';

class DetailScreen extends ConsumerStatefulWidget {
  const DetailScreen({
    super.key,
    required this.thingId,
  });

  final String thingId;

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  final PageController _pageController = PageController();
  int _photoIndex = 0;
  bool _deleting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thingAsync = ref.watch(thingProvider(widget.thingId));
    final chainAsync = ref.watch(locationChainProvider(widget.thingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('物品详情'),
        actions: [
          IconButton(
            tooltip: '编辑',
            onPressed: thingAsync.valueOrNull == null || _deleting
                ? null
                : () => _openEditSheet(thingAsync.valueOrNull!),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: thingAsync.valueOrNull == null || _deleting
                ? null
                : () => _deleteThing(thingAsync.valueOrNull!),
            icon: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: thingAsync.when(
          data: (thing) {
            if (thing == null) {
              return const _DetailEmptyState();
            }

            return chainAsync.when(
              data: (chain) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                physics: const BouncingScrollPhysics(),
                children: [
                  _PhotoCarousel(
                    thing: thing,
                    controller: _pageController,
                    index: _photoIndex,
                    onPageChanged: (index) {
                      setState(() {
                        _photoIndex = index;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    thing.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2F241E),
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE8D8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          thing.isLocation ? '位置节点' : '物品',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF9C542F),
                                  ),
                        ),
                      ),
                      if (thing.expiry != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: thing.expiry!.isBefore(DateTime.now())
                                ? const Color(0xFFF7D5CC)
                                : const Color(0xFFFCE9D6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            thing.expiry!.isBefore(DateTime.now())
                                ? '已过期'
                                : '有效期 ${DateFormat('yyyy-MM-dd').format(thing.expiry!)}',
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF8F3B1B),
                                    ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  _DetailSection(
                    title: '位置路径',
                    child: LocationChain(
                      currentLabel: thing.name,
                      chain: chain,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DetailSection(
                    title: '标签',
                    child: thing.tags.isEmpty
                        ? const Text('还没有标签')
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in thing.tags)
                                Chip(
                                  label: Text(tag.name),
                                  backgroundColor: const Color(0xFFF7E3D4),
                                  side: const BorderSide(
                                    color: Color(0xFFE6C9B8),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 18),
                  _DetailSection(
                    title: '备注',
                    child: Text(
                      thing.notes?.trim().isNotEmpty == true
                          ? thing.notes!
                          : '暂无备注',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF4C392D),
                            height: 1.5,
                          ),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('位置链加载失败：$error'),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('详情加载失败：$error'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditSheet(Thing thing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF7F1E8),
      builder: (_) => _EditThingSheet(thing: thing),
    );

    if (saved == true) {
      ref.invalidate(thingProvider(widget.thingId));
      ref.invalidate(locationChainProvider(widget.thingId));
    }
  }

  Future<void> _deleteThing(Thing thing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这件物品？'),
        content: Text('会删除“${thing.name}”的记录，已存照片也会一起移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deleting = true;
    });

    try {
      final storage = ref.read(storageServiceProvider);
      await ref.read(thingDaoProvider).deleteThing(thing.id);
      for (final path in thing.photoUrls) {
        await storage.deleteImage(path);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }
}

class _PhotoCarousel extends StatelessWidget {
  const _PhotoCarousel({
    required this.thing,
    required this.controller,
    required this.index,
    required this.onPageChanged,
  });

  final Thing thing;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final imagePaths = thing.photoUrls;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 280,
            child: imagePaths.isEmpty
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFF5DFCF),
                          Color(0xFFF0C9B2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 52,
                        color: Color(0xFF8E644F),
                      ),
                    ),
                  )
                : PageView.builder(
                    controller: controller,
                    itemCount: imagePaths.length,
                    onPageChanged: onPageChanged,
                    itemBuilder: (context, pageIndex) {
                      final file = File(imagePaths[pageIndex]);
                      if (!file.existsSync()) {
                        return const Center(
                          child: Icon(Icons.broken_image_outlined, size: 42),
                        );
                      }
                      return Image.file(
                        file,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
          ),
          if (imagePaths.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var dot = 0; dot < imagePaths.length; dot++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: dot == index ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dot == index
                            ? const Color(0xFFD86F45)
                            : const Color(0xFFE6D6C3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailEmptyState extends StatelessWidget {
  const _DetailEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              '这件物品不存在了',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditThingSheet extends ConsumerStatefulWidget {
  const _EditThingSheet({
    required this.thing,
  });

  final Thing thing;

  @override
  ConsumerState<_EditThingSheet> createState() => _EditThingSheetState();
}

class _EditThingSheetState extends ConsumerState<_EditThingSheet> {
  late ThingDraft _draft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = ThingDraft(
      id: widget.thing.id,
      itemName: widget.thing.name,
      imagePaths: widget.thing.photoUrls,
      selectedTags: widget.thing.tags,
      proposedTags: const [],
      householdId: widget.thing.householdId,
      createdBy: widget.thing.createdBy,
      locationName: widget.thing.containerName,
      containedInId: widget.thing.containedIn,
      expiry: widget.thing.expiry,
      notes: widget.thing.notes,
      thingType: widget.thing.thingType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider).valueOrNull ?? const <Tag>[];
    final locations = ref.watch(locationsProvider).valueOrNull ?? const <Thing>[];
    final locationSuggestions = locations
        .map((thing) => thing.name)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '编辑物品',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ConfirmCard(
              draft: _draft,
              availableTags: tags,
              locationSuggestions: locationSuggestions,
              onChanged: (draft) {
                setState(() {
                  _draft = draft;
                });
              },
              onGhostTagTap: (_) {},
              onRemoveTag: (tag) {
                setState(() {
                  _draft = _draft.copyWith(
                    selectedTags: [
                      for (final item in _draft.selectedTags)
                        if (item.id != tag.id) item,
                    ],
                  );
                });
              },
              onAvailableTagToggle: (tag) {
                setState(() {
                  _draft = _draft.copyWith(
                    selectedTags: [..._draft.selectedTags, tag],
                  );
                });
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? '保存中…' : '保存修改'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_draft.itemName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('物品名不能为空')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await ref.read(thingDaoProvider).saveDraft(
            ThingDraft(
              id: _draft.id,
              itemName: _draft.itemName.trim(),
              imagePaths: _draft.imagePaths,
              selectedTags: _draft.selectedTags,
              proposedTags: _draft.proposedTags,
              householdId: _draft.householdId,
              createdBy: _draft.createdBy,
              locationName: _normalizeText(_draft.locationName),
              containedInId: _draft.containedInId,
              expiry: _draft.expiry,
              notes: _normalizeText(_draft.notes),
              followUp: _draft.followUp,
              followUpAsked: _draft.followUpAsked,
              thingType: _draft.thingType,
            ),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

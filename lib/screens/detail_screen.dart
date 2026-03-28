import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import '../models/household.dart';
import '../models/thing.dart';
import '../providers/app_providers.dart';
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
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  bool _initialized = false;
  DateTime? _expiry;
  List<Tag> _selectedTags = const [];
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _syncFromThing(Thing thing) {
    if (_initialized) {
      return;
    }

    _initialized = true;
    _nameController.text = thing.name;
    _locationController.text = thing.containerName ?? '';
    _notesController.text = thing.notes ?? '';
    _expiry = thing.expiry;
    _selectedTags = thing.tags;
  }

  Future<void> _pickExpiry(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _expiry ?? DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _expiry = picked;
    });
  }

  Future<void> _save(Thing thing) async {
    setState(() {
      _saving = true;
    });

    try {
      await ref.read(thingDaoProvider).saveDraft(
            ThingDraft(
              id: thing.id,
              itemName: _nameController.text.trim(),
              imagePaths: thing.photoUrls,
              selectedTags: _selectedTags,
              proposedTags: const [],
              householdId: thing.householdId,
              createdBy: thing.createdBy,
              locationName: _locationController.text.trim(),
              containedInId: null,
              expiry: _expiry,
              notes: _notesController.text.trim(),
              thingType: thing.thingType,
            ),
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存修改')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _delete(Thing thing) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('删除物品？'),
              content: Text('“${thing.name}”会从本地记录里移除。'),
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
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    for (final path in thing.photoUrls) {
      await ref.read(storageServiceProvider).deleteImage(path);
    }
    await ref.read(thingDaoProvider).deleteThing(thing.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final thingAsync = ref.watch(thingProvider(widget.thingId));
    final tagsAsync = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('物品详情'),
      ),
      body: thingAsync.when(
        data: (thing) {
          if (thing == null) {
            return const Center(child: Text('物品不存在或已删除'));
          }
          _syncFromThing(thing);

          return tagsAsync.when(
            data: (availableTags) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _HeroImage(path: thing.photoUrls.isEmpty ? null : thing.photoUrls.first),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: '物品名称',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(
                              labelText: '放置位置',
                              prefixIcon: Icon(Icons.place_outlined),
                            ),
                          ),
                          if (thing.containedIn != null) ...[
                            const SizedBox(height: 12),
                            const Text('位置链'),
                            const SizedBox(height: 8),
                            LocationChain(thingId: thing.id),
                          ],
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => _pickExpiry(context),
                            borderRadius: BorderRadius.circular(18),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFE0D3C7)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_outlined),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _expiry == null
                                          ? '有效期未知，点这里设置'
                                          : '有效期 ${DateFormat('yyyy-MM-dd').format(_expiry!)}',
                                    ),
                                  ),
                                  if (_expiry != null)
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _expiry = null;
                                        });
                                      },
                                      icon: const Icon(Icons.clear),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: '备注',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '标签',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in availableTags)
                                FilterChip(
                                  label: Text(tag.name),
                                  selected:
                                      _selectedTags.any((item) => item.id == tag.id),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedTags = [..._selectedTags, tag];
                                      } else {
                                        _selectedTags = _selectedTags
                                            .where((item) => item.id != tag.id)
                                            .toList();
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _delete(thing),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('删除'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _save(thing),
                          icon: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_saving ? '保存中...' : '保存'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('加载标签失败：$error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败：$error')),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.path,
  });

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null || !File(path!).existsSync()) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFF3D5BE),
                Color(0xFFEAB189),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            size: 72,
            color: Color(0xFF6D4E40),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.file(
        File(path!),
        fit: BoxFit.cover,
        height: 280,
      ),
    );
  }
}

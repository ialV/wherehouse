import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/household.dart';
import '../models/thing.dart';
import '../providers/app_providers.dart';
import '../widgets/confirm_card.dart';

class AddScreen extends ConsumerStatefulWidget {
  const AddScreen({super.key});

  @override
  ConsumerState<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends ConsumerState<AddScreen> {
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _descriptionController;
  late final TextEditingController _followUpController;

  File? _imageFile;
  ThingDraft? _draft;
  bool _isExtracting = false;
  bool _isRefining = false;
  bool _isSaving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _followUpController = TextEditingController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _followUpController.dispose();
    if (!_saved && _imageFile != null) {
      unawaited(
        ref.read(storageServiceProvider).deleteImage(_imageFile!.path),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final locationsAsync = ref.watch(locationsProvider);
    final availableTags = tagsAsync.valueOrNull ?? const <Tag>[];
    final locationSuggestions = (locationsAsync.valueOrNull ?? const <Thing>[])
        .map((thing) => thing.name)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('新增物品'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          physics: const BouncingScrollPhysics(),
          children: [
            _HeroPanel(
              imageFile: _imageFile,
              onCapture: _isBusy ? null : _captureImage,
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '描述一下',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '一句话就够，比如“这盒布洛芬放在厨房抽屉”。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6E5748),
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _descriptionController,
                      minLines: 2,
                      maxLines: 5,
                      enabled: !_isBusy,
                      decoration: const InputDecoration(
                        hintText: '物品是什么、放哪了、有没有有效期',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isBusy ? null : _extractDraft,
                        icon: _isExtracting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome_outlined),
                        label: Text(_isExtracting ? '识别中…' : '生成确认卡片'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_draft != null) ...[
              const SizedBox(height: 18),
              ConfirmCard(
                draft: _draft!,
                availableTags: availableTags,
                locationSuggestions: locationSuggestions,
                onChanged: (nextDraft) {
                  setState(() {
                    _draft = nextDraft;
                  });
                },
                onGhostTagTap: _promoteGhostTag,
                onRemoveTag: (tag) {
                  setState(() {
                    _draft = _draft?.copyWith(
                      selectedTags: [
                        for (final item in _draft!.selectedTags)
                          if (item.id != tag.id) item,
                      ],
                    );
                  });
                },
                onAvailableTagToggle: (tag) {
                  setState(() {
                    _draft = _draft?.copyWith(
                      selectedTags: [..._draft!.selectedTags, tag],
                    );
                  });
                },
              ),
            ],
            if (_draft?.followUp != null) ...[
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Color(0xFFB05F3B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '还差一点信息',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _draft!.followUp!.text,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF4C392D),
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _followUpController,
                        enabled: !_isBusy,
                        decoration: InputDecoration(
                          hintText: _draft!.followUp!.text,
                          prefixIcon: const Icon(Icons.edit_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isBusy ? null : _skipFollowUp,
                              child: const Text('先直接确认'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isBusy ? null : _refineDraft,
                              child: _isRefining
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('补充一下'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_draft != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isBusy ? null : _saveDraft,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_isSaving ? '保存中…' : '确认保存'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _isBusy => _isExtracting || _isRefining || _isSaving;

  Future<void> _captureImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
    );
    if (picked == null || !mounted) {
      return;
    }

    final storage = ref.read(storageServiceProvider);
    final savedFile = await storage.saveImage(File(picked.path));

    if (!mounted) {
      return;
    }

    if (_imageFile != null && _imageFile!.path != savedFile.path) {
      unawaited(storage.deleteImage(_imageFile!.path));
    }

    setState(() {
      _imageFile = savedFile;
      _draft = null;
      _followUpController.clear();
    });
  }

  Future<void> _extractDraft() async {
    if (_imageFile == null) {
      _showSnackBar('先拍一张照片');
      return;
    }

    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showSnackBar('写一句描述，识别会更准');
      return;
    }

    setState(() {
      _isExtracting = true;
    });

    try {
      final tags = await ref.read(thingDaoProvider).loadTags();
      final draft = await ref.read(llmServiceProvider).extractThing(
            imageFile: _imageFile!,
            description: description,
            availableTags: tags,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _draft = draft.copyWith(
          notes: draft.notes ?? description,
        );
      });
    } catch (error) {
      if (mounted) {
        _showSnackBar('提取失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExtracting = false;
        });
      }
    }
  }

  Future<void> _refineDraft() async {
    final currentDraft = _draft;
    if (currentDraft == null) {
      return;
    }

    setState(() {
      _isRefining = true;
    });

    try {
      final refined = await ref.read(llmServiceProvider).refineDraft(
            currentDraft: currentDraft,
            userReply: _followUpController.text,
            availableTags: await ref.read(thingDaoProvider).loadTags(),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _draft = refined;
        _followUpController.clear();
      });
    } catch (error) {
      if (mounted) {
        _showSnackBar('补充失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefining = false;
        });
      }
    }
  }

  void _skipFollowUp() {
    final currentDraft = _draft;
    if (currentDraft == null) {
      return;
    }

    setState(() {
      _draft = currentDraft.copyWith(
        clearFollowUp: true,
        followUpAsked: true,
      );
      _followUpController.clear();
    });
  }

  Future<void> _promoteGhostTag(String tagName) async {
    final currentDraft = _draft;
    if (currentDraft == null) {
      return;
    }

    try {
      final tag = await ref.read(thingDaoProvider).createTag(tagName);
      if (!mounted) {
        return;
      }

      setState(() {
        _draft = currentDraft.copyWith(
          selectedTags: [...currentDraft.selectedTags, tag],
          proposedTags: [
            for (final item in currentDraft.proposedTags)
              if (item.toLowerCase() != tagName.toLowerCase()) item,
          ],
        );
      });
    } catch (error) {
      if (mounted) {
        _showSnackBar('创建标签失败：$error');
      }
    }
  }

  Future<void> _saveDraft() async {
    final draft = _draft;
    if (draft == null) {
      _showSnackBar('先生成确认卡片');
      return;
    }
    if (draft.itemName.trim().isEmpty) {
      _showSnackBar('物品名不能为空');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(thingDaoProvider).saveDraft(
            _normalizeDraft(draft),
          );
      _saved = true;

      if (!mounted) {
        return;
      }

      _showSnackBar('已保存');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        _showSnackBar('保存失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  ThingDraft _normalizeDraft(ThingDraft draft) {
    return ThingDraft(
      id: draft.id,
      itemName: draft.itemName.trim(),
      imagePaths: draft.imagePaths,
      selectedTags: draft.selectedTags,
      proposedTags: draft.proposedTags,
      householdId: draft.householdId,
      createdBy: draft.createdBy,
      locationName: _normalizeText(draft.locationName),
      containedInId: draft.containedInId,
      expiry: draft.expiry,
      notes: _normalizeText(draft.notes),
      followUp: draft.followUp,
      followUpAsked: draft.followUpAsked,
      thingType: draft.thingType,
    );
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.imageFile,
    required this.onCapture,
  });

  final File? imageFile;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.2,
            child: imageFile == null
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFF8E0CF),
                          Color(0xFFF2C9B2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        size: 56,
                        color: Color(0xFF995A3A),
                      ),
                    ),
                  )
                : Image.file(
                    imageFile!,
                    fit: BoxFit.cover,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '先拍照，再让系统帮你整理字段',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '支持拍现有物品，也支持拍外包装或标签面。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6E5748),
                      ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(imageFile == null ? '拍照' : '重新拍照'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

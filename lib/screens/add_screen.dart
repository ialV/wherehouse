import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../database/database.dart';
import '../models/thing.dart';
import '../providers/app_providers.dart';
import '../widgets/confirm_card.dart';
import 'detail_screen.dart';

class AddScreen extends ConsumerStatefulWidget {
  const AddScreen({super.key});

  @override
  ConsumerState<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends ConsumerState<AddScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _followUpController = TextEditingController();

  XFile? _selectedImage;
  ThingDraft? _draft;
  bool _isAnalyzing = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _followUpController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedImage = picked;
      _draft = null;
    });
  }

  Future<void> _analyze() async {
    if (_selectedImage == null) {
      _showSnackBar('先拍一张照片或从相册选一张。');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar('再补一句话，比如“这个放厨房药箱里”。');
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final tags = await ref.read(thingDaoProvider).loadTags();
      final draft = await ref.read(llmServiceProvider).extractThing(
            imageFile: File(_selectedImage!.path),
            description: _descriptionController.text.trim(),
            availableTags: tags,
          );
      if (!mounted) {
        return;
      }

      setState(() {
        _draft = draft;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _applyFollowUp() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }

    final tags = await ref.read(thingDaoProvider).loadTags();
    final updated = await ref.read(llmServiceProvider).refineDraft(
          currentDraft: draft,
          userReply: _followUpController.text.trim(),
          availableTags: tags,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _draft = updated;
      _followUpController.clear();
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    final image = _selectedImage;
    if (draft == null || image == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final storage = ref.read(storageServiceProvider);
      final savedImage = await storage.saveImage(File(image.path));
      final thingId = await ref.read(thingDaoProvider).saveDraft(
            draft.copyWith(imagePaths: [savedImage.path], clearFollowUp: true),
          );
      if (!mounted) {
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DetailScreen(thingId: thingId),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _activateGhostTag(String name) async {
    final draft = _draft;
    if (draft == null) {
      return;
    }

    final tag = await ref.read(thingDaoProvider).createTag(name);
    if (!mounted) {
      return;
    }

    setState(() {
      _draft = draft.copyWith(
        selectedTags: [
          ...draft.selectedTags,
          tag,
        ],
        proposedTags: draft.proposedTags.where((item) => item != name).toList(),
      );
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;

    return Scaffold(
      appBar: AppBar(
        title: const Text('放一个'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '拍照 + 一句话',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '先记下来，信息不全也能确认，追问只做辅助。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _ImagePickerPanel(
                    imagePath: _selectedImage?.path,
                    onCameraTap: () => _pickImage(ImageSource.camera),
                    onGalleryTap: () => _pickImage(ImageSource.gallery),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '比如：这个放厨房药箱了',
                      labelText: '一句话描述',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isAnalyzing ? null : _analyze,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(_isAnalyzing ? '识别中...' : '生成确认卡片'),
                  ),
                ],
              ),
            ),
          ),
          if (draft != null) ...[
            const SizedBox(height: 16),
            ConfirmCard(
              draft: draft,
              onNameChanged: (value) {
                setState(() {
                  _draft = draft.copyWith(itemName: value);
                });
              },
              onLocationChanged: (value) {
                setState(() {
                  _draft = draft.copyWith(locationName: value);
                });
              },
              onNotesChanged: (value) {
                setState(() {
                  _draft = draft.copyWith(notes: value);
                });
              },
              onExpiryChanged: (value) {
                setState(() {
                  _draft = draft.copyWith(expiry: value);
                });
              },
              onRemoveTag: (tag) {
                setState(() {
                  _draft = draft.copyWith(
                    selectedTags:
                        draft.selectedTags.where((item) => item.id != tag.id).toList(),
                  );
                });
              },
              onAddGhostTag: _activateGhostTag,
              onRemoveGhostTag: (value) {
                setState(() {
                  _draft = draft.copyWith(
                    proposedTags:
                        draft.proposedTags.where((item) => item != value).toList(),
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '补一句也行',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _followUpController,
                      decoration: InputDecoration(
                        hintText: draft.followUp?.text ?? '比如：在右边第二层，2027 年过期',
                        helperText: draft.followUp == null
                            ? '现在不追问，直接确认也可以。'
                            : '追问原因：${draft.followUp!.reason}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _applyFollowUp,
                          child: const Text('补充更新'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(_isSaving ? '保存中...' : '确认保存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImagePickerPanel extends StatelessWidget {
  const _ImagePickerPanel({
    required this.imagePath,
    required this.onCameraTap,
    required this.onGalleryTap,
  });

  final String? imagePath;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF2D7C3),
                Color(0xFFE8B998),
                Color(0xFFCE7B54),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: imagePath == null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 56,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '先拍一张，或者从相册里挑一张',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: onCameraTap,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('拍照'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: onGalleryTap,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('相册'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: onGalleryTap,
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('换一张'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}


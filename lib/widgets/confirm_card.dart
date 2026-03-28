import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/household.dart';
import '../models/thing.dart';

class ConfirmCard extends StatefulWidget {
  const ConfirmCard({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onGhostTagTap,
    this.onRemoveTag,
    this.onAvailableTagToggle,
    this.availableTags = const [],
    this.locationSuggestions = const [],
  });

  final ThingDraft draft;
  final ValueChanged<ThingDraft> onChanged;
  final ValueChanged<String> onGhostTagTap;
  final ValueChanged<Tag>? onRemoveTag;
  final ValueChanged<Tag>? onAvailableTagToggle;
  final List<Tag> availableTags;
  final List<String> locationSuggestions;

  @override
  State<ConfirmCard> createState() => _ConfirmCardState();
}

class _ConfirmCardState extends State<ConfirmCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
  late final TextEditingController _expiryController;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _locationController = TextEditingController();
    _notesController = TextEditingController();
    _expiryController = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant ConfirmCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTagIds = widget.draft.selectedTags.map((tag) => tag.id).toSet();
    final availableTags = widget.availableTags
        .where((tag) => !selectedTagIds.contains(tag.id))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6E2D6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    color: Color(0xFFB05F3B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '确认一下，我就帮你记住了',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2F241E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '物品名',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              onChanged: (value) {
                widget.onChanged(_mergeDraft(itemName: value));
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '放在哪里',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              onChanged: (value) {
                widget.onChanged(
                  _mergeDraft(
                    locationName: value,
                    clearContainedInId: true,
                  ),
                );
              },
            ),
            if (widget.locationSuggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in widget.locationSuggestions.take(6))
                    ActionChip(
                      label: Text(suggestion),
                      onPressed: () {
                        _locationController.text = suggestion;
                        widget.onChanged(
                          _mergeDraft(
                            locationName: suggestion,
                            clearContainedInId: true,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _expiryController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: '有效期',
                prefixIcon: const Icon(Icons.event_outlined),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.draft.expiry != null)
                      IconButton(
                        tooltip: '清空有效期',
                        onPressed: () {
                          widget.onChanged(
                            _mergeDraft(clearExpiry: true),
                          );
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    IconButton(
                      tooltip: '选择日期',
                      onPressed: () => _pickExpiry(context),
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                ),
              ),
              onTap: () => _pickExpiry(context),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '备注',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.notes_rounded),
                ),
              ),
              onChanged: (value) {
                widget.onChanged(
                  _mergeDraft(
                    notes: value,
                    clearNotes: value.trim().isEmpty,
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              '标签',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in widget.draft.selectedTags)
                  InputChip(
                    label: Text(tag.name),
                    selected: true,
                    showCheckmark: false,
                    selectedColor: const Color(0xFFF6D7C7),
                    onDeleted: widget.onRemoveTag == null
                        ? null
                        : () => widget.onRemoveTag!(tag),
                  ),
                for (final tagName in widget.draft.proposedTags)
                  _GhostTagChip(
                    label: tagName,
                    onTap: () => widget.onGhostTagTap(tagName),
                  ),
              ],
            ),
            if (availableTags.isNotEmpty && widget.onAvailableTagToggle != null) ...[
              const SizedBox(height: 16),
              Text(
                '可补充标签',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6E5748),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in availableTags.take(12))
                    FilterChip(
                      label: Text(tag.name),
                      selected: false,
                      onSelected: (_) => widget.onAvailableTagToggle!(tag),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickExpiry(BuildContext context) async {
    final initialDate = widget.draft.expiry ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) {
      return;
    }

    widget.onChanged(
      _mergeDraft(
        expiry: DateTime(picked.year, picked.month, picked.day),
      ),
    );
  }

  void _syncControllers() {
    _nameController.text = widget.draft.itemName;
    _locationController.text = widget.draft.locationName ?? '';
    _notesController.text = widget.draft.notes ?? '';
    _expiryController.text = widget.draft.expiry == null
        ? ''
        : _dateFormat.format(widget.draft.expiry!);
  }

  ThingDraft _mergeDraft({
    String? itemName,
    String? locationName,
    DateTime? expiry,
    bool clearExpiry = false,
    String? notes,
    bool clearNotes = false,
    bool clearContainedInId = false,
  }) {
    return ThingDraft(
      id: widget.draft.id,
      itemName: itemName ?? widget.draft.itemName,
      imagePaths: widget.draft.imagePaths,
      selectedTags: widget.draft.selectedTags,
      proposedTags: widget.draft.proposedTags,
      householdId: widget.draft.householdId,
      createdBy: widget.draft.createdBy,
      locationName: locationName ?? widget.draft.locationName,
      containedInId: clearContainedInId ? null : widget.draft.containedInId,
      expiry: clearExpiry ? null : (expiry ?? widget.draft.expiry),
      notes: clearNotes ? null : (notes ?? widget.draft.notes),
      followUp: widget.draft.followUp,
      followUpAsked: widget.draft.followUpAsked,
      thingType: widget.draft.thingType,
    );
  }
}

class _GhostTagChip extends StatelessWidget {
  const _GhostTagChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: DottedBorder(
        color: const Color(0xFFCE7D58),
        dashPattern: const [5, 3],
        borderType: BorderType.RRect,
        radius: const Radius.circular(999),
        padding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                size: 16,
                color: Color(0xFFB96A44),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF8D4F32),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

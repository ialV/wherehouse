import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/household.dart';
import '../models/thing.dart';

class ConfirmCard extends StatelessWidget {
  const ConfirmCard({
    super.key,
    required this.draft,
    required this.onNameChanged,
    required this.onLocationChanged,
    required this.onNotesChanged,
    required this.onExpiryChanged,
    required this.onRemoveTag,
    required this.onAddGhostTag,
    required this.onRemoveGhostTag,
  });

  final ThingDraft draft;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<String> onNotesChanged;
  final ValueChanged<DateTime?> onExpiryChanged;
  final ValueChanged<Tag> onRemoveTag;
  final ValueChanged<String> onAddGhostTag;
  final ValueChanged<String> onRemoveGhostTag;

  @override
  Widget build(BuildContext context) {
    final dateText = draft.expiry == null
        ? '未知'
        : DateFormat('yyyy-MM-dd').format(draft.expiry!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确认录入',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: draft.itemName,
              decoration: const InputDecoration(
                labelText: '物品名称',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              onChanged: onNameChanged,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.locationName,
              decoration: const InputDecoration(
                labelText: '放置位置',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              onChanged: onLocationChanged,
            ),
            const SizedBox(height: 12),
            _ExpiryField(
              dateText: dateText,
              onPick: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: draft.expiry ?? DateTime.now(),
                );
                onExpiryChanged(picked);
              },
              onClear: draft.expiry == null ? null : () => onExpiryChanged(null),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '备注',
                alignLabelWithHint: true,
              ),
              onChanged: onNotesChanged,
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
                for (final tag in draft.selectedTags)
                  InputChip(
                    label: Text(tag.name),
                    onDeleted: () => onRemoveTag(tag),
                    backgroundColor: const Color(0xFFF3E9D9),
                  ),
                for (final ghost in draft.proposedTags)
                  GestureDetector(
                    onTap: () => onAddGhostTag(ghost),
                    child: DottedBorder(
                      color: const Color(0xFFB87D61),
                      borderType: BorderType.RRect,
                      radius: const Radius.circular(999),
                      dashPattern: const [5, 3],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: const Color(0xFFFFF8F2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(ghost),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => onRemoveGhostTag(ghost),
                              child: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryField extends StatelessWidget {
  const _ExpiryField({
    required this.dateText,
    required this.onPick,
    this.onClear,
  });

  final String dateText;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE0D3C7)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '有效期',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF7F736B),
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(dateText),
                ],
              ),
            ),
            IconButton(
              tooltip: onClear == null ? '选择日期' : '清空日期',
              onPressed: onClear ?? onPick,
              icon: Icon(
                onClear == null ? Icons.edit_calendar_outlined : Icons.clear,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


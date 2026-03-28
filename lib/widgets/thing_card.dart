import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/thing.dart';
import 'location_chain.dart';

class ThingCard extends StatelessWidget {
  const ThingCard({
    super.key,
    required this.thing,
    this.onTap,
    this.compact = false,
  });

  final Thing thing;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ThingImage(
                path: thing.photoUrls.isEmpty ? null : thing.photoUrls.first,
                compact: compact,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thing.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (thing.isLocation)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8E7C9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('位置'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (thing.containerName != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: Color(0xFF8F6B5C),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              thing.containerName!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    if (thing.containedIn != null) ...[
                      const SizedBox(height: 8),
                      LocationChain(
                        thingId: thing.id,
                        compact: true,
                      ),
                    ],
                    if (thing.expiry != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '有效期 ${dateFormat.format(thing.expiry!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: thing.isExpiringSoon
                                  ? const Color(0xFFB23A2A)
                                  : const Color(0xFF776B62),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    if ((thing.notes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        thing.notes!,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (thing.tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in thing.tags.take(compact ? 3 : 8))
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(tag.name),
                              side: BorderSide.none,
                              backgroundColor: const Color(0xFFF0EFEA),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThingImage extends StatelessWidget {
  const _ThingImage({
    required this.path,
    required this.compact,
  });

  final String? path;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 72.0 : 84.0;
    final radius = BorderRadius.circular(18);

    if (path == null) {
      return _FallbackThumb(size: size, radius: radius);
    }

    final file = File(path!);
    if (!file.existsSync()) {
      return _FallbackThumb(size: size, radius: radius);
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb({
    required this.size,
    required this.radius,
  });

  final double size;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF5D7BF),
            Color(0xFFE2B9A3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF6F5448)),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/thing.dart';
import '../providers/app_providers.dart';

class LocationChain extends ConsumerWidget {
  const LocationChain({
    super.key,
    required this.thingId,
    this.compact = false,
  });

  final String thingId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chainAsync = ref.watch(locationChainProvider(thingId));
    final style = Theme.of(context).textTheme.bodySmall;

    return chainAsync.when(
      data: (chain) {
        if (chain.isEmpty) {
          return Text(
            '未设置位置',
            style: style?.copyWith(color: const Color(0xFF8A7D74)),
          );
        }

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var index = 0; index < chain.length; index += 1) ...[
              if (index > 0)
                Icon(
                  Icons.chevron_right_rounded,
                  size: compact ? 14 : 18,
                  color: const Color(0xFF9E8E82),
                ),
              Chip(
                visualDensity:
                    compact ? VisualDensity.compact : VisualDensity.standard,
                backgroundColor: const Color(0xFFF5E5D8),
                label: Text(chain[index].name),
                side: BorderSide.none,
              ),
            ],
          ],
        );
      },
      loading: () => const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => Text(
        '位置链加载失败',
        style: style?.copyWith(color: Colors.red.shade400),
      ),
    );
  }
}


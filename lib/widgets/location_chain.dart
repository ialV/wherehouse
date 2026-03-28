import 'package:flutter/material.dart';

import '../models/thing.dart';

class LocationChain extends StatelessWidget {
  const LocationChain({
    super.key,
    required this.currentLabel,
    required this.chain,
  });

  final String currentLabel;
  final List<Thing> chain;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      currentLabel,
      ...chain.map((thing) => thing.name),
    ].where((label) => label.trim().isNotEmpty).toList();

    if (labels.isEmpty) {
      return Text(
        '未设置位置',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF8A7D74),
            ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 8,
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Chip(
            avatar: index == 0
                ? const Icon(Icons.inventory_2_outlined, size: 16)
                : const Icon(Icons.archive_outlined, size: 16),
            label: Text(labels[index]),
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: Color(0xFFE4D2BF)),
            backgroundColor: index == 0
                ? const Color(0xFFFFF4EA)
                : Colors.white.withOpacity(0.9),
          ),
          if (index != labels.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF8A6E5B),
              ),
            ),
        ],
      ],
    );
  }
}

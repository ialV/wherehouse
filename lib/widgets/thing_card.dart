import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/thing.dart';

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
    final locationText = thing.containerName?.trim().isNotEmpty == true
        ? thing.containerName!.trim()
        : '暂未归位';
    final expiryLabel = _buildExpiryLabel();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: compact
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 108,
                    child: _ThingThumbnail(thing: thing),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _ThingCardBody(
                        thing: thing,
                        locationText: locationText,
                        expiryLabel: expiryLabel,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1.1,
                    child: _ThingThumbnail(thing: thing),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: _ThingCardBody(
                      thing: thing,
                      locationText: locationText,
                      expiryLabel: expiryLabel,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String? _buildExpiryLabel() {
    if (thing.expiry == null) {
      return null;
    }

    final formatter = DateFormat('M月d日');
    if (thing.expiry!.isBefore(DateTime.now())) {
      return '已过期 ${formatter.format(thing.expiry!)}';
    }
    if (thing.isExpiringSoon) {
      return '临期 ${formatter.format(thing.expiry!)}';
    }
    return '效期 ${formatter.format(thing.expiry!)}';
  }
}

class _ThingCardBody extends StatelessWidget {
  const _ThingCardBody({
    required this.thing,
    required this.locationText,
    required this.expiryLabel,
  });

  final Thing thing;
  final String locationText;
  final String? expiryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          thing.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2F241E),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.place_outlined,
                size: 16,
                color: Color(0xFF88624C),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                locationText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6E5748),
                ),
              ),
            ),
          ],
        ),
        if (expiryLabel != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: thing.expiry!.isBefore(DateTime.now())
                  ? const Color(0xFFF7D5CC)
                  : const Color(0xFFFCE9D6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              expiryLabel!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF8F3B1B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ThingThumbnail extends StatelessWidget {
  const _ThingThumbnail({required this.thing});

  final Thing thing;

  @override
  Widget build(BuildContext context) {
    if (thing.photoUrls.isEmpty) {
      return const _ThingPlaceholder();
    }

    final imageFile = File(thing.photoUrls.first);
    if (!imageFile.existsSync()) {
      return const _ThingPlaceholder();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          imageFile,
          fit: BoxFit.cover,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.04),
                Colors.black.withOpacity(0.12),
              ],
            ),
          ),
        ),
        if (thing.isLocation)
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '位置',
                style: TextStyle(
                  color: Color(0xFF6E5748),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ThingPlaceholder extends StatelessWidget {
  const _ThingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF5DFCF),
            Color(0xFFF0C9B2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.inventory_2_rounded,
          size: 42,
          color: Color(0xFF8E644F),
        ),
      ),
    );
  }
}

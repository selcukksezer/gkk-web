import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/item_model.dart';
import '../../utils/item_icon_resolver.dart';

class ItemIconView extends StatelessWidget {
  const ItemIconView({
    super.key,
    required this.iconValue,
    this.itemId,
    this.itemType,
    this.size = 24,
    this.fallback = '📦',
    this.fit = BoxFit.contain,
    this.expand = false,
  });

  final String iconValue;
  final String? itemId;
  final ItemType? itemType;
  final double size;
  final String fallback;
  final BoxFit fit;
  final bool expand;

  static Future<Set<String>>? _manifestFuture;

  static Future<Set<String>> _loadManifestPaths() async {
    final String raw = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> jsonMap = json.decode(raw) as Map<String, dynamic>;
    return jsonMap.keys.toSet();
  }

  static Future<Set<String>> _manifestPaths() {
    _manifestFuture ??= _loadManifestPaths();
    return _manifestFuture!;
  }

  Widget _fallbackWidget(String raw) {
    return SizedBox(
      width: expand ? double.infinity : size,
      height: expand ? double.infinity : size,
      child: Center(
        child: Text(
          raw.isEmpty ? fallback : raw,
          style: TextStyle(fontSize: size * 0.72),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String raw = iconValue.trim();
    final List<String> candidates = ItemIconResolver.resolveCandidates(
      iconValue: iconValue,
      itemId: itemId,
      itemType: itemType,
    );

    if (candidates.isEmpty) return _fallbackWidget(raw);

    return FutureBuilder<Set<String>>(
      future: _manifestPaths(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: expand ? double.infinity : size,
            height: expand ? double.infinity : size,
          );
        }

        final Set<String> manifest = snapshot.data ?? <String>{};
        String? selected;
        for (final candidate in candidates) {
          if (manifest.contains(candidate)) {
            selected = candidate;
            break;
          }
        }

        if (selected == null) return _fallbackWidget(raw);

        return Image.asset(
          selected,
          width: expand ? double.infinity : size,
          height: expand ? double.infinity : size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return _fallbackWidget(raw);
          },
        );
      },
    );
  }
}

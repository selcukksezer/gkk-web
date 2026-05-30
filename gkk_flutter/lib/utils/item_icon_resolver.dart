import '../models/item_model.dart';

class ItemIconResolver {
  ItemIconResolver._();

  static final RegExp _emojiRegex = RegExp(
    r'^[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]+$',
    unicode: true,
  );

  static bool isLikelyAssetPath(String value) {
    final String v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    return (v.contains('/') || v.contains('\\')) &&
        (v.endsWith('.png') || v.endsWith('.jpg') || v.endsWith('.jpeg') || v.endsWith('.webp'));
  }

  static bool isLikelyEmoji(String value) {
    final String v = value.trim();
    if (v.isEmpty) return false;
    return _emojiRegex.hasMatch(v);
  }

  static String normalizeAssetPath(String iconValue) {
    final String icon = iconValue.trim();
    if (icon.startsWith('assets/icons/')) {
      return icon.replaceFirst('assets/icons/', 'assets/items/');
    }
    if (icon.startsWith('/assets/icons/')) {
      return icon.replaceFirst('/assets/icons/', 'assets/items/');
    }
    if (icon.startsWith('/assets/items/')) {
      return icon.substring(1);
    }
    return icon;
  }

  static String _folderByItemType(ItemType? itemType, String key) {
    switch (itemType) {
      case ItemType.weapon:
        return 'weapons';
      case ItemType.armor:
        return 'armor';
      case ItemType.potion:
      case ItemType.consumable:
      case ItemType.scroll:
        return 'potions';
      case ItemType.material:
      case ItemType.rune:
      case ItemType.recipe:
      case ItemType.cosmetic:
        return 'materials';
      case null:
        if (key.startsWith('wpn_')) return 'weapons';
        if (key.startsWith('arm_') || key.startsWith('chest_') || key.startsWith('head_') || key.startsWith('legs_') || key.startsWith('boots_') || key.startsWith('gloves_') || key.startsWith('ring_') || key.startsWith('neck_')) {
          return 'armor';
        }
        if (key.startsWith('potion_') || key.startsWith('scroll_') || key.startsWith('catalyst_')) {
          return 'potions';
        }
        return 'materials';
    }
  }

  static List<String> resolveCandidates({
    required String iconValue,
    String? itemId,
    ItemType? itemType,
  }) {
    final String icon = iconValue.trim();
    final String id = itemId?.trim() ?? '';

    if (icon.isNotEmpty && isLikelyAssetPath(icon)) {
      final String normalized = normalizeAssetPath(icon);
      return <String>[normalized];
    }

    String key = '';
    if (icon.isNotEmpty && !isLikelyEmoji(icon)) {
      key = icon;
    } else if (id.isNotEmpty) {
      key = id;
    }

    if (key.isEmpty) return const <String>[];

    final String folder = _folderByItemType(itemType, key);
    return <String>[
      'assets/items/$folder/$key.png',
      'assets/items/$folder/$key.webp',
      'assets/items/$folder/$key.jpg',
      'assets/items/$folder/$key.jpeg',
      'assets/items/$key.png',
      'assets/items/$key.webp',
      'assets/items/$key.jpg',
      'assets/items/$key.jpeg',
    ];
  }
}


$content = Get-Content "f:\gkk-web\gkk_flutter\lib\screens\home\widgets\hero_showcase.dart" -Raw -Encoding UTF8
$content = $content -replace "(?s)Column\(\s*children: \[.*?_buildEquipSlot.*?_buildEquipSlot.*?_buildEquipSlot.*?\]\,", "Column(children: leftSlots.map((slot) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildEquipSlot(widget.inventoryState.equippedItems[slot.key], Icons.star, slot.label))).toList(),"
Set-Content "f:\gkk-web\gkk_flutter\lib\screens\home\widgets\hero_showcase.dart" -Value $content -Encoding UTF8


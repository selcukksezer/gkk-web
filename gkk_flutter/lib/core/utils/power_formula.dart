import '../../models/inventory_model.dart';
import '../../models/player_model.dart';

class PowerBreakdown {
  const PowerBreakdown({
    required this.totalPower,
    required this.equipmentPower,
    required this.levelPower,
    required this.reputationPower,
    required this.luckPower,
  });

  final int totalPower;
  final int equipmentPower;
  final int levelPower;
  final int reputationPower;
  final int luckPower;
}

PowerBreakdown calculateTotalPower({
  required PlayerProfile player,
  required Iterable<InventoryItem?> equippedItems,
}) {
  int equipmentPower = 0;
  for (final InventoryItem? item in equippedItems) {
    if (item == null) continue;
    final double base =
        item.attack + item.defense + (item.health / 10.0) + (item.luck * 2.0);
    final double multiplier = 1 + (item.enhancementLevel * 0.15);
    equipmentPower += (base * multiplier).floor();
  }

  final int levelPower = player.level * 500;
  final int reputationPower = ((player.reputation ?? 0) * 0.1).floor();
  final int luckPower = ((player.luck ?? 0) * 50).floor();

  return PowerBreakdown(
    totalPower: equipmentPower + levelPower + reputationPower + luckPower,
    equipmentPower: equipmentPower,
    levelPower: levelPower,
    reputationPower: reputationPower,
    luckPower: luckPower,
  );
}

double calculateDungeonSuccessRate({
  required int playerTotalPower,
  required int dungeonPowerRequirement,
  required int playerLuck,
  required int reputation,
  required CharacterClass? characterClass,
  int guildLevel = 0,
  double seasonModifier = 0,
}) {
  if (dungeonPowerRequirement <= 0) {
    return 1.0;
  }

  final double ratio = playerTotalPower <= 0
      ? 0
      : playerTotalPower / dungeonPowerRequirement;

  double rate;
  if (ratio >= 1.5) {
    rate = 0.95;
  } else if (ratio >= 1.0) {
    rate = 0.70 + (ratio - 1.0) * 0.50;
  } else if (ratio >= 0.5) {
    rate = 0.25 + (ratio - 0.5) * 0.90;
  } else if (ratio >= 0.25) {
    rate = 0.10 + (ratio - 0.25) * 0.60;
  } else {
    rate = (ratio * 0.40).clamp(0.05, 0.95);
  }

  rate += (playerLuck * 0.001).clamp(0.0, 0.05);
  rate += (reputation * 0.0005).clamp(0.0, 0.025);
  rate += (guildLevel * 0.01).clamp(0.0, 0.05);

  if (characterClass == CharacterClass.warrior) {
    rate += 0.05;
  }

  rate += seasonModifier.clamp(0.0, 0.10);

  return rate.clamp(0.05, 0.95);
}

class XpProgress {
  const XpProgress({
    required this.level,
    required this.totalXp,
    required this.levelStartXp,
    required this.nextLevelTotalXp,
    required this.xpInLevel,
    required this.xpNeededInLevel,
    required this.percent,
  });

  final int level;
  final int totalXp;
  final int levelStartXp;
  final int nextLevelTotalXp;
  final int xpInLevel;
  final int xpNeededInLevel;
  final double percent;
}

int xpNeededForLevel(int level) {
  if (level < 1) return 0;
  final double raw = 100 * level * (1 + level * 0.15);
  return raw.floor();
}

int totalXpForLevel(int level) {
  if (level <= 1) return 0;
  int total = 0;
  for (int i = 1; i < level; i += 1) {
    total += xpNeededForLevel(i);
  }
  return total;
}

int levelFromTotalXp(int totalXp, {int levelCap = 70}) {
  final int safeTotalXp = totalXp < 0 ? 0 : totalXp;
  int currentLevel = 1;

  while (currentLevel < levelCap) {
    final int nextLevelTotal = totalXpForLevel(currentLevel + 1);
    if (safeTotalXp < nextLevelTotal) break;
    currentLevel += 1;
  }

  return currentLevel;
}

XpProgress buildXpProgress({
  required int level,
  required int totalXp,
  int levelCap = 70,
}) {
  final int safeLevel = level < 1 ? 1 : level;
  final int safeTotalXp = totalXp < 0 ? 0 : totalXp;
  final int derivedLevel = levelFromTotalXp(safeTotalXp, levelCap: levelCap);
  final int effectiveLevel = safeLevel > derivedLevel ? safeLevel : derivedLevel;

  if (effectiveLevel >= levelCap) {
    return XpProgress(
      level: effectiveLevel,
      totalXp: safeTotalXp,
      levelStartXp: totalXpForLevel(levelCap),
      nextLevelTotalXp: totalXpForLevel(levelCap),
      xpInLevel: 1,
      xpNeededInLevel: 1,
      percent: 1.0,
    );
  }

  final int levelStart = totalXpForLevel(effectiveLevel);
  final int nextLevelTotal = totalXpForLevel(effectiveLevel + 1);
  final int needed = (nextLevelTotal - levelStart).clamp(1, 1 << 30);
  final int currentInLevel = (safeTotalXp - levelStart).clamp(0, needed);
  final double pct = (currentInLevel / needed).clamp(0.0, 1.0);

  return XpProgress(
    level: effectiveLevel,
    totalXp: safeTotalXp,
    levelStartXp: levelStart,
    nextLevelTotalXp: nextLevelTotal,
    xpInLevel: currentInLevel,
    xpNeededInLevel: needed,
    percent: pct,
  );
}

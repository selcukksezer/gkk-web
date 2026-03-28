enum QuestDifficulty { easy, medium, hard, elite, dungeon }

enum QuestStatus { available, active, completed, failed }

QuestDifficulty _parseQuestDifficulty(dynamic value) {
  switch (value?.toString()) {
    case 'easy':
      return QuestDifficulty.easy;
    case 'hard':
      return QuestDifficulty.hard;
    case 'elite':
      return QuestDifficulty.elite;
    case 'dungeon':
      return QuestDifficulty.dungeon;
    default:
      return QuestDifficulty.medium;
  }
}

QuestStatus _parseQuestStatus(dynamic value) {
  switch (value?.toString()) {
    case 'active':
      return QuestStatus.active;
    case 'completed':
      return QuestStatus.completed;
    case 'failed':
      return QuestStatus.failed;
    default:
      return QuestStatus.available;
  }
}

String _questDifficultyToString(QuestDifficulty d) {
  switch (d) {
    case QuestDifficulty.easy:
      return 'easy';
    case QuestDifficulty.medium:
      return 'medium';
    case QuestDifficulty.hard:
      return 'hard';
    case QuestDifficulty.elite:
      return 'elite';
    case QuestDifficulty.dungeon:
      return 'dungeon';
  }
}

String _questStatusToString(QuestStatus s) {
  switch (s) {
    case QuestStatus.available:
      return 'available';
    case QuestStatus.active:
      return 'active';
    case QuestStatus.completed:
      return 'completed';
    case QuestStatus.failed:
      return 'failed';
  }
}

class QuestData {
  const QuestData({
    required this.id,
    required this.questId,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.requiredLevel,
    required this.energyCost,
    required this.goldReward,
    required this.xpReward,
    required this.gemReward,
    required this.itemRewards,
    required this.status,
    required this.progress,
    required this.progressMax,
    required this.target,
    this.expiresAt,
  });

  final String id;
  final String questId;
  final String name;
  final String description;
  final QuestDifficulty difficulty;
  final int requiredLevel;
  final int energyCost;
  final int goldReward;
  final int xpReward;
  final int gemReward;
  final List<String> itemRewards;
  final QuestStatus status;
  final int progress;
  final int progressMax;
  final int target;
  final String? expiresAt;

  factory QuestData.fromJson(Map<String, dynamic> json) {
    final dynamic itemsRaw = json['item_rewards'];
    final List<String> itemRewards = itemsRaw is List
        ? itemsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return QuestData(
      id: (json['id'] ?? '').toString(),
      questId: (json['quest_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      difficulty: _parseQuestDifficulty(json['difficulty']),
      requiredLevel: _asInt(json['required_level'], fallback: 1),
      energyCost: _asInt(json['energy_cost']),
      goldReward: _asInt(json['gold_reward']),
      xpReward: _asInt(json['xp_reward']),
      gemReward: _asInt(json['gem_reward']),
      itemRewards: itemRewards,
      status: _parseQuestStatus(json['status']),
      progress: _asInt(json['progress']),
      progressMax: _asInt(json['progress_max'], fallback: 1),
      target: _asInt(json['target'], fallback: 1),
      expiresAt: json['expires_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'quest_id': questId,
        'name': name,
        'description': description,
        'difficulty': _questDifficultyToString(difficulty),
        'required_level': requiredLevel,
        'energy_cost': energyCost,
        'gold_reward': goldReward,
        'xp_reward': xpReward,
        'gem_reward': gemReward,
        'item_rewards': itemRewards,
        'status': _questStatusToString(status),
        'progress': progress,
        'progress_max': progressMax,
        'target': target,
        'expires_at': expiresAt,
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

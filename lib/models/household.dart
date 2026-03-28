class Household {
  const Household({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.memberIds,
  });

  final String id;
  final String name;
  final String inviteCode;
  final List<String> memberIds;

  Household copyWith({
    String? id,
    String? name,
    String? inviteCode,
    List<String>? memberIds,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      memberIds: memberIds ?? this.memberIds,
    );
  }
}

class WherehouseUser {
  const WherehouseUser({
    required this.id,
    required this.name,
    required this.householdIds,
  });

  final String id;
  final String name;
  final List<String> householdIds;
}

class Tag {
  const Tag({
    required this.id,
    required this.householdId,
    required this.name,
    required this.usageCount,
    required this.status,
    required this.createdAt,
    required this.lastUsedAt,
  });

  final String id;
  final String householdId;
  final String name;
  final int usageCount;
  final String status;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  bool get isActive => status == 'active';

  Tag copyWith({
    String? id,
    String? householdId,
    String? name,
    int? usageCount,
    String? status,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      usageCount: usageCount ?? this.usageCount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}


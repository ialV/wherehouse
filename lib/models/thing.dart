import 'household.dart';

class Thing {
  const Thing({
    required this.id,
    required this.householdId,
    required this.name,
    required this.photoUrls,
    required this.tags,
    required this.containedIn,
    required this.expiry,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.thingType,
    this.containerName,
  });

  final String id;
  final String householdId;
  final String name;
  final List<String> photoUrls;
  final List<Tag> tags;
  final String? containedIn;
  final DateTime? expiry;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String thingType;
  final String? containerName;

  bool get isLocation => thingType == 'location';
  bool get hasPhotos => photoUrls.isNotEmpty;
  bool get isExpiringSoon {
    if (expiry == null) {
      return false;
    }

    final today = DateTime.now();
    final threshold = today.add(const Duration(days: 30));
    return expiry!.isBefore(threshold);
  }

  Thing copyWith({
    String? id,
    String? householdId,
    String? name,
    List<String>? photoUrls,
    List<Tag>? tags,
    String? containedIn,
    DateTime? expiry,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? thingType,
    String? containerName,
  }) {
    return Thing(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      photoUrls: photoUrls ?? this.photoUrls,
      tags: tags ?? this.tags,
      containedIn: containedIn ?? this.containedIn,
      expiry: expiry ?? this.expiry,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      thingType: thingType ?? this.thingType,
      containerName: containerName ?? this.containerName,
    );
  }
}

class FollowUpPrompt {
  const FollowUpPrompt({
    required this.text,
    required this.reason,
    required this.importance,
  });

  final String text;
  final String reason;
  final FollowUpImportance importance;
}

enum FollowUpImportance { important, gentle, none }

class ThingDraft {
  const ThingDraft({
    this.id,
    required this.itemName,
    required this.imagePaths,
    required this.selectedTags,
    required this.proposedTags,
    required this.householdId,
    required this.createdBy,
    this.locationName,
    this.containedInId,
    this.expiry,
    this.notes,
    this.followUp,
    this.followUpAsked = false,
    this.thingType = 'item',
  });

  final String? id;
  final String itemName;
  final List<String> imagePaths;
  final List<Tag> selectedTags;
  final List<String> proposedTags;
  final String householdId;
  final String createdBy;
  final String? locationName;
  final String? containedInId;
  final DateTime? expiry;
  final String? notes;
  final FollowUpPrompt? followUp;
  final bool followUpAsked;
  final String thingType;

  ThingDraft copyWith({
    String? id,
    String? itemName,
    List<String>? imagePaths,
    List<Tag>? selectedTags,
    List<String>? proposedTags,
    String? householdId,
    String? createdBy,
    String? locationName,
    String? containedInId,
    DateTime? expiry,
    String? notes,
    FollowUpPrompt? followUp,
    bool clearFollowUp = false,
    bool? followUpAsked,
    String? thingType,
  }) {
    return ThingDraft(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      imagePaths: imagePaths ?? this.imagePaths,
      selectedTags: selectedTags ?? this.selectedTags,
      proposedTags: proposedTags ?? this.proposedTags,
      householdId: householdId ?? this.householdId,
      createdBy: createdBy ?? this.createdBy,
      locationName: locationName ?? this.locationName,
      containedInId: containedInId ?? this.containedInId,
      expiry: expiry ?? this.expiry,
      notes: notes ?? this.notes,
      followUp: clearFollowUp ? null : (followUp ?? this.followUp),
      followUpAsked: followUpAsked ?? this.followUpAsked,
      thingType: thingType ?? this.thingType,
    );
  }
}


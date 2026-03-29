import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../database/database.dart';
import '../models/household.dart';
import '../models/thing.dart';
import 'debug_log.dart';

class LlmService {
  LlmService({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String? apiKey;
  final http.Client _client;

  static const _endpoint =
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  static const _visionModel = 'qwen-vl-max-latest';

  Future<ThingDraft> extractThing({
    required File imageFile,
    required String description,
    required List<Tag> availableTags,
  }) async {
    final fallback = _fallbackExtract(
      description: description,
      availableTags: availableTags,
      imagePath: imageFile.path,
      followUpAlreadyAsked: false,
    );

    final _log = DebugLog.instance;
    final key = apiKey?.trim();
    _log.add('LLM', 'apiKey present: ${key != null && key.isNotEmpty}, len=${key?.length ?? 0}');
    _log.add('LLM', 'description: "$description"');
    _log.add('LLM', 'availableTags: ${availableTags.map((t) => t.name).toList()}');
    if (key == null || key.isEmpty) {
      _log.add('LLM', '⚠️ No API key → using fallback regex path');
      return fallback;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      _log.add('LLM', 'Image size: ${bytes.length} bytes');
      final base64Image = base64Encode(bytes);
      final response = await _client.post(
        Uri.parse(_endpoint),
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $key',
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode({
          'model': _visionModel,
          'temperature': 0.1,
          'messages': [
            {
              'role': 'system',
              'content': [
                {
                  'type': 'text',
                  'text': _systemPrompt(availableTags),
                }
              ],
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  },
                },
                {
                  'type': 'text',
                  'text': '用户描述：$description',
                },
              ],
            },
          ],
        }),
      );

      _log.add('LLM', 'API response: ${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _log.add('LLM', '⚠️ HTTP error body: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
        return fallback;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) {
        _log.add('LLM', '⚠️ Empty choices in response');
        return fallback;
      }

      final message = choices.first['message'] as Map<String, dynamic>? ?? {};
      final content = message['content'];
      final rawContent = content is String ? content : jsonEncode(content);
      _log.add('LLM', 'Raw LLM content: ${rawContent.length > 800 ? rawContent.substring(0, 800) : rawContent}');
      final parsed = _extractJson(rawContent);
      if (parsed == null) {
        _log.add('LLM', '⚠️ Failed to extract JSON from content');
        return fallback;
      }

      _log.add('LLM', '✅ Parsed JSON: ${jsonEncode(parsed)}');
      return _mapDraft(
        parsed,
        description: description,
        imagePath: imageFile.path,
        availableTags: availableTags,
        followUpAlreadyAsked: false,
      );
    } catch (e, st) {
      _log.add('LLM', '❌ Exception: $e');
      _log.add('LLM', 'Stack: ${st.toString().split("\n").take(5).join(" | ")}');
      return fallback;
    }
  }

  Future<ThingDraft> refineDraft({
    required ThingDraft currentDraft,
    required String userReply,
    required List<Tag> availableTags,
  }) async {
    final reply = userReply.trim();
    if (reply.isEmpty) {
      return currentDraft.copyWith(
        clearFollowUp: true,
        followUpAsked: true,
      );
    }

    final extracted = _fallbackExtract(
      description: reply,
      availableTags: availableTags,
      imagePath: currentDraft.imagePaths.first,
      followUpAlreadyAsked: true,
    );

    return currentDraft.copyWith(
      itemName: extracted.itemName != '未命名物品'
          ? extracted.itemName
          : currentDraft.itemName,
      locationName: extracted.locationName ?? currentDraft.locationName,
      expiry: extracted.expiry ?? currentDraft.expiry,
      notes: _mergeNotes(currentDraft.notes, userReply),
      selectedTags: _mergeTags(
        currentDraft.selectedTags,
        extracted.selectedTags,
      ),
      proposedTags: _mergeStrings(
        currentDraft.proposedTags,
        extracted.proposedTags,
      ),
      clearFollowUp: true,
      followUpAsked: true,
    );
  }

  ThingDraft _mapDraft(
    Map<String, dynamic> payload, {
    required String description,
    required String imagePath,
    required List<Tag> availableTags,
    required bool followUpAlreadyAsked,
  }) {
    final itemName = (payload['item_name'] as String?)?.trim();
    final location = (payload['location'] as String?)?.trim();
    final expiry = _parseDate(payload['expiry'] as String?);
    final notes = (payload['notes'] as String?)?.trim();
    final followUpText = (payload['follow_up'] as String?)?.trim();
    final followUpReason = (payload['follow_up_reason'] as String?)?.trim();
    final importance =
        (payload['importance'] as String?)?.trim().toLowerCase() ?? 'none';

    final selectedTags = <Tag>[];
    for (final value in payload['tags_existing'] as List<dynamic>? ?? const []) {
      final tagName = '$value'.trim();
      final matched = availableTags.where(
        (tag) => tag.name.toLowerCase() == tagName.toLowerCase(),
      );
      if (matched.isNotEmpty) {
        selectedTags.add(matched.first);
      }
    }

    final proposedTags = <String>[
      for (final value in payload['tags_proposed'] as List<dynamic>? ?? const [])
        '$value'.trim(),
    ].where((value) => value.isNotEmpty).toList();

    return ThingDraft(
      itemName: itemName == null || itemName.isEmpty ? _guessItemName(description) : itemName,
      imagePaths: [imagePath],
      selectedTags: selectedTags,
      proposedTags: proposedTags,
      householdId: AppDatabase.defaultHouseholdId,
      createdBy: AppDatabase.defaultUserId,
      locationName: location,
      expiry: expiry,
      notes: notes,
      followUp: followUpAlreadyAsked || followUpText == null || followUpText.isEmpty
          ? null
          : FollowUpPrompt(
              text: followUpText,
              reason: followUpReason ?? 'llm',
              importance: _mapImportance(importance),
            ),
      followUpAsked: followUpAlreadyAsked,
    );
  }

  ThingDraft _fallbackExtract({
    required String description,
    required List<Tag> availableTags,
    required String imagePath,
    required bool followUpAlreadyAsked,
  }) {
    final normalized = description.trim();
    final itemName = _guessItemName(normalized);
    final location = _guessLocation(normalized);
    final expiry = _parseDate(_extractExpiry(normalized));
    final matchedTags = _guessExistingTags(
      text: normalized,
      availableTags: availableTags,
    );
    final proposedTags = _guessProposedTags(
      text: normalized,
      existing: matchedTags.map((tag) => tag.name).toList(),
    );

    FollowUpPrompt? followUp;
    if (!followUpAlreadyAsked) {
      if (_looksLikeMedicine(normalized) && expiry == null) {
        followUp = const FollowUpPrompt(
          text: '有看到有效期吗？',
          reason: 'medicine_missing_expiry',
          importance: FollowUpImportance.important,
        );
      } else if (location != null && _isBroadLocation(location)) {
        followUp = const FollowUpPrompt(
          text: '厨房具体哪个位置呀？',
          reason: 'location_too_broad',
          importance: FollowUpImportance.gentle,
        );
      }
    }

    return ThingDraft(
      itemName: itemName,
      imagePaths: [imagePath],
      selectedTags: matchedTags,
      proposedTags: proposedTags,
      householdId: AppDatabase.defaultHouseholdId,
      createdBy: AppDatabase.defaultUserId,
      locationName: location,
      expiry: expiry,
      notes: normalized.isEmpty ? null : normalized,
      followUp: followUp,
      followUpAsked: followUpAlreadyAsked,
    );
  }

  String _systemPrompt(List<Tag> tags) {
    final tagNames = tags.map((tag) => tag.name).toList();
    return '''
你是一个家庭物品录入助手。用户会给你一张照片和一句描述。

请严格返回一个 JSON 对象，不要输出任何额外解释。格式如下：
{
  "item_name": "物品名称",
  "location": "放置位置（另一个物品或地点名称）",
  "expiry": "有效期（ISO date，仅当提到或照片可见时）",
  "tags_existing": ["从已有词表中选择的 tag 名"],
  "tags_proposed": ["词表里没有、但建议新增的 tag 名"],
  "notes": "任何额外信息",
  "follow_up": "追问文案，null 表示不追问",
  "follow_up_reason": "追问原因（用于调试）",
  "importance": "important|gentle|none"
}

追问规则：
- 药品/食品缺有效期时，important
- 位置只有房间名时，gentle
- 信息充分时，none
- 追问必须口语化、简短、少于 20 个字
- 只允许追问一次

已有 tag 词表：${jsonEncode(tagNames)}
''';
  }

  Map<String, dynamic>? _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return null;
    }

    final jsonText = raw.substring(start, end + 1);
    final decoded = jsonDecode(jsonText);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final normalized = raw.trim().replaceAll('.', '-').replaceAll('/', '-');
    final direct = DateTime.tryParse(normalized);
    if (direct != null) {
      return DateTime(direct.year, direct.month, direct.day);
    }

    final match = RegExp(r'(\d{4})[-年](\d{1,2})(?:[-月](\d{1,2}))?')
        .firstMatch(normalized);
    if (match == null) {
      return null;
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.tryParse(match.group(3) ?? '') ?? 1;
    return DateTime(year, month, day);
  }

  String _guessItemName(String description) {
    final text = description.trim();
    if (text.isEmpty) {
      return '未命名物品';
    }

    final patterns = <RegExp>[
      RegExp(r'把(.+?)放'),
      RegExp(r'这个(.+?)(放|在)'),
      RegExp(r'(.+?)(放在|放到|在).+'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final candidate = match?.group(1)?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }

    return text.length > 12 ? text.substring(0, 12) : text;
  }

  String? _guessLocation(String description) {
    final patterns = <RegExp>[
      RegExp(r'放在(.+)$'),
      RegExp(r'放到(.+)$'),
      RegExp(r'在(.+)$'),
      RegExp(r'放(.+)$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(description);
      final candidate = match?.group(1)?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        return candidate.replaceAll('了', '').trim();
      }
    }

    return null;
  }

  String? _extractExpiry(String text) {
    final match = RegExp(
      r'(20\d{2}[./-]\d{1,2}(?:[./-]\d{1,2})?)|(20\d{2}年\d{1,2}月(?:\d{1,2}日)?)',
    ).firstMatch(text);
    return match?.group(0);
  }

  List<Tag> _guessExistingTags({
    required String text,
    required List<Tag> availableTags,
  }) {
    final lowered = text.toLowerCase();
    final matched = <Tag>[];

    void tryAdd(String keyword, String tagName) {
      if (!lowered.contains(keyword)) {
        return;
      }
      final tag = availableTags.where(
        (item) => item.name.toLowerCase() == tagName.toLowerCase(),
      );
      if (tag.isNotEmpty) {
        matched.add(tag.first);
      }
    }

    if (_looksLikeMedicine(text)) {
      tryAdd('药', '药品');
      tryAdd('布洛芬', '止痛');
      tryAdd('退烧', '感冒常备');
      tryAdd('儿童', '儿童用药');
    }

    if (lowered.contains('洗') || lowered.contains('衣')) {
      tryAdd('衣', '衣物');
      tryAdd('换季', '换季');
    }

    if (lowered.contains('吃') || lowered.contains('饼干') || lowered.contains('零食')) {
      tryAdd('吃', '食品');
      tryAdd('饼干', '食品');
      tryAdd('零食', '食品');
    }

    if (lowered.contains('清洁') || lowered.contains('洗洁精')) {
      tryAdd('清洁', '清洁');
      tryAdd('洗洁精', '清洁');
    }

    return {
      for (final tag in matched) tag.id: tag,
    }.values.toList();
  }

  List<String> _guessProposedTags({
    required String text,
    required List<String> existing,
  }) {
    final lowered = text.toLowerCase();
    final tags = <String>[];

    void addIfMissing(String value) {
      if (!existing.contains(value) && !tags.contains(value)) {
        tags.add(value);
      }
    }

    if (lowered.contains('退烧')) {
      addIfMissing('退烧');
    }
    if (lowered.contains('出差')) {
      addIfMissing('出差');
    }
    if (lowered.contains('应急') || lowered.contains('急救')) {
      addIfMissing('急救');
    }
    if (lowered.contains('宝宝')) {
      addIfMissing('宝宝');
    }

    return tags;
  }

  bool _looksLikeMedicine(String text) {
    const keywords = [
      '药',
      '胶囊',
      '片',
      '口服液',
      '布洛芬',
      '阿莫西林',
      '美林',
      '对乙酰氨基酚',
    ];
    return keywords.any(text.contains);
  }

  bool _isBroadLocation(String location) {
    const broadLocations = [
      '厨房',
      '客厅',
      '卧室',
      '阳台',
      '卫生间',
      '书房',
      '餐厅',
    ];
    return broadLocations.contains(location.trim());
  }

  FollowUpImportance _mapImportance(String value) {
    switch (value) {
      case 'important':
        return FollowUpImportance.important;
      case 'gentle':
        return FollowUpImportance.gentle;
      default:
        return FollowUpImportance.none;
    }
  }

  List<Tag> _mergeTags(List<Tag> a, List<Tag> b) {
    return {
      for (final tag in [...a, ...b]) tag.id: tag,
    }.values.toList();
  }

  List<String> _mergeStrings(List<String> a, List<String> b) {
    final merged = <String>{...a, ...b};
    return merged.where((value) => value.trim().isNotEmpty).toList();
  }

  String _mergeNotes(String? existing, String next) {
    final trimmed = next.trim();
    if (existing == null || existing.trim().isEmpty) {
      return trimmed;
    }
    if (trimmed.isEmpty) {
      return existing;
    }
    return '$existing；$trimmed';
  }
}

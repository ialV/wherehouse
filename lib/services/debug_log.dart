import 'package:flutter/foundation.dart';

class DebugLog {
  DebugLog._();
  static final DebugLog instance = DebugLog._();

  final List<LogEntry> _entries = [];
  List<LogEntry> get entries => List.unmodifiable(_entries);

  void add(String tag, String message) {
    final entry = LogEntry(
      time: DateTime.now(),
      tag: tag,
      message: message,
    );
    _entries.add(entry);
    if (_entries.length > 200) {
      _entries.removeAt(0);
    }
    debugPrint('[$tag] $message');
  }

  void clear() => _entries.clear();
}

class LogEntry {
  const LogEntry({
    required this.time,
    required this.tag,
    required this.message,
  });

  final DateTime time;
  final String tag;
  final String message;

  String get formatted {
    final t = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
    return '[$t][$tag] $message';
  }
}

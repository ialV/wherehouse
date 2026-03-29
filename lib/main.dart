import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'database/database.dart';
import 'providers/app_providers.dart';
import 'services/debug_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = DebugLog.instance;

  try {
    await dotenv.load(fileName: '.env');
    final keyVal = dotenv.maybeGet('DASHSCOPE_API_KEY');
    log.add('INIT', '.env loaded OK. DASHSCOPE_API_KEY present: ${keyVal != null && keyVal.isNotEmpty}, len=${keyVal?.length ?? 0}');
    if (keyVal != null && keyVal.isNotEmpty) {
      log.add('INIT', 'Key prefix: ${keyVal.substring(0, keyVal.length > 6 ? 6 : keyVal.length)}...');
    }
  } catch (e) {
    log.add('INIT', '.env load FAILED: $e');
  }

  final database = await AppDatabase.open();
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const WherehouseApp(),
    ),
  );
}


import 'dart:convert';

import 'package:annoto/app/app.dart';
import 'package:annoto/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config =
      jsonDecode(await rootBundle.loadString('config.json'))
          as Map<String, dynamic>;
  await Supabase.initialize(
    url: config['SUPABASE_URL'] as String,
    anonKey: config['SUPABASE_ANON_KEY'] as String,
  );
  await SettingsService.load();
  runApp(const AnnotoApp());
}

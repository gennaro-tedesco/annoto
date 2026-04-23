import 'package:annoto/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('home screen renders with app bar and settings action', (
    tester,
  ) async {
    await tester.pumpWidget(const AnnotoApp());
    await tester.pump();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });
}

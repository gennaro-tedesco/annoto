import 'package:annoto/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows home title and opens settings drawer', (tester) async {
    await tester.pumpWidget(const AnnotoApp());

    expect(find.text('annoto'), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('files'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('How to'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });
}

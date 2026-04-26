import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain_app/app.dart';
import 'package:domain_app/core/storage/preferences.dart';
import 'package:domain_app/core/theme/theme_provider.dart';

void main() {
  testWidgets('App renders main screen', (WidgetTester tester) async {
    final prefs = PreferencesService();
    await prefs.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
        ],
        child: const DomainApp(),
      ),
    );

    expect(find.text('Domain'), findsOneWidget);
  });
}

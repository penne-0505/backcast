import 'package:backcast/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('shows the Riverpod startup message', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BackcastApp()));

    expect(find.text('Backcast'), findsOneWidget);
    expect(
      find.text('Flutter + Riverpod environment is ready.'),
      findsOneWidget,
    );
  });
}

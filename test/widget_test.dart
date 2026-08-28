import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/app.dart';

void main() {
  testWidgets('Studio shell shows library placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudioApp()));

    expect(find.text('Library'), findsOneWidget);
    expect(
      find.text('Library is empty. Local files will show up here.'),
      findsOneWidget,
    );
    expect(find.text('Not playing'), findsOneWidget);
  });
}

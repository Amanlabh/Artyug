import 'package:flutter_test/flutter_test.dart';
import 'package:mobilapp_artyug/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ArtyugApp());
    expect(find.byType(ArtyugApp), findsOneWidget);
  });
}

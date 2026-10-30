import 'package:flutter_test/flutter_test.dart';
import 'package:sweets_biller_web/main.dart';

void main() {
  testWidgets('RASHI ENTERPRISES Biller smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SweetsBillerApp());
    expect(find.text('RASHI ENTERPRISES Biller'), findsOneWidget);
    expect(find.text('Customer Details (Optional)'), findsOneWidget);
    expect(find.text('Add Item'), findsNWidgets(2)); // Header + Button
    expect(find.text('Bill Summary'), findsOneWidget);
    expect(find.text('Preview PDF'), findsOneWidget);
    expect(find.text('Share on WhatsApp'), findsOneWidget);
  });
}

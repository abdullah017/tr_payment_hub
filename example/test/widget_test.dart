import 'package:flutter_test/flutter_test.dart';
import 'package:tr_payment_hub_example/main.dart';

void main() {
  testWidgets('Payment form renders', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Card Number'), findsOneWidget);
    expect(find.text('Use 3D Secure'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tr_payment_hub_example/app.dart';

void main() {
  testWidgets('App renders home screen', (tester) async {
    await tester.pumpWidget(const TRPaymentHubExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('TR Payment Hub'), findsOneWidget);
  });
}

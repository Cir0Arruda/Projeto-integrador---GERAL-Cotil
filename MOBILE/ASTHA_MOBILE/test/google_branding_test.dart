import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astha_app/widgets/google_sign_in_button.dart';
void main(){
 testWidgets('Google logo uses the official bundled asset with fixed proportions', (tester) async {
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:GoogleSignInButton())));
  await tester.pumpAndSettle();
  final image=tester.widget<Image>(find.byType(Image));
  expect((image.image as AssetImage).assetName,'assets/google-g.png');
  expect(image.width,20);expect(image.height,20);expect(image.fit,BoxFit.contain);
  expect(find.text('Continuar com o Google'),findsOneWidget);expect(tester.takeException(),isNull);
 });
}

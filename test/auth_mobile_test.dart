import 'package:d/core/theme/app_theme.dart';
import 'package:d/features/auth/presentation/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpAuthAt(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.dark, home: const AuthScreen()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login fits iPhone 13 Pro Max logical viewport', (tester) async {
    await pumpAuthAt(tester, const Size(428, 926));

    expect(find.text('Sign in to save trips'), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup fits Samsung S25 FE mobile viewport', (tester) async {
    await pumpAuthAt(tester, const Size(412, 915));
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your driver account'), findsOneWidget);
    expect(find.text('SIGN UP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

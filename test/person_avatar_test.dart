import 'package:finanzas_hogar/presentation/common/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: Center(child: child)));
  }

  testWidgets('sin avatar muestra la inicial', (tester) async {
    await tester.pumpWidget(wrap(const PersonAvatar(name: 'Ana')));
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('con emoji muestra el emoji centrado', (tester) async {
    await tester.pumpWidget(
      wrap(const PersonAvatar(name: 'Ana', avatar: 'emoji:👩', radius: 30)),
    );
    expect(find.text('👩'), findsOneWidget);
  });

  testWidgets('con foto inexistente no rompe el layout', (tester) async {
    await tester.pumpWidget(
      wrap(const PersonAvatar(
        name: 'Ana',
        avatar: 'photo:/no/existe.png',
        radius: 30,
      )),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
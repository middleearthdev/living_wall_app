import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:living_wall_app/main.dart';

void main() {
  testWidgets('LivingWallApp boots with theme preview', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LivingWallApp()));
    await tester.pumpAndSettle();

    expect(find.text('Living Wall'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jokarz_engineering/main.dart';

void main() {
  testWidgets('Jokarz Engineering App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: JokarzEngineeringApp(),
      ),
    );

    // Initial frame
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);

    // Pump past initial async load
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Scaffold), findsWidgets);
  });
}

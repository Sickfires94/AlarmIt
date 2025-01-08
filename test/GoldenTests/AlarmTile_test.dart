import 'package:alarm_it/widgets/AlarmTile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';    // import your widget

void main() {
  testGoldens('AlarmTile golden test', (tester) async {
    // Build the widget
    await tester.pumpWidgetBuilder(
      MaterialApp(
        home: Scaffold(
          body: AlarmTile(
            key: Key("id"),
            title: 'Test Alarm',
            onPressed: () {},
            onDismissed: (){},
          ),
        ),
      ),
    );

    // Wait for the widget to render
    await tester.pumpAndSettle();

    // Capture and compare the widget with the golden image
    await screenMatchesGolden(tester, 'alarm_tile');
  });
}

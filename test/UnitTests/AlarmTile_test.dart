import 'package:alarm_it/widgets/AlarmTile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';  // Import your widget

void main() {
  group('AlarmTile Widget Tests', () {
    testWidgets('should call onPressed when the button is tapped', (tester) async {
      bool buttonPressed = false;

      // Build the widget with the onPressed callback
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlarmTile(
              key: Key("key"),
              title: 'Test Alarm',
              onPressed: () {
                buttonPressed = true;
              },
            ),
          ),
        ),
      );

      // Find the RawMaterialButton and tap it
      final button = find.byType(RawMaterialButton);
      await tester.tap(button);
      await tester.pumpAndSettle();

      // Check if the button was pressed
      expect(buttonPressed, true);
    });

    testWidgets('should call onDismissed when swiped', (tester) async {
      bool dismissed = false;

      // Build the widget with the onDismissed callback
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlarmTile(
              key: Key("key"),
              title: 'Test Alarm',
              onPressed: () {},
              onDismissed: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      // Find the Dismissible widget and swipe it using drag
      final dismissible = find.byType(Dismissible);
      await tester.drag(dismissible, const Offset(-500.0, 0.0)); // Drag left to dismiss
      await tester.pumpAndSettle();

      // Check if the onDismissed callback was called
      expect(dismissed, true);
    });

    testWidgets('should not dismiss if onDismissed is null', (tester) async {
      bool dismissed = false;

      // Build the widget without the onDismissed callback
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlarmTile(
              key: Key("key"),
              title: 'Test Alarm',
              onPressed: () {},
              // onDismissed is not provided
            ),
          ),
        ),
      );

      // Find the Dismissible widget and try to swipe it
      final dismissible = find.byType(Dismissible);
      await tester.drag(dismissible, const Offset(-500.0, 0.0)); // Drag left to dismiss
      await tester.pumpAndSettle();

      // Check if the onDismissed callback was NOT called
      expect(dismissed, false);
    });
  });
}

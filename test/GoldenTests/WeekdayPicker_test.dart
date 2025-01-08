import 'package:alarm_it/widgets/WeekdaysPicker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'; // Update the import path for your widget.
import 'package:golden_toolkit/golden_toolkit.dart';



void main() {
  testGoldens('WeekdaysPicker golden test with initial selection', (tester) async {
    // Define initial selection
    final initialSelectedDays = [false, true, false, true, false, false, true, false];

    // Build the widget using the golden toolkit
    await tester.pumpWidgetBuilder(
      MaterialApp(
        home: Scaffold(
          body: WeekdaysPicker(
            initialSelectedDays: initialSelectedDays,
            onSelectionChanged: (selectedDays) {},
          ),
        ),
      ),
    );

    // Capture the screenshot of the widget
    await screenMatchesGolden(tester, 'weekdays_picker_initial');
  });

  testGoldens('WeekdaysPicker golden test with all selected', (tester) async {
    // Define initial selection where all days are selected
    final initialSelectedDays = [false, true, true, true, true, true, true, true];

    // Build the widget using the golden toolkit
    await tester.pumpWidgetBuilder(
      MaterialApp(
        home: Scaffold(
          body: WeekdaysPicker(
            initialSelectedDays: initialSelectedDays,
            onSelectionChanged: (selectedDays) {},
          ),
        ),
      ),
    );

    // Capture the screenshot of the widget
    await screenMatchesGolden(tester, 'weekdays_picker_all_selected');
  });

  testGoldens('WeekdaysPicker golden test with none selected', (tester) async {
    // Define initial selection where no days are selected
    final initialSelectedDays = [false, false, false, false, false, false, false, false];

    // Build the widget using the golden toolkit
    await tester.pumpWidgetBuilder(
      MaterialApp(
        home: Scaffold(
          body: WeekdaysPicker(
            initialSelectedDays: initialSelectedDays,
            onSelectionChanged: (selectedDays) {},
          ),
        ),
      ),
    );

    // Capture the screenshot of the widget
    await screenMatchesGolden(tester, 'weekdays_picker_none_selected');
  });

  testGoldens('WeekdaysPicker golden test after toggling days', (tester) async {
    // Define initial selection
    final initialSelectedDays = [false, true, false, true, false, false, true, false];

    // Build the widget using the golden toolkit
    await tester.pumpWidgetBuilder(
      MaterialApp(
        home: Scaffold(
          body: WeekdaysPicker(
            initialSelectedDays: initialSelectedDays,
            onSelectionChanged: (selectedDays) {},
          ),
        ),
      ),
    );

    // Simulate tapping the day (e.g., toggle a day)
    await tester.tap(find.text('Mon')); // Tap Monday to toggle selection
    await tester.pump(); // Rebuild after the tap

    // Capture the screenshot of the widget after the change
    await screenMatchesGolden(tester, 'weekdays_picker_after_toggle');
  });
}

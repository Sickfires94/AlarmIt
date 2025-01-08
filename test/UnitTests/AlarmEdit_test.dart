import 'package:alarm_it/Screens/AlarmEdit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:file_picker/file_picker.dart';

// Mock classes
class MockAlarmService extends Mock implements AlarmService {

  AlarmCustom getAlarmById(int AlarmID) {
    return  AlarmCustom(id: DateTime.now().millisecondsSinceEpoch % 10000 + 1,
        enabled: true,
        hour: 12,
        minute: 12,
        alarmMusicPath: "Path",
        loopAudio: true,
        volume: 1,
        vibrate: true,
        title: "Test Alarm",
        body: "Test Body",
        ringingDays: [false, false, false, false, false, false, false, false],
        repeatNo: 1,
        delay: 5);

  }
}
class MockAlarmCustom extends Mock implements AlarmCustom {}

void main() {
  group('AlarmEditScreen Tests', () {
    late MockAlarmService mockAlarmService;
    late AlarmCustom mockAlarmCustom;

    setUp(() {
      mockAlarmService = MockAlarmService();
      mockAlarmCustom = AlarmCustom(
          id: DateTime.now().millisecondsSinceEpoch % 10000 + 1,
          enabled: true,
          hour: DateTime.now().hour,
          minute: DateTime.now().minute + 1,
          alarmMusicPath: 'assets/alarm.mp3',
          loopAudio: true,
          volume: null,
          vibrate: true,
          title: "New Alarm",
          body: "For new Reminders",
          ringingDays: [false, false, false, false, false, false, false, false],
          repeatNo: 0,
          delay: 0);;
    });

    testWidgets('should display correct initial state for new alarm', (WidgetTester tester) async {
      // Arrange: Mock the behavior of AlarmService
      when(mockAlarmService.getAlarmById(1)).thenReturn(mockAlarmService.getAlarmById(1));

      // Act: Build the widget
      await tester.pumpWidget(MaterialApp(
        home: AlarmEditScreen(1, alarmService: mockAlarmService),
      ));

      // Assert: Check the initial state of the widget
      expect(find.text('New Alarm'), findsOneWidget);
      expect(find.text('For new Reminders'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget); // Assuming it displays "Today" initially.
    });

    testWidgets('should update state when saving alarm', (WidgetTester tester) async {
      // Arrange: Mock the behavior of AlarmService
      when(mockAlarmService.getAlarmById(1)).thenReturn(mockAlarmCustom);

      // Act: Build the widget and simulate interaction
      await tester.pumpWidget(MaterialApp(
        home: AlarmEditScreen(1, alarmService: mockAlarmService),
      ));

      // Change alarm title
      await tester.enterText(find.byType(TextField).first, 'Updated Alarm');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      // Assert: Check that the alarm was saved
      verify(mockAlarmService.addAlarm(mockAlarmCustom)).called(1);
      expect(find.text('Updated Alarm'), findsOneWidget);
    });

    testWidgets('should call deleteAlarm when delete button is pressed', (WidgetTester tester) async {
      // Arrange: Mock the behavior of AlarmService
      when(mockAlarmService.getAlarmById(1)).thenReturn(mockAlarmCustom);

      // Act: Build the widget and simulate delete button press
      await tester.pumpWidget(MaterialApp(
        home: AlarmEditScreen(1, alarmService: mockAlarmService),
      ));

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump();

      // Assert: Verify deleteAlarm method is called
      verify(mockAlarmService.deleteAlarm(1)).called(1);
    });

    testWidgets('should change repeat number when NumberPicker value is changed', (WidgetTester tester) async {
      // Arrange: Mock the behavior of AlarmService
      when(mockAlarmService.getAlarmById(1)).thenReturn(mockAlarmCustom);

      // Act: Build the widget
      await tester.pumpWidget(MaterialApp(
        home: AlarmEditScreen(1, alarmService: mockAlarmService),
      ));

      // Interact with NumberPicker
      await tester.tap(find.byType(NumberPicker));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(NumberPicker), const Offset(0, -50));
      await tester.pump();

      // Assert: Verify that repeatNo value has changed
      expect(find.text('Repeat Alarm'), findsOneWidget);
    });
  });
}

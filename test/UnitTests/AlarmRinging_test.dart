import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm_it/Screens/AlarmRinging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:alarm_it/Models/AlarmSettings.dart';

// Mock classes for AlarmService and AlarmSettings
class MockAlarmService extends Mock implements AlarmService {
  void handleAlarmStop(int AlarmId){
    return;
  }
}

void main() {
  group('AlarmRingScreen Tests', () {
    late MockAlarmService mockAlarmService;
    late AlarmSettings mockAlarmSettings;

    final alarmSettings = AlarmSettings(
      id: 1,
      dateTime: DateTime.now().add(Duration(milliseconds: 10)),
      assetAudioPath: 'assets/alarm.mp3',
      volume: 1,
      notificationSettings: const NotificationSettings(
        title: 'Test Alarm',
        body: 'This is the body',
        stopButton: 'Stop the alarm',
        icon: 'notification_icon',
      ),
    );

    setUp(() {
      mockAlarmService = MockAlarmService();
      mockAlarmSettings = alarmSettings;
    });

    testWidgets('should show correct text when alarm is ringing', (WidgetTester tester) async {
      // Arrange: Mock the behavior of Alarm.isRinging
      when(mockAlarmSettings.id).thenReturn(1);
      when(mockAlarmSettings.notificationSettings.title).thenReturn('Test Alarm');
      when(mockAlarmService.handleAlarmStop(1)).thenAnswer((_) async {});

      // Act: Build the widget
      await tester.pumpWidget(MaterialApp(
        home: AlarmRingScreen(
          alarmSettings: mockAlarmSettings,
          alarmService: mockAlarmService,
        ),
      ));

      // Assert: Check if the correct text is displayed
      expect(find.text('Your alarm "Test Alarm" is ringing...'), findsOneWidget);
      //expect(find.text('🔔'), findsOneWidget);
    });

    testWidgets('should call stopAlarm when Stop button is pressed', (WidgetTester tester) async {
      // Arrange
      when(mockAlarmSettings.id).thenReturn(1);
      when(mockAlarmSettings.notificationSettings.title).thenReturn('Test Alarm');
      when(mockAlarmService.handleAlarmStop(1)).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(MaterialApp(
        home: AlarmRingScreen(
          alarmSettings: mockAlarmSettings,
          alarmService: mockAlarmService,
        ),
      ));

      // Press the "Stop" button
      await tester.tap(find.text('Stop'));
      await tester.pump();

      // Assert: Ensure handleAlarmStop was called
      verify(mockAlarmService.handleAlarmStop(mockAlarmSettings.id)).called(1);
    });

    testWidgets('should pop navigator when alarm stops ringing', (WidgetTester tester) async {
      // Arrange
      when(mockAlarmSettings.id).thenReturn(1);
      when(mockAlarmSettings.notificationSettings.title).thenReturn('Test Alarm');
      when(mockAlarmService.handleAlarmStop(1)).thenAnswer((_) async {});

      // Act: Build the widget
      await tester.pumpWidget(MaterialApp(
        home: AlarmRingScreen(
          alarmSettings: mockAlarmSettings,
          alarmService: mockAlarmService,
        ),
      ));

      // Mock the Alarm.isRinging to return false (alarm stopped)
      when(Alarm.isRinging(mockAlarmSettings.id)).thenAnswer((_) async => false);

      // Wait for timer to finish
      await tester.pumpAndSettle();

      // Assert: Ensure the navigator popped
      expect(find.byType(AlarmRingScreen), findsNothing);
    });
  });
}

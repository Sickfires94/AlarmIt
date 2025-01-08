import 'package:alarm/alarm.dart';
import 'package:alarm_it/Screens/AlarmRinging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:alarm_it/Models/AlarmSettings.dart';

class MockAlarmService extends Mock implements AlarmService {
  void handleAlarmStop(int AlarmId){
    return;
  }
}

void main() {

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

  group('AlarmRingScreen Golden Tests', () {
    late MockAlarmService mockAlarmService;
    late AlarmSettings mockAlarmSettings;

    setUp(() {
      mockAlarmService = MockAlarmService();
      mockAlarmSettings = alarmSettings;
    });


    testWidgets('renders AlarmRingScreen correctly in dark mode', (WidgetTester tester) async {
      // Arrange: Mock the behavior of Alarm.isRinging
      when(mockAlarmSettings.id).thenReturn(1);
      when(mockAlarmSettings.notificationSettings.title).thenReturn('Test Alarm');
      when(mockAlarmService.handleAlarmStop(1)).thenAnswer((_) async {});

      // Act: Build the widget
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.black,
          // Define the default brightness and colors.
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,),),
        home: AlarmRingScreen(
          alarmSettings: mockAlarmSettings,
          alarmService: mockAlarmService,
        ),
      ));

      // Assert: Verify the widget renders correctly and matches the golden file
      await expectLater(
        find.byType(AlarmRingScreen),
        matchesGoldenFile('golden/AlarmRingScreen_dark.png'),
      );
    });
  });
}

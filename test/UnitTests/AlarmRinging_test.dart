import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:alarm_it/Screens/AlarmRinging.dart';
import 'package:alarm_it/Services/AlarmFirestore.dart';
import 'package:alarm_it/Services/AlarmListBloc.dart';
import 'package:alarm_it/Services/AuthService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:mocktail/mocktail.dart';


// Mock classes for AlarmService and AlarmSettings
// class MockAlarmService extends Mock implements AlarmService {
//   void handleAlarmStop(int AlarmId){
//     return;
//   }
// }


class MockAlarmService extends Mock implements AlarmService {}
class MockFirestoreAlarmService extends Mock implements AlarmFirestoreService {}


void main() {
  group('AlarmRingScreen Tests', () {
    final MockAlarmService mockAlarmService = MockAlarmService();
    final MockFirestoreAlarmService mockFirestoreAlarmService = MockFirestoreAlarmService();

    final AlarmCustom mockAlarmCustom = AlarmCustom(
        id: 1,
        enabled: true,
        hour: 12,
        minute: 30,
        alarmMusicPath: 'assets/alarm.mp3',
        loopAudio: true,
        volume: null,
        vibrate: true,
        title: "New Alarm",
        body: "For new Reminders",
        ringingDays: [false, false, false, false, false, false, false, false],
        repeatNo: 0,
        delay: 0
    );
    mockAlarmService.alarms = [mockAlarmCustom];


    final AlarmSettings mockAlarmSettings = AlarmSettings(
      id: 1,
      dateTime: DateTime.now().copyWith(hour: mockAlarmCustom.hour, minute: mockAlarmCustom.minute),
      assetAudioPath: 'assets/alarm.mp3',
      volume: 1,
      notificationSettings: const NotificationSettings(
        title: 'Test Alarm',
        body: 'This is the body',
        stopButton: 'Stop the alarm',
        icon: 'notification_icon',
      ),
    );

    final widget =  MultiBlocProvider(
        providers: [
          BlocProvider<AlarmListBloc>(
              create:(BuildContext context) => AlarmListBloc(alarmService: mockAlarmService, alarmFirestoreService: mockFirestoreAlarmService)
          )
        ],
        child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.black,
              // Define the default brightness and colors.
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,),),
            home: Scaffold(
              body:AlarmRingScreen(alarmSettings: mockAlarmSettings),
            )
        ));


    testWidgets('should show correct text when alarm is ringing', (WidgetTester tester) async {
      // Arrange: Mock the behavior of Alarm.isRinging
      when(() => mockAlarmService.handleAlarmStop(1)).thenAnswer((_) async {});

      // Act: Build the widget
      await tester.pumpWidget(widget);

      // Assert: Check if the correct text is displayed
      expect(find.text('Your alarm "Test Alarm" is ringing...'), findsOneWidget);
      //expect(find.text('🔔'), findsOneWidget);
    });

    testWidgets('should call stopAlarm when Stop button is pressed', (WidgetTester tester) async {
      // Arrange
     when(() => mockAlarmService.handleAlarmStop(1)).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(widget);

      // Press the "Stop" button
      await tester.tap(find.text('Stop'));
      await tester.pump();

      // Assert: Ensure handleAlarmStop was called
      verify(() => mockAlarmService.handleAlarmStop(mockAlarmSettings.id)).called(1);
    });

    // testWidgets('should pop navigator when alarm stops ringing', (WidgetTester tester) async {
    //   // Arrange
    //  when(() => mockAlarmService.handleAlarmStop(1)).thenAnswer((_) {Alarm.stop(id)});
    //
    //   // Act: Build the widget
    //   await tester.pumpWidget(widget);
    //
    //   // Mock the Alarm.isRinging to return false (alarm stopped)
    //   when(() => Alarm.isRinging(mockAlarmSettings.id)).thenAnswer((_) => Future.value(false));
    //
    //   // Wait for timer to finish
    //   await tester.pumpAndSettle();
    //
    //   // Assert: Ensure the navigator popped
    //   expect(find.byType(AlarmRingScreen), findsNothing);
    // });
  });
}

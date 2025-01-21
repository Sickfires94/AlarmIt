import 'package:alarm/alarm.dart';
import 'package:alarm_it/Screens/AlarmRinging.dart';
import 'package:alarm_it/Services/AlarmFirestore.dart';
import 'package:alarm_it/Services/AlarmListBloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:mocktail/mocktail.dart';


class MockAlarmCustom extends Mock implements AlarmCustom {}
class MockAlarmService extends Mock implements AlarmService {}
class MockAlarmFirestoreService extends Mock implements AlarmFirestoreService {}

void main() {



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

  final alarmSettings = AlarmSettings(
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

  group('AlarmRingScreen Golden Tests', () {
    late MockAlarmFirestoreService mockAlarmFirestoreService;
    late MockAlarmService mockAlarmService;
    late AlarmSettings mockAlarmSettings;


    setUp(() {
      mockAlarmService = MockAlarmService();
      mockAlarmFirestoreService = MockAlarmFirestoreService();
      mockAlarmSettings = alarmSettings;
    });


    /// Should Pass but alarm Library doesn't dispose off a timer in itself :(
    testWidgets('renders AlarmRingScreen correctly in dark mode', (WidgetTester tester) async {
      // Arrange: Mock the behavior of Alarm.isRinging
      mockAlarmService.alarms = [mockAlarmCustom];
     when(() => mockAlarmService.handleAlarmStop(1)).thenAnswer((_) async {Alarm.stop(1);});

      // Act: Build the widget
      await tester.pumpWidget(MultiBlocProvider(
          providers: [
            BlocProvider<AlarmListBloc>(
                create:(BuildContext context) => AlarmListBloc(alarmService: mockAlarmService, alarmFirestoreService: mockAlarmFirestoreService)
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
        home: AlarmRingScreen(
          alarmSettings: mockAlarmSettings,
        ),
      )));

      // Assert: Verify the widget renders correctly and matches the golden file
      await expectLater(
        find.byType(AlarmRingScreen),
        matchesGoldenFile('goldens/AlarmRingScreen_dark.png'),
      );

      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle(const Duration(seconds:2));
    });
  });
}

import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:alarm_it/Screens/AlarmEdit.dart';
import 'package:alarm_it/Screens/AlarmEdit.dart';
import 'package:alarm_it/Screens/AlarmEdit.dart';
import 'package:alarm_it/Screens/AlarmEdit.dart';
import 'package:alarm_it/Screens/AlarmEdit.dart';
import 'package:alarm_it/Screens/AlarmEdit.dart';
import 'package:alarm_it/Services/AlarmEditBloc.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:alarm_it/Services/AuthService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';


class MockAlarmCustom extends Mock implements AlarmCustom {}
class MockAlarmService extends Mock implements AlarmService {}


void main() {
  final MockAlarmService mockAlarmService = MockAlarmService();
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


  final widget = MultiBlocProvider(
    providers: [
      BlocProvider<AlarmEditBloc>(
        create: (BuildContext context) =>
            AlarmEditBloc(alarmService: mockAlarmService)..add(getAlarm(AlarmId: 1)),
      ),
    ],
    child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.black,
          // Define the default brightness and colors.
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        home: Scaffold(
            body: AlarmEditScreen(),
    )));

  group('AlarmEditScreen() Golden Tests', () {
    testWidgets('renders initial state (golden)', (WidgetTester tester) async {

      when(() => mockAlarmService.getAlarmById(1)).thenReturn(mockAlarmCustom);

      await tester.pumpWidget(
        widget
      );

      await tester.pumpAndSettle();
      // Capture the screen and compare it to the golden file
      await expectLater(
        find.byType(AlarmEditScreen),
        matchesGoldenFile('goldens/alarm_editing_initial.png'),
      );
      //await tester.tap()
    });

    testWidgets('renders with pre-filled data (golden)', (WidgetTester tester) async {
      await tester.pumpWidget(
        widget
      );


      await tester.pumpAndSettle();
      // Capture the screen and compare it to a different golden file
      await expectLater(
        find.byType(AlarmEditScreen),
        matchesGoldenFile('goldens/alarm_editing_prefilled.png'),
      );
    });

    // Add more test cases for different UI states (e.g., enabled/disabled alarm, different sound selection)
  });
}
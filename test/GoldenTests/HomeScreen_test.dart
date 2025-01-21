import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:alarm_it/Screens/Home.dart';
import 'package:alarm_it/Services/AlarmFirestore.dart';
import 'package:alarm_it/Services/AlarmListBloc.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:alarm_it/main.dart';
import 'package:alarm_it/widgets/AlarmTile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAlarmService extends Mock implements AlarmService{}
class MockAlarmFirestoreService extends Mock implements AlarmFirestoreService{}

void main() {

  final MockAlarmService mockAlarmService = MockAlarmService();
  final MockAlarmFirestoreService mockAlarmFirestoreService = MockAlarmFirestoreService();

  final AlarmCustom? mockAlarm1 = AlarmCustom(
    id: 1,
    enabled: true,
    hour: 8,
    minute: 0,
    alarmMusicPath: 'assets/alarm.mp3',
    loopAudio: true,
    vibrate: true,
    title: 'New Alarm',
    body: 'For new Reminders',
    ringingDays: [false, false, false, false, false, false, false, false],
    repeatNo: 0,
    delay: 0,
    volume: null,
  );

  final AlarmCustom? mockAlarm2 = AlarmCustom(
    id: 1,
    enabled: true,
    hour: 9,
    minute: 0,
    alarmMusicPath: 'assets/alarm.mp3',
    loopAudio: true,
    vibrate: true,
    title: 'New Alarm',
    body: 'For new Reminders',
    ringingDays: [false, false, false, false, false, false, false, false],
    repeatNo: 0,
    delay: 0,
    volume: null,
  );

  final widget = MultiBlocProvider(
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
          home: Scaffold(
            body:HomeScreen(),
          )
      ));


  testWidgets('HomeScreen shows alarm tiles when alarms are loaded',
          (WidgetTester tester) async {

        when(() => mockAlarmFirestoreService.getAlarms()).thenAnswer((_) => Future.value([
          mockAlarm1,
          mockAlarm2,
        ]));

        await tester.pumpWidget(widget);

        await tester.pumpAndSettle();

        expectLater(find.byType(AlarmTile), findsAny); // Assuming AlarmTile renders alarms
        expectLater(find.text('8:00 AM'), findsOneWidget);
        expectLater(find.text('9:00 AM'), findsOneWidget);

        await expectLater(
          find.byType(HomeScreen),
          matchesGoldenFile('goldens/Home_page.png'),
        );

      });
}
// AlarmEditScreenTest.dart

import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:alarm_it/Screens/AlarmEdit.dart';
import 'package:alarm_it/Services/AlarmEditBloc.dart';
import 'package:alarm_it/Services/AlarmListBloc.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:alarm_it/localVariables/AlarmMusic.dart';
import 'package:alarm_it/widgets/WeekdaysPicker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAlarmService extends Mock implements AlarmService {}


void main() {
  group('AlarmEditScreen', () {
    final MockAlarmService mockAlarmService = MockAlarmService();

    final AlarmCustom mockAlarm = AlarmCustom(
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

    when(() => mockAlarmService.getAlarmById(1)).thenReturn(mockAlarm);

    final widget = MultiBlocProvider(
        providers: [
          BlocProvider<AlarmEditBloc>(
              create:(BuildContext context) => AlarmEditBloc(alarmService: mockAlarmService)
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
            body:AlarmEditScreen(),
          )
        ));


    testWidgets('renders initial state', (WidgetTester tester) async {

      await tester.pumpWidget(
        widget
      );

      expect(find.text('Loading'), findsOneWidget);
    });

    testWidgets('shows initial alarm data (new alarm)', (WidgetTester tester) async {

      await tester.pumpWidget(
        widget
      );

      await tester.pumpAndSettle();

      expectLater(find.text('New Alarm'), findsOneWidget);
      expectLater(find.text('08:00 AM'), findsOneWidget);
    });

    testWidgets('shows initial alarm data (existing alarm)', (WidgetTester tester) async {

      await tester.pumpWidget(
        widget
      );

      await tester.pumpAndSettle();

      expect(find.text('New Alarm'), findsOneWidget);
      expect(find.text('08:00 AM'), findsOneWidget);
      expect(find.widgetWithText(Switch, 'Enabled'), findsOneWidget);
      expect(find.widgetWithText(Switch, 'Loop alarm audio'), findsOneWidget);
      expect(find.widgetWithText(Switch, 'Vibrate'), findsOneWidget);
      expect(find.text('Repeat Alarm'), findsOneWidget);
      expect(find.text('Delay (Minutes)'), findsOneWidget);
      });

    testWidgets('updates title on text input', (WidgetTester tester) async {


      await tester.pumpWidget(
        widget
      );


      await tester.pumpAndSettle();

      final titleField = find.byType(TextFormField);
      await tester.enterText(titleField, 'Updated Title');
      await tester.pump();

      expect(find.text('Updated Title'), findsOneWidget);

    });

    // ... other tests for updating time, ringing days, etc. (refer to the previous response)

    testWidgets('saves alarm on save button tap', (WidgetTester tester) async {
      when(() => mockAlarmService.addAlarm(mockAlarm)).thenAnswer((_) => Future.value());

      await tester.pumpWidget(
        widget
      );


      await tester.pumpAndSettle();

      final saveButton = find.byIcon(Icons.check);
      await tester.tap(saveButton);
      await tester.pump();
      //
     // verify(() => mockAlarmEditBloc.add(saveAlarm())).called(1);

      // verify(() => mockAlarmService.addAlarm(alarm).called(1);

    });

    // Add more tests for error handling, edge cases, etc.
  });
}
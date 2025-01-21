import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm_it/Services/AlarmEditBloc.dart';
import 'package:alarm_it/Services/AlarmFirestore.dart';
import 'package:alarm_it/Services/AlarmListBloc.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:alarm_it/Services/AuthService.dart';
import 'package:alarm_it/Services/LoginBloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'Screens/AlarmRinging.dart';
import 'Screens/Home.dart';
import 'Screens/Login.dart';
import 'Services/AlarmPermissions.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Alarm.init();

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final AlarmService alarmService = AlarmService();
  final AuthService authService = AuthService();
  final AlarmFirestoreService alarmFirestoreService = AlarmFirestoreService();

  runApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<LoginBloc>(
            create: (BuildContext context) => LoginBloc(authService: authService),
          ),
          BlocProvider<AlarmListBloc>(
            create: (BuildContext context) => AlarmListBloc(alarmService: alarmService, alarmFirestoreService: alarmFirestoreService),
          ),
          BlocProvider<AlarmEditBloc>(
            create: (BuildContext context) => AlarmEditBloc(alarmService: alarmService),
          ),
        ],
          child: MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                scaffoldBackgroundColor: Colors.black,
                // Define the default brightness and colors.
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blue,
                  brightness: Brightness.dark,),),
            home: AlarmIt(),
      ),
    ),
  );
}

class AlarmIt extends StatelessWidget{

  StreamSubscription<AlarmSettings>? ringSubscription;

  @override
  Widget build(BuildContext context) {

    Future<void> navigateToRingScreen(AlarmSettings alarmSettings) async {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) =>
              AlarmRingScreen(alarmSettings: alarmSettings),
        ),
      );
    }

    AlarmPermissions.checkNotificationPermission();
    if (Alarm.android) {
      AlarmPermissions.checkAndroidScheduleExactAlarmPermission();
    }
    ringSubscription ??= Alarm.ringStream.stream.asBroadcastStream().listen(navigateToRingScreen);

    return LoginScreen();

  }

}
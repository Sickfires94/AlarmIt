import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm_it/Services/AlarmEditBloc.dart';
import 'package:alarm_it/Services/AlarmListBloc.dart';
import 'package:alarm_it/Services/LoginBloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'Screens/Home.dart';
import 'Screens/Login.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Alarm.init();

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<LoginBloc>(
            create: (BuildContext context) => LoginBloc(),
          ),
          BlocProvider<AlarmListBloc>(
            create: (BuildContext context) => AlarmListBloc(),
          ),
          BlocProvider<AlarmEditBloc>(
            create: (BuildContext context) => AlarmEditBloc(),
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
  @override
  Widget build(BuildContext context) {
    return LoginScreen();
  }

}
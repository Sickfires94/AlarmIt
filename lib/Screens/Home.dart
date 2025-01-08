import 'dart:async';


import 'package:alarm_it/Services/AlarmFirestore.dart';
import 'package:alarm_it/Services/AlarmListBloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:alarm_it/widgets/LoginButton.dart';
import 'package:flutter/material.dart';

import '../Services/AlarmPermissions.dart';
import '../Services/AuthService.dart';
import '../widgets/AlarmTile.dart';
import 'AlarmEdit.dart';
import 'AlarmHomeShortcutButton.dart';
import 'AlarmRinging.dart';
import 'AlarmsList.dart';
import 'Login.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.authService});

  final AuthService authService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AlarmSettings> alarms = [];

  static StreamSubscription<AlarmSettings>? ringSubscription;
  static StreamSubscription<int>? updateSubscription;
  late AlarmService alarmService;
  AlarmFirestoreService alarmFirestoreService = new AlarmFirestoreService();

  @override
  void initState() {
    super.initState();
    AlarmPermissions.checkNotificationPermission();
    if (Alarm.android) {
      AlarmPermissions.checkAndroidScheduleExactAlarmPermission();
    }
    unawaited(loadAlarms());
    ringSubscription ??= Alarm.ringStream.stream.listen(navigateToRingScreen);
    updateSubscription ??= Alarm.updateStream.stream.listen((_) {
      unawaited(loadAlarms());
    });
  }

  Future<void> loadAlarms() async {
    final updatedAlarms = await Alarm.getAlarms();
    updatedAlarms.sort((a, b) => a.dateTime.isBefore(b.dateTime) ? 0 : 1);
    setState(() {
      alarms = updatedAlarms;
    });
  }

  Future<void> navigateToRingScreen(AlarmSettings alarmSettings) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            AlarmRingScreen(alarmSettings: alarmSettings, alarmService: alarmService,),
      ),
    );
    unawaited(loadAlarms());
  }


  @override
  void dispose() {
    ringSubscription?.cancel();
    updateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Reached");
       return BlocBuilder<AlarmListBloc, AlarmState>(builder: (context, state) {
         if(state is AlarmsLoaded) {
           print("Alarms Loaded");
          alarmService = new AlarmService(
              alarms: state.alarms, alarmFirestoreService: alarmFirestoreService);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Alarm IT'),
              actions: [LoginButtonWidget(authService: widget.authService)],
            ),
            body: AlarmsList(alarms: state.alarms, alarmService: alarmService,),
            floatingActionButton:
                 //  AlarmHomeShortcutButton(refreshAlarms: loadAlarms),
                  FloatingActionButton(
                    onPressed: () => navigateToAlarmScreen(-1).then((value) => setState(() {})),
                    child: const Icon(Icons.alarm_add_rounded, size: 33),
                  ),
            );
        }

        if (state is AlarmsInitial) context.read<AlarmListBloc>().add(fetchAlarms());
         // if (state is AlarmsLoading) context.read<AlarmListBloc>().add(fetchAlarms());

        return Scaffold(
          appBar: AppBar(
            title: const Text('ALARM IT'),
            actions: [LoginButtonWidget(authService: widget.authService)],
          ),
          body: Center(child: CircularProgressIndicator(),),
        );
      });
    }

  // void navigateToLoginScreen() async {
  //   Navigator.of(context).push(
  //     MaterialPageRoute(builder: (context) => LoginScreen(authService: authService)),
  //   ).then((_) => setState(() {}));
  // }

  Future<void> navigateToAlarmScreen(int AlarmID) async {
    final res = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      builder: (context) {
        return AlarmEditScreen(AlarmID, alarmService: alarmService);
      },
    );
  }
}

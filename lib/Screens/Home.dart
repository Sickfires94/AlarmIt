import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:alarm_it/widgets/LoginButton.dart';
import 'package:flutter/material.dart';

import '../Services/AlarmPermissions.dart';
import '../Services/AuthService.dart';
import '../widgets/AlarmTile.dart';
import 'AlarmEdit.dart';
import 'AlarmHomeShortcutButton.dart';
import 'AlarmRinging.dart';
import 'Login.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AlarmSettings> alarms = [];

  static StreamSubscription<AlarmSettings>? ringSubscription;
  static StreamSubscription<int>? updateSubscription;
  AuthService authService = new AuthService();

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
            AlarmRingScreen(alarmSettings: alarmSettings),
      ),
    );
    unawaited(loadAlarms());
  }

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
        return AlarmEditScreen(AlarmID);
      },
    );

    if (res != null && res == true) unawaited(loadAlarms());
  }

  @override
  void dispose() {
    ringSubscription?.cancel();
    updateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ALARM IT'),
        actions: [
          LoginButtonWidget(authService: authService)
        ],
      ),
      body: SafeArea(
        child: alarms.isNotEmpty
            ? ListView.separated(
          itemCount: alarms.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return AlarmTile(
              key: Key(alarms[index].id.toString()),
              title: TimeOfDay(
                hour: alarms[index].dateTime.hour,
                minute: alarms[index].dateTime.minute,
              ).format(context),
              onPressed: () => navigateToAlarmScreen(alarms[index].id),
              onDismissed: () {
                Alarm.stop(alarms[index].id).then((_) => loadAlarms());
              },
            );
          },
        )
            : Center(
          child: Text(
            'No alarms set',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AlarmHomeShortcutButton(refreshAlarms: loadAlarms),
            FloatingActionButton(
              onPressed: () => navigateToAlarmScreen(-1),
              child: const Icon(Icons.alarm_add_rounded, size: 33),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }


}
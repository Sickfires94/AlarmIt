import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:flutter/material.dart';

class AlarmRingScreen extends StatefulWidget {
  const AlarmRingScreen({required this.alarmSettings, super.key});

  final AlarmSettings alarmSettings;

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final isRinging = await Alarm.isRinging(widget.alarmSettings.id);
      if (isRinging) {
        alarmPrint('Alarm ${widget.alarmSettings.notificationSettings.title} is still ringing...');
        return;
      }

      // Add repeat logic here

      alarmPrint('Alarm ${widget.alarmSettings.notificationSettings.title} stopped ringing.');
      timer.cancel();
      if (mounted) Navigator.pop(context);
    });
  }
  
  void stopAlarm(){
    // Get current weekday and figure out the next day to recall alarm
    AlarmService.handleAlarmStop(widget.alarmSettings.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              'Your alarm "${widget.alarmSettings.notificationSettings.title}" is ringing...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text('🔔', style: TextStyle(fontSize: 50)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                RawMaterialButton(
                  onPressed: () async => Alarm.set(
                    alarmSettings: widget.alarmSettings.copyWith(
                      dateTime: DateTime.now().add(const Duration(minutes: 1)),
                    ),
                  ),
                  child: Text(
                    'Snooze',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                RawMaterialButton(
                  onPressed: stopAlarm,
                  child: Text(
                    'Stop',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
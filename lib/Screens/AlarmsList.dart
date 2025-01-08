import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../widgets/AlarmTile.dart';
import 'AlarmEdit.dart';

class AlarmsList extends StatefulWidget{
  final List<AlarmCustom> alarms;
  final AlarmService alarmService;
  AlarmsList({required this.alarms, required this.alarmService});

  State<AlarmsList> createState() => _AlarmsListState();
  }

  class _AlarmsListState extends State<AlarmsList>{


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: widget.alarms.isNotEmpty
          ? ListView.separated(
        itemCount: widget.alarms.length,
        separatorBuilder: (context, index) =>
        const Divider(height: 1),
        itemBuilder: (context, index) {
          return AlarmTile(
            key: Key(widget.alarms[index].id.toString()),
            title: TimeOfDay(
              hour: widget.alarms[index].hour,
              minute: widget.alarms[index].minute,
            ).format(context),
            onPressed: () =>
                navigateToAlarmScreen(widget.alarms[index].id),
            onDismissed: () {
              widget.alarmService.deleteAlarm(widget.alarms[index].id);
              setState(() {

                widget.alarms.removeWhere((alarm) => alarm.id == widget.alarms[index].id);
              });
            }
              // Alarm.stop(widget.alarms[index].id)
              //     .then((_) => loadAlarms());
          );
        },
      )
          : Center(
        child: Text(
          'No alarms set',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  Future<void> navigateToAlarmScreen(int AlarmID) async {
    final res = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      // enableDrag: true,
      // showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      builder: (context) {
        return AlarmEditScreen(AlarmID, alarmService: widget.alarmService,);
      },
    );
  }

}
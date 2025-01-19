import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../Services/AlarmEditBloc.dart';
import '../Services/AlarmListBloc.dart';
import '../widgets/AlarmTile.dart';
import 'AlarmEdit.dart';

class AlarmsList extends StatelessWidget{


  @override
  Widget build(BuildContext context) {

    Future<void> navigateToAlarmScreen(int AlarmId) async {
      context.watch<AlarmEditBloc>()..add(getAlarm(AlarmId: AlarmId));
      final res = await showModalBottomSheet<bool?>(
        context: context,
        isScrollControlled: true,
        // enableDrag: true,
        // showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        builder: (context) => AlarmEditScreen(),
      );
    }
    if (context.read<AlarmListBloc>().state is AlarmsLoaded) {
      AlarmsLoaded state = context.read<AlarmListBloc>().state as AlarmsLoaded;
      return SafeArea(
        child: state.alarms.isNotEmpty
            ? ListView.separated(
          itemCount: state.alarms.length,
          separatorBuilder: (context, index) =>
          const Divider(height: 1),
          itemBuilder: (context, index) {
            return AlarmTile(
                key: Key(state.alarms[index].id.toString()),
                title: TimeOfDay(
                  hour: state.alarms[index].hour,
                  minute: state.alarms[index].minute,
                ).format(context),
                onPressed: () =>
                    navigateToAlarmScreen(state.alarms[index].id),
                onDismissed: () {
                  context.read<AlarmListBloc>().add(deleteAlarmList(alarmId: state.alarms[index].id));
                }
              // Alarm.stop(state.alarms[index].id)
              //     .then((_) => loadAlarms());
            );
          },
        )
            : Center(
          child: Text(
            'No alarms set',
            style: Theme
                .of(context)
                .textTheme
                .titleMedium,
          ),
        ),
      );
    }
    return Text("Loading");
  }



}
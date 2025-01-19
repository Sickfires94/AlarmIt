import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:alarm/alarm.dart';
import 'package:alarm_it/Services/AlarmFirestore.dart';
import 'package:alarm_it/Services/AlarmListBloc.dart';
import 'package:alarm_it/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AlarmService {
  late List<AlarmCustom> alarms;
  AlarmFirestoreService alarmFirestoreService = AlarmFirestoreService();

  AlarmService() {
    syncAlarms();
  }

  void syncAlarms() async {
    alarms = (await alarmFirestoreService.getAlarms()) as List<AlarmCustom>;
  }

  /// implement a function to set the next alarm according to the ALarmCustom provided
  void addAlarm(AlarmCustom alarm){
    bool exists = false;

    // print("Editing alarm? " + alarms.contains(alarm).toString());
    //

    for (int i = 0; i < alarms.length; i++){
      if(alarms[i].id == alarm.id){
        alarms[i] = alarm;
        stopAlarm(alarm.id);
        exists = true;
        break;
      }
    }
    if(!exists)
      alarms.add(alarm);

    if (exists)
      alarmFirestoreService.editAlarm(alarm);
    else
      alarmFirestoreService.saveAlarm(alarm);

    if(alarm.enabled)
      setNextAlarm(alarm);
  }

  void toggleAlarmEnable(int AlarmId){
    AlarmCustom alarm = getAlarmById(AlarmId);

    if(alarm.enabled){
      stopAlarm(AlarmId);
      alarm.enabled = false;
      return;
    }

    alarm.enabled = true;
    setNextAlarm(alarm);

  }

  void loadAlarms(){

  }

  AlarmCustom getAlarmById(int AlarmID){
    for(final alarm in alarms){
      if(alarm.id == AlarmID) return alarm;
    }
    throw Exception("Alarm not found");
  }

  List<AlarmCustom> getAlarmsList(){
    return alarms;
  }

  void setNextAlarm(AlarmCustom alarm){
    AlarmSettings newAlarm = AlarmSettings(
      id: alarm.id,
      dateTime: getNextDateTime(hour: alarm.hour, minute: alarm.minute, ringingDays: alarm.ringingDays),
      assetAudioPath: alarm.alarmMusicPath,
      notificationSettings: NotificationSettings(title: alarm.title, body: alarm.body),
      loopAudio:alarm.loopAudio,
      volume:alarm.volume,
      vibrate: alarm.vibrate,
    );
    Alarm.set(alarmSettings: newAlarm);
  }

  void setNextAlarmWithTime(AlarmCustom alarm, DateTime time){
    AlarmSettings newAlarm = AlarmSettings(
      id: alarm.id,
      dateTime: time,
      assetAudioPath: alarm.alarmMusicPath,
      notificationSettings: NotificationSettings(title: alarm.title, body: alarm.body),
      loopAudio:alarm.loopAudio,
      volume:alarm.volume,
      vibrate: alarm.vibrate,
    );
    Alarm.set(alarmSettings: newAlarm);
  }

  DateTime getNextDateTime({required int hour, required int minute, required List<bool> ringingDays}){
    DateTime NextDateTime = DateTime.now().copyWith(hour: hour, minute: minute, second: 0, millisecond: 0);
    if(NextDateTime.isBefore(DateTime.now())) NextDateTime = NextDateTime.add(Duration(days: 1));
    print("Ringing days" + ringingDays.toString());
    print("Contains atleast 1 true: " + ringingDays.contains(true).toString());
    if(!ringingDays.contains(true)) return NextDateTime;

    while(!ringingDays[NextDateTime.weekday]) {
      NextDateTime = NextDateTime.add(Duration(days: 1));
      print(NextDateTime.toString() + " : " + NextDateTime.weekday.toString());
    }

    print("New Time: " + NextDateTime.toString());
    return NextDateTime;
  }


  DateTime getAlarmSetTime(int AlarmId){
    AlarmCustom alarm = getAlarmById(AlarmId);
    return getNextDateTime(hour: alarm.hour, minute: alarm.minute, ringingDays: alarm.ringingDays, );
  }


  /// implement a function to get the alarm id and stop it (delete alarm)
  void stopAlarm(int AlarmId){
    Alarm.stop(AlarmId);
  }


  void deleteAlarm(int AlarmId){
    stopAlarm(AlarmId);
    alarmFirestoreService.deleteAlarm(AlarmId);
    for(int i = 0; i < alarms.length; i++){
      if(alarms[i].id == AlarmId) {
        alarms.removeAt(i);
        return;
      }
    }
  }

  /// implement a function to call once an alarm is stopped so its next alarm is set up
  void handleAlarmStop(int AlarmId){
    stopAlarm(AlarmId);
    AlarmCustom alarm = getAlarmById(AlarmId);


    // Handle Grouped Alarm
    if(handleGroupedAlarm(alarm)) return;

    print("Contains atleast 1 true: " + alarm.ringingDays.contains(true).toString());
    if(!alarm.ringingDays.contains(true)) {
      alarm.enabled = false;
      addAlarm(alarm);
      return;
    }
    setNextAlarm(alarm);
  }

  bool handleGroupedAlarm(AlarmCustom alarm){

    if(alarm.delay == 0) return false;

    DateTime NextDateTime = DateTime.now().copyWith(hour: alarm.hour, minute: alarm.minute, second: 0, millisecond: 0);
    for(int i = 0; i < alarm.repeatNo; i++){
      NextDateTime = NextDateTime.add(Duration(minutes: alarm.delay));
      if(NextDateTime.isAfter(DateTime.now())){
        setNextAlarmWithTime(alarm, NextDateTime);
        return true;
      }
    }
    return false;
  }
}

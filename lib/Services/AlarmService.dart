import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:alarm/alarm.dart';

class AlarmService {

  static List<AlarmCustom> alarms = [];


  /// implement a function to set the next alarm according to the ALarmCustom provided
  static void addAlarm(AlarmCustom alarm){



    alarms.add(alarm);
    if(alarm.enabled)
      setNextAlarm(alarm);
  }

  static AlarmCustom getAlarmById(int AlarmID){
    for(final alarm in alarms){
      if(alarm.id == AlarmID) return alarm;
    }
    throw Exception("Alarm not found");
  }

  static List<AlarmCustom> getAlarmsList(){
    return alarms;
  }

  static void setNextAlarm(AlarmCustom alarm){
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

  static void setNextAlarmWithTime(AlarmCustom alarm, DateTime time){
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

  static DateTime getNextDateTime({required int hour, required int minute, required List<bool> ringingDays}){
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


  static DateTime getAlarmSetTime(int AlarmId){
    AlarmCustom alarm = getAlarmById(AlarmId);
    return getNextDateTime(hour: alarm.hour, minute: alarm.minute, ringingDays: alarm.ringingDays, );
  }


/// implement a function to get the alarm id and stop it (delete alarm)
  static void stopAlarm(int AlarmId){
    Alarm.stop(AlarmId);
  }


  static void deleteAlarm(int AlarmId){
    stopAlarm(AlarmId);
    for(int i = 0; i < alarms.length; i++){
      if(alarms[i].id == AlarmId) {
        alarms.removeAt(i);
        return;
      }
    }
  }

/// implement a function to call once an alarm is stopped so its next alarm is set up
  static void handleAlarmStop(int AlarmId){
    stopAlarm(AlarmId);
    AlarmCustom alarm = getAlarmById(AlarmId);


    // Handle Grouped Alarm
    if(handleGroupedAlarm(alarm)) return;

    print("Contains atleast 1 true: " + alarm.ringingDays.contains(true).toString());
    if(!alarm.ringingDays.contains(true)) return;
    setNextAlarm(alarm);
  }

  static bool handleGroupedAlarm(AlarmCustom alarm){

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
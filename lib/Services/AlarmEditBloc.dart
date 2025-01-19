
import 'package:alarm_it/Services/AlarmListBloc.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:alarm_it/Models/AlarmSettings.dart';


abstract class AlarmEditEvent{}
class saveAlarm extends AlarmEditEvent{}
class deleteAlarm extends AlarmEditEvent{}
class getAlarm extends AlarmEditEvent{
  int AlarmId;
  getAlarm({required this.AlarmId});
}
class exitAlarmPage extends AlarmEditEvent{}

abstract class AlarmEditState{
}
class EditAlarmInitial extends AlarmEditState{}
class LoadingAlarm extends AlarmEditState{}
class AlarmLoaded extends AlarmEditState{
  AlarmCustom alarm;
  AlarmLoaded({required this.alarm});
}
class AlarmSaved extends AlarmEditState{}
class AlarmExited extends AlarmEditState{}

class AlarmEditBloc extends Bloc<AlarmEditEvent, AlarmEditState>{
  AlarmService alarmService = new AlarmService();

  AlarmEditBloc() : super(EditAlarmInitial()){
    on<getAlarm>((event, emit,) => _getAlarm(AlarmId: event.AlarmId));
    on<saveAlarm>((event, emit,) => _saveAlarm());
    on<deleteAlarm>((event, emit,) => _deleteAlarm());
    on<exitAlarmPage>((event, emit,) => _exitPage());

  }

  _getAlarm({required int AlarmId}){
    emit(LoadingAlarm());
    AlarmCustom alarm;
    if(AlarmId == -1) alarm = _getDefaultAlarm();
    else alarm = alarmService.getAlarmById(AlarmId);
    emit(AlarmLoaded(alarm: alarm));
  }

  AlarmCustom _getDefaultAlarm(){
    final alarmCustom = AlarmCustom(
      id: DateTime.now().millisecondsSinceEpoch % 10000 + 1,
      enabled: true,
      hour: DateTime.now().add(const Duration(minutes: 1)).hour,
      minute: DateTime.now().add(const Duration(minutes: 1)).minute,
      loopAudio: true,
      vibrate: true,
      volume: null,
      alarmMusicPath: "assets/alarm.mp3",
      title: "New Alarm",
      body: "For new Reminders",
      // notificationSettings: const NotificationSettings(
      //   title: 'This is the title',
      //   body: 'This is the body',
      //   stopButton: 'Stop the alarm',
      //   icon: 'notification_icon',
      // ),
      ringingDays: [false, false, false, false, false, false, false, false],
      repeatNo: 0,
      delay: 0,
    );
    return alarmCustom;
  }

  void _saveAlarm(){
    if (state is AlarmLoaded) {
      alarmService.addAlarm((state as AlarmLoaded).alarm);
      emit(AlarmSaved());
    }
  }

  void _deleteAlarm(){
    if (state is AlarmLoaded){
      alarmService.deleteAlarm((state as AlarmLoaded).alarm.id);
    }
  }

  _exitPage(){
    emit(AlarmExited());
  }
}

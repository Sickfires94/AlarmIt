
import 'package:alarm/alarm.dart';

class AlarmCustom{
  int id;
  // DateTime selectedDateTime;
  bool enabled;
  int hour;
  int minute;
  String alarmMusicPath;
  double? volume;
  bool loopAudio;
  bool vibrate;
  String title;
  String body;
  List<bool> ringingDays;
  int repeatNo;
  int delay;

  // AlarmCustom({required super.id, required super.dateTime, required super.assetAudioPath, required super.notificationSettings});


  AlarmCustom({
    required this.id,
    // required this.selectedDateTime,
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.alarmMusicPath,
    required this.loopAudio,
    required this.volume,
    required this.vibrate,
    required this.title,
    required this.body,
    required this.ringingDays,
    required this.repeatNo,
    required this.delay,
});


}
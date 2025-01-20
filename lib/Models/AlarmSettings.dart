
import 'package:alarm/alarm.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  AlarmCustom copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    String? alarmMusicPath,
    bool? loopAudio,
    double? volume,
    bool? vibrate,
    String? title,
    String? body,
    List<bool>? ringingDays,
    int? repeatNo,
    int? delay
  }){
    return AlarmCustom(
      id: this.id,
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      alarmMusicPath: alarmMusicPath ?? this.alarmMusicPath,
      loopAudio: loopAudio ?? this.loopAudio,
      volume: volume ?? this.volume,
      vibrate: vibrate ?? this.vibrate,
      title: title ?? this.title,
      body: body ?? this.body,
      ringingDays: ringingDays ?? this.ringingDays,
      repeatNo: repeatNo ?? this.repeatNo,
      delay: delay ?? this.delay
    );
  }

  factory AlarmCustom.fromJson(Map<String, dynamic> json) => AlarmCustom(
    id: json['id'],
    enabled: json['enabled'],
    hour: json['hour'],
    minute: json['minute'],
    alarmMusicPath: json['alarmMusicPath'],
    loopAudio: json['loopAudio'],
    volume: json['volume'] as double?,
    vibrate: json['vibrate'],
    title: json['title'],
    body: json['body'],
    ringingDays: List<bool>.from(json['ringingDays']),
    repeatNo: json['repeatNo'],
    delay: json['delay'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'alarmMusicPath': alarmMusicPath,
    'loopAudio': loopAudio,
    'volume': volume,
    'vibrate': vibrate,
    'title': title,
    'body': body,
    'ringingDays': ringingDays,
    'repeatNo': repeatNo,
    'delay': delay,
  };


}
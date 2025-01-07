import 'dart:io';


import 'package:numberpicker/numberpicker.dart';
import 'package:alarm/alarm.dart';
import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:alarm_it/localVariables/AlarmMusic.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../widgets/WeekdaysPicker.dart';

class AlarmEditScreen extends StatefulWidget {
  AlarmEditScreen(int AlarmID, {super.key}){
    if (AlarmID != -1)
      alarmCustom = AlarmService.getAlarmById(AlarmID);
    else
      alarmCustom = null;
  }



  AlarmCustom? alarmCustom;

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  bool loading = false;
  late bool creating;

  late int id;
  late bool enabled;
  late DateTime selectedDateTime;
  late bool vibrate;
  late double? volume;
  late String alarmMusicPath;
  late bool loopAudio;
  late String title;
  late String body;
  late List<bool> ringingDays;
  late int repeatNo;
  late int repeatIteration;
  late int delay;



  final _formKey = GlobalKey<FormState>();
  TextEditingController repeatController = TextEditingController();


  @override
  void initState() {
    super.initState();
    creating = widget.alarmCustom == null;

    if (creating) {
      id = DateTime.now().millisecondsSinceEpoch % 10000 + 1;
      selectedDateTime = DateTime.now().add(const Duration(minutes: 1));
      selectedDateTime = selectedDateTime.copyWith(second: 0, millisecond: 0);
      // hour = selectedDateTime.hour;
      // minute = selectedDateTime.minute;
      enabled = true;
      loopAudio = true;
      vibrate = true;
      volume = null;
      alarmMusicPath = 'assets/alarm.mp3';
      title = "New Alarm";
      body = "For new Reminders";
      ringingDays = [false, false, false, false, false, false, false, false];
      repeatNo = 0;
      repeatIteration = 0;
      delay = 0;
    } else {
      print("Reached Here");
      // selectedDateTime = DateTime(hour = widget.alarmCustom!.hour, minute = widget.alarmCustom!.minute);
      id = widget.alarmCustom!.id;
      print("DateTimeRecieved: " + AlarmService.getAlarmSetTime(id).toString());
      // selectedDateTime = AlarmService.getNextDateTime(hour: widget.alarmCustom!.hour, minute : widget.alarmCustom!.minute);
      selectedDateTime = AlarmService.getAlarmSetTime(id);
      loopAudio = widget.alarmCustom!.loopAudio;
      vibrate = widget.alarmCustom!.vibrate;
      enabled = widget.alarmCustom!.enabled;
      volume = widget.alarmCustom!.volume;
      alarmMusicPath = widget.alarmCustom!.alarmMusicPath;
      title = widget.alarmCustom!.title;
      body = widget.alarmCustom!.body;
      ringingDays = widget.alarmCustom!.ringingDays;
      repeatNo = widget.alarmCustom!.repeatNo;
      delay = widget.alarmCustom!.delay;
    }
  }

  void pickLocalMusic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() {
       AlarmMusic.addMusic(filename: file.uri.pathSegments.last.substring(0, 20), path: file.path);
      });
      print(AlarmMusic.dropdownItems.last.value);
    }
  }

  void setRepeatDays(List<bool> days){
    if(days.length != 8) return;
    setState(() {
      ringingDays = days;
    });

    print(ringingDays);
  }


  String getDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = selectedDateTime.difference(today).inDays;

    switch (difference) {
      case 0:
        return 'Today';
      case 1:
        return 'Tomorrow';
      case 2:
        return 'After tomorrow';
      default:
        return 'In $difference days';
    }
  }

  Future<void> pickTime() async {
    final res = await showTimePicker(
      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
      context: context,
    );

    if (res != null) {
      setState(() {
        final now = DateTime.now();
        selectedDateTime = now.copyWith(
          hour: res.hour,
          minute: res.minute,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
        if (selectedDateTime.isBefore(now)) {
          selectedDateTime = selectedDateTime.add(const Duration(days: 1));
        }
      });
    }
  }

  AlarmCustom buildAlarmSettings() {


    final alarmCustom = AlarmCustom(
      id: id,
      enabled: enabled,
      hour: selectedDateTime.hour,
      minute: selectedDateTime.minute,
      loopAudio: loopAudio,
      vibrate: vibrate,
      volume: volume,
      alarmMusicPath: alarmMusicPath,
      title: title,
      body: body,
      // notificationSettings: const NotificationSettings(
      //   title: 'This is the title',
      //   body: 'This is the body',
      //   stopButton: 'Stop the alarm',
      //   icon: 'notification_icon',
      // ),
      ringingDays: ringingDays,
      repeatNo: repeatNo,
      delay: delay,
    );
    return alarmCustom;
  }

  void saveAlarm() {

    // TODO call buildAlarmSettings and store result in AlarmService that will set and manage Alarms
    AlarmCustom alarm = buildAlarmSettings();
    AlarmService.addAlarm(alarm);
    Navigator.pop(context, true);

    // Alarm.set(alarmSettings: buildAlarmSettings()).then((res) {
    //   if (res && mounted) Navigator.pop(context, true);
    //   setState(() => loading = false);
    // });
  }

  void deleteAlarm() {
    // TODO tell service to stop the alarm with the current id
    AlarmService.deleteAlarm(id);
    Navigator.pop(context);

    // Alarm.stop(widget.alarmCustom!.id).then((res) {
    //   if (res && mounted) Navigator.pop(context, true);
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(color: Colors.blueAccent),
                ),
              ),
              TextButton(
                onPressed: saveAlarm,
                child: loading
                    ? const CircularProgressIndicator()
                    : Text(
                  'Save',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
          Text(
            getDay(),
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(color: Colors.blueAccent.withOpacity(0.8)),
          ),
          RawMaterialButton(
            onPressed: pickTime,
            fillColor: Colors.grey[200],
            child: Container(
              margin: const EdgeInsets.all(20),
              child: Text(
                TimeOfDay.fromDateTime(selectedDateTime).format(context),
                style: Theme.of(context)
                    .textTheme
                    .displayMedium!
                    .copyWith(color: Colors.blueAccent),
              ),
            ),
          ),

          Row(
            children: [WeekdaysPicker(initialSelectedDays: ringingDays, onSelectionChanged: setRepeatDays,)],
          ),
          Column(
            children: [
              Text("Repeat Alarm"),
              NumberPicker(
                value: repeatNo,
                minValue: 0,
                maxValue: 5,
                axis: Axis.horizontal,
                onChanged: (value) => setState(() => repeatNo = value),
              ),
              Text("Delay (Minutes)"),
              NumberPicker(
                value: delay,
                minValue: 0,
                maxValue: 60,
                step: 1,
                axis: Axis.horizontal,
                onChanged: (value) => setState(() {
                  delay = value;
                }),
              )
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Loop alarm audio',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Switch(
                value: loopAudio,
                onChanged: (value) => setState(() => loopAudio = value),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vibrate',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Switch(
                value: vibrate,
                onChanged: (value) => setState(() => vibrate = value),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children:[
                Text(
                'Sound',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(width: 10,),
              ElevatedButton(onPressed: pickLocalMusic, child: Icon(Icons.search))]),
              DropdownButton(
                value: alarmMusicPath,
                items: AlarmMusic.dropdownItems,
                onChanged: (value) => setState(() => alarmMusicPath = value!),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Custom volume',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Switch(
                value: volume != null,
                onChanged: (value) =>
                    setState(() => volume = value ? 0.5 : null),
              ),
            ],
          ),
          SizedBox(
            height: 30,
            child: volume != null
                ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  volume! > 0.7
                      ? Icons.volume_up_rounded
                      : volume! > 0.1
                      ? Icons.volume_down_rounded
                      : Icons.volume_mute_rounded,
                ),
                Expanded(
                  child: Slider(
                    value: volume!,
                    onChanged: (value) {
                      setState(() => volume = value);
                    },
                  ),
                ),
              ],
            )
                : const SizedBox(),
          ),
          if (!creating)
            TextButton(
              onPressed: deleteAlarm,
              child: Text(
                'Delete Alarm',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(color: Colors.red),
              ),
            ),
          const SizedBox(),
        ],
      ),
    );
  }
}
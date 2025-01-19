import 'dart:io';


import 'package:alarm_it/Services/AlarmListBloc.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:alarm_it/Models/AlarmSettings.dart';
import 'package:alarm_it/Services/AlarmService.dart';
import 'package:alarm_it/localVariables/AlarmMusic.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../Services/AlarmEditBloc.dart';
import '../widgets/WeekdaysPicker.dart';

class AlarmEditScreen extends StatelessWidget {

  // AlarmEditScreen(int AlarmID){
  //   if (AlarmID != -1)
  //     alarmCustom = context.read<AlarmListBloc>().;
  //   else
  //     alarmCustom = null;
  // }




  // final _formKey = GlobalKey<FormState>();
  // TextEditingController repeatController = TextEditingController();
  // final titleController = TextEditingController();
  // final bodyController = TextEditingController();


  // void init() {
  //
  //   if (creating) {
  //     id = DateTime.now().millisecondsSinceEpoch % 10000 + 1;
  //     selectedDateTime = DateTime.now().add(const Duration(minutes: 1));
  //     selectedDateTime = selectedDateTime.copyWith(second: 0, millisecond: 0);
  //     // hour = selectedDateTime.hour;
  //     // minute = selectedDateTime.minute;
  //     enabled = true;
  //     loopAudio = true;
  //     vibrate = true;
  //     volume = null;
  //     alarmMusicPath = 'assets/alarm.mp3';
  //     titleController.text = "New Alarm";
  //     bodyController.text = "For new Reminders";
  //     ringingDays = [false, false, false, false, false, false, false, false];
  //     repeatNo = 0;
  //     delay = 0;
  //   } else {
  //     print("Reached Here");
  //     // selectedDateTime = DateTime(hour = widget.alarmCustom!.hour, minute = widget.alarmCustom!.minute);
  //     id = widget.alarmCustom!.id;
  //     print("DateTimeRecieved: " + widget.alarmService.getAlarmSetTime(id).toString());
  //     // selectedDateTime = AlarmService.getNextDateTime(hour: widget.alarmCustom!.hour, minute : widget.alarmCustom!.minute);
  //     selectedDateTime = widget.alarmService.getAlarmSetTime(id);
  //     loopAudio = widget.alarmCustom!.loopAudio;
  //     vibrate = widget.alarmCustom!.vibrate;
  //     enabled = widget.alarmCustom!.enabled;
  //     volume = widget.alarmCustom!.volume;
  //     alarmMusicPath = widget.alarmCustom!.alarmMusicPath;
  //     titleController.text = widget.alarmCustom!.title;
  //     bodyController.text = widget.alarmCustom!.body;
  //     ringingDays = widget.alarmCustom!.ringingDays;
  //     repeatNo = widget.alarmCustom!.repeatNo;
  //     delay = widget.alarmCustom!.delay;
  //   }
  // }

  void pickLocalMusic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      AlarmMusic.addMusic(filename: file.uri.pathSegments.last.substring(0, 20), path: file.path);
      print(AlarmMusic.dropdownItems.last.value);
    }
  }





  // void deleteAlarm() {
  //   // TODO tell service to stop the alarm with the current id
  //   widget.alarmService.deleteAlarm(id);
  //   Navigator.pop(context);
  // }

  @override
  Widget build(BuildContext context) {

    void setRepeatDays(List<bool> days){
      print("days: " + days.toString());
      if(days.length != 8) return;
      if(context.read<AlarmEditBloc>().state is AlarmLoaded)
        (context.read<AlarmEditBloc>().state as AlarmLoaded).alarm.ringingDays = days;

    }

    Future<void> pickTime() async {

      AlarmLoaded state = context.read<AlarmEditBloc>().state as AlarmLoaded;

      final res = await showTimePicker(
        initialTime: TimeOfDay.fromDateTime(DateTime.now().copyWith(hour: state.alarm.hour, minute: state.alarm.minute)),
        context: context,
      );

      if (res != null && context.read<AlarmEditBloc>().state is AlarmLoaded) {
          state.alarm.hour = res.hour;
          state.alarm.minute = res.minute;
      }
    }

    var readState = context.read<AlarmEditBloc>().state;

    return BlocBuilder<AlarmEditBloc, AlarmEditState>(
        builder: (context, state) {
          if (state is AlarmLoaded) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: Icon(
                            Icons.close_sharp, size: 40, color: Colors.red,)
                      ),
                      SizedBox(
                          width: 200,
                          child: TextFormField(
                            style: TextStyle(fontSize: 25),
                            textAlign: TextAlign.end,
                            initialValue: state.alarm.title,
                            onSaved: (value) {
                              state.alarm.title = value ?? "New Alarm";
                              },
                            decoration: InputDecoration(
                              suffixIcon: Icon(Icons.edit, size: 20,),
                              border: InputBorder.none,
                            ),)
                      ),
                      IconButton(
                          onPressed: () {
                            context.read<AlarmEditBloc>().add(saveAlarm());
                          },
                          icon: Icon(
                            Icons.check, size: 40, color: Colors.green,)
                      ),
                    ],
                  ),

                  SizedBox(height: 20,),
                  RawMaterialButton(
                    onPressed: pickTime,
                    //fillColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          15), // Add some border radius for visual appeal
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      child: Text(
                        TimeOfDay.fromDateTime(DateTime.now().copyWith(hour: state.alarm.hour, minute: state.alarm.minute)).format(
                            context),
                        style: Theme
                            .of(context)
                            .textTheme
                            .displayMedium!
                            .copyWith(color: Colors.blueAccent),
                      ),
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      WeekdaysPicker(initialSelectedDays: state.alarm.ringingDays,
                        onSelectionChanged: setRepeatDays,)
                    ],
                  ),
                  SizedBox(height: 20,),
                  Column(
                    children: [
                      Text("Repeat Alarm", style: TextStyle(fontSize: 20),),
                      NumberPicker(
                        value: state.alarm.repeatNo,
                        minValue: 0,
                        maxValue: 5,
                        axis: Axis.horizontal,
                        onChanged: (value) => state.alarm.repeatNo = value),
                      Text("Delay (Minutes)", style: TextStyle(fontSize: 20),),
                      NumberPicker(
                        value: state.alarm.delay,
                        minValue: 0,
                        maxValue: 60,
                        step: 5,
                        axis: Axis.horizontal,
                        onChanged: (value) =>
                            state.alarm.delay = value
                      )
                    ],
                  ),


                  // TextFormField(
                  //   controller: bodyController,
                  //   decoration: const InputDecoration(
                  //     labelText: 'Body',
                  //     border: OutlineInputBorder(),
                  //   ),
                  // ),
                  // const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Enabled", style: TextStyle(fontSize: 20),),
                      Switch(
                        value: state.alarm.enabled,
                        onChanged: (value) =>
                            state.alarm.enabled = value,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Loop alarm audio', style: TextStyle(fontSize: 20),),
                      Switch(
                        value: state.alarm.loopAudio,
                        onChanged: (value) => state.alarm.loopAudio = value),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Vibrate', style: TextStyle(fontSize: 20),),
                      Switch(
                        value: state.alarm.vibrate,
                        onChanged: (value) => state.alarm.vibrate = value),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              'Sound', style: TextStyle(fontSize: 20),
                            ),
                            SizedBox(width: 10,),
                            ElevatedButton(
                                onPressed: pickLocalMusic,
                                child: Icon(Icons.search))
                          ]),
                      DropdownButton(
                        value: state.alarm.alarmMusicPath,
                        items: AlarmMusic.dropdownItems,
                        onChanged: (value) =>
                        state.alarm.alarmMusicPath = value ?? "assets/alarm.mp3",
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Custom volume', style: TextStyle(fontSize: 20),
                      ),
                      Switch(
                        value: state.alarm.volume != null,
                        onChanged: (value) =>
                            state.alarm.volume = value ? 0.5 : null),
                    ],
                  ),
                  SizedBox(
                    height: 30,
                    child: state.alarm.volume != null
                        ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          state.alarm.volume! > 0.7
                              ? Icons.volume_up_rounded
                              : state.alarm.volume! > 0.1
                              ? Icons.volume_down_rounded
                              : Icons.volume_mute_rounded,
                        ),
                        Expanded(
                          child: Slider(
                            value: state.alarm.volume ?? 0.8,
                            onChanged: (value) {
                              state.alarm.volume = value;
                            },
                          ),
                        ),
                      ],
                    )
                        : const SizedBox(),
                  ),
                  const SizedBox(),
                ],
              ),
            );
          }
          return Text("Loading");
        });
  }
}
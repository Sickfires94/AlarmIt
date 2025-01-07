import 'package:flutter/material.dart';

 class AlarmMusic {
  static List<DropdownMenuItem<String>> dropdownItems = [
    DropdownMenuItem<String>(
      value: 'assets/alarm.mp3',
      child: Text('Marimba'),
    ),
    DropdownMenuItem<String>(
      value: 'assets/nokia.mp3',
      child: Text('Nokia'),
    ),
    DropdownMenuItem<String>(
      value: 'assets/mozart.mp3',
      child: Text('Mozart'),
    ),
    DropdownMenuItem<String>(
      value: 'assets/star_wars.mp3',
      child: Text('Star Wars'),
    ),
    DropdownMenuItem<String>(
      value: 'assets/one_piece.mp3',
      child: Text('One Piece'),
    ),
  ];

  static void addMusic({filename, path}){
    for(final item in dropdownItems){
      if (item.value == path) return;
    }

    dropdownItems.add(DropdownMenuItem<String>(
      value: path,
      child: Text(filename),
    ));
  }

}
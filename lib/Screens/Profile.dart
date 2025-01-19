import 'package:alarm_it/Screens/Login.dart';
import 'package:alarm_it/Services/AuthService.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../Services/AlarmListBloc.dart';

class ProfileScreen extends StatelessWidget{

  Widget build(BuildContext context) {

    void handleLogout() async {
      // await authService.logout();
      Navigator.of(context)..pop()..pop();
    }

    return Scaffold(
      body: Center( child: ElevatedButton(
        onPressed: handleLogout,
        child: Text("Log out"),

      ))
    );
  }



}
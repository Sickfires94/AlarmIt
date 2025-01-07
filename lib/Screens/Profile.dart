import 'package:alarm_it/Services/AuthService.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget{
  final AuthService authService;

  ProfileScreen({required this.authService});

  Widget build(BuildContext context) {

    void handleLogout() async {
      await authService.logout();
      Navigator.of(context).pop();
    }


    return Scaffold(
      body: Center( child: ElevatedButton(onPressed: handleLogout, child: Text("Log out")))
    );
  }



}
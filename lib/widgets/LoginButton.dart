import 'package:alarm_it/Services/AuthService.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../Screens/Login.dart';
import '../Screens/Profile.dart';

class LoginButtonWidget extends StatefulWidget {
  final AuthService authService;

  LoginButtonWidget({super.key, required this.authService});


  State<LoginButtonWidget> createState() => _LoginButtonState();

}

class _LoginButtonState extends State<LoginButtonWidget>{
  Widget build(BuildContext context) {

    void navigateToProfileScreen() async {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ProfileScreen(authService: widget.authService,)),
      ).then((_) => setState(() {}));
    }

    void navigateToLoginScreen() async {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => LoginScreen(authService: widget.authService,)),
      ).then((_) => setState(() {}));
    }

    print("Current User: " + FirebaseAuth.instance.currentUser.toString());

    if(FirebaseAuth.instance.currentUser == null){
      return ElevatedButton(onPressed: navigateToLoginScreen, child: Text("Login"));
    }

    return IconButton(
        onPressed: navigateToProfileScreen, icon: Icon(Icons.person));

  }

}
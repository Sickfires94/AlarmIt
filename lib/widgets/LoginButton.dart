import 'package:alarm_it/Services/AuthService.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../Screens/Login.dart';
import '../Screens/Profile.dart';

class LoginButtonWidget extends StatelessWidget {
  Widget build(BuildContext context) {

    void navigateToProfileScreen() async {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      );
    }

    print("Current User: " + FirebaseAuth.instance.currentUser.toString());

    return IconButton(
        onPressed: navigateToProfileScreen, icon: Icon(Icons.person));
  }
}
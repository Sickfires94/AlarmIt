import 'package:alarm_it/Screens/Home.dart';
import 'package:alarm_it/Services/AlarmListBloc.dart';
import 'package:alarm_it/Services/AuthService.dart';
import 'package:alarm_it/Services/LoginBloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatelessWidget {
  final AuthService authService = new AuthService();
  final _formKey = GlobalKey<FormState>();

  void _submitForm(BuildContext context){
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      var state = context.read<LoginBloc>().state;

      try {
        // Perform login/signup logic here
        if (state is LoginPageSelected) {
          context.read<LoginBloc>().add(handleLogin(context: context));
        } else {
          context.read<LoginBloc>().add(handleRegister());
          }
        } on FirebaseAuthException catch (e) {
        print(e.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message!),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // if(FirebaseAuth.instance.currentUser != null) {
    //   context.read<AlarmListBloc>()..add(fetchAlarmsList());
    //   Navigator.push(
    //     context,
    //     MaterialPageRoute(builder: (context) =>  HomeScreen(),),
    //   );
    // };
    var state = context.watch<LoginBloc>().state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm It'), // More specific app name
        centerTitle: true,
        backgroundColor: Colors.black, // Add a color
      ),
      backgroundColor: Colors.black,
      body: Container(

        margin: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          border: Border.all(color: Colors.white),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.grey,
              offset: Offset(0.0, 1.0), //(x,y)
              blurRadius: 6.0,
            ),
          ],
        ),
    child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          // Allow content to scroll if needed
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch buttons
              children: [
                const SizedBox(height: 40), // Add some top padding
                // Image.asset(
                //   // Add an app logo or image
                //   'assets/alarm_it_logo.png', // Replace with your image path
                //   height: 150,
                //   width: 150,
                // ),
                Icon(Icons.alarm, size: 150,),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(10.0), // Rounded corners
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value!.isEmpty || !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    context.read<LoginBloc>().setEmail(value ?? "");
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value!.isEmpty || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    context.read<LoginBloc>().setPassword(value ?? "");
                  },
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    _submitForm(context);
                  },
                  child: Text(
                    (state is LoginPageSelected) ? 'Login' : 'Signup',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize:
                        const Size(double.infinity, 50), // Stretch button
                    backgroundColor: Colors.grey.shade700, // Add a color
                  ),
                ),
                //const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    if(state is LoginPageSelected){
                      context.read<LoginBloc>().add(showRegisterPage());
                    }
                    else {
                      context.read<LoginBloc>().add(showLoginPage());
                    }
                  },
                  child: Text(
                    (state is LoginPageSelected)
                        ? 'Don\'t have an account? Signup'
                        : 'Already have an account? Login',
                    style: TextStyle(
                        color: Colors.white, fontSize: 15), // Add color
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await authService.signInWithGoogle();
                      context.read<AlarmListBloc>()..add(fetchAlarmsList());
                      Navigator.push(
                       context,
                        MaterialPageRoute(builder: (context) =>  HomeScreen(),),
                      );
                    } catch (e) {
                      print(e);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Google Login failed. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: Image.asset(
                    'assets/google_logo.png', // Replace with your Google logo
                    height: 75,
                    width: 75,
                  ),
                  // label: const Text('Continue with Google', style: TextStyle(color: Colors.blue, fontSize: 25),),
                  label: Text(""),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(50, 50),
                    maximumSize: const Size(75, 75),
                    backgroundColor:
                        Colors.white, // White background for Google
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

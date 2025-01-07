import 'package:alarm_it/Services/AuthService.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key, required this.authService}) : super(key: key);
  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoginMode = true;

  String _email = '';
  String _password = '';

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Perform login/signup logic here
      if (_isLoginMode) {
        // Handle login
        print('Email: $_email, Password: $_password');
        await widget.authService.login(email: _email, password: _password);
        Navigator.pop(context);
      } else {
        // Handle signup
        print('Email: $_email, Password: $_password');
        await widget.authService.registration(email: _email, password: _password);

        setState(() {
          _isLoginMode = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login/Signup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children:[
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isEmpty || !value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
                onSaved: (value) {
                  _email = value!;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value!.isEmpty || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                onSaved: (value) {
                  _password = value!;
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text(_isLoginMode ? 'Login' : 'Signup'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                  });
                },
                child: Text(_isLoginMode
                    ? 'Don\'t have an account? Signup'
                    : 'Already have an account? Login'),
              ),
        ElevatedButton(onPressed: () async {
          await widget.authService.signInWithGoogle();
          Navigator.pop(context);
        }, child: Text("Google Login")),
            ],
          ),
        ),
      ),
    );
  }
}
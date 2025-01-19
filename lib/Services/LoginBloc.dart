import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../Screens/Home.dart';
import 'AlarmListBloc.dart';
import 'AuthService.dart';


abstract class LoginEvent {}
class showLoginPage extends LoginEvent{}
class showRegisterPage extends LoginEvent{}
class handleRegister extends LoginEvent{}
class handleLogin extends LoginEvent{
  BuildContext context;
  handleLogin({required this.context});
}

abstract class LoginState{
  String email;
  String password;
  LoginState({required this.email, required this.password});

  LoginState copyWith({String? email, String? password});
}


class LoginPageSelected extends LoginState{
  LoginPageSelected({required super.email, required super.password});

  LoginPageSelected copyWith({String? email, String? password}){
    return LoginPageSelected(email: email ?? this.email, password: password ?? this.password);
  }

}
class RegisterPageSelected extends LoginState{
  RegisterPageSelected({required super.email, required super.password});

  RegisterPageSelected copyWith({String? email, String? password}){
    return RegisterPageSelected(email: email ?? this.email, password: password ?? this.password);
  }
}


class LoginBloc extends Bloc<LoginEvent, LoginState>{
  final AuthService authService = new AuthService();

  LoginBloc() : super(LoginPageSelected(email: 'Email Here', password: 'Password Here')){
    on<showLoginPage>((event, emit) => emit(LoginPageSelected(email: state.email, password: state.password)));
    on<showRegisterPage>((event, emit) => emit(RegisterPageSelected(email: state.email, password: state.password)));
    on<handleLogin>((event, emit,) => _handleLogin(event.context));
    on<handleRegister>((event, emit,) => _handleRegister());

  }



  void _handleLogin(BuildContext context) async {
    print("Email: " + state.email);
    print("Password" + state.password);
      await authService.login(email: state.email, password: state.password);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) =>  HomeScreen(),),
    );
  }

  void _handleRegister() async {
      await authService.registration(email: state.email, password: state.password);
      emit(LoginPageSelected(email: 'Email Here', password: 'Password Here'));
  }

  void setEmail(String email) {
    if (email.isNotEmpty) {
      emit(state.copyWith(email: email)); // Update the state
    }
  }

  void setPassword(String password) {
    if (password.isNotEmpty) {
      emit(state.copyWith(password: password));// Update the state

    }
  }

}
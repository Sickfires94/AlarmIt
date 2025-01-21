import 'package:alarm_it/Screens/Login.dart';
import 'package:alarm_it/Services/AuthService.dart';
import 'package:alarm_it/Services/LoginBloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';



class MockAuthService extends Mock implements AuthService{}

void main() {
  final MockAuthService mockAuthService = MockAuthService();
  final widget = MultiBlocProvider(
    providers: [
      BlocProvider<LoginBloc>(
        create: (BuildContext context) =>
            LoginBloc(authService: mockAuthService),
      ),
    ],
    child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.black,
          // Define the default brightness and colors.
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        home: LoginScreen()),
  );

  group('LoginScreen Golden Tests', () {
    testWidgets('renders login page with initial state (golden)',
        (WidgetTester tester) async {
      await tester.pumpWidget(widget);

      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_page_initial.png'),
      );
    });

    testWidgets('shows error message on invalid email (golden)',
        (WidgetTester tester) async {
      await tester.pumpWidget(widget);

      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'invalidEmail');
      await tester.pump();

      final loginButton = find.text('Login');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_page_invalid_email.png'),
      );
    });

    testWidgets('shows error message on short password (golden)',
        (WidgetTester tester) async {
      await tester.pumpWidget(widget);

      final passwordField = find.byType(TextFormField).at(1);
      await tester.enterText(passwordField, 'short');
      await tester.pump();

      final loginButton = find.text('Login');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_page_short_password.png'),
      );
    });

    testWidgets('renders register page (golden)', (WidgetTester tester) async {
      await tester.pumpWidget(widget);

      final registerButton = find.text('Don\'t have an account? Signup');
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_page_register.png'),
      );
    });
  });
}

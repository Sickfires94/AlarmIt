
import 'package:alarm_it/Screens/Home.dart';
import 'package:alarm_it/Screens/Login.dart';
import 'package:alarm_it/Services/AuthService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Mock the AuthService
class MockAuthService extends Mock implements AuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginScreen Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    testWidgets('form validation - invalid email', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(),
      ));

      // Find email and password fields
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);

      // Enter invalid email
      await tester.enterText(emailField, 'invalidemail');
      await tester.enterText(passwordField, '123456');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Check that the validation error appears
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('form validation - invalid password', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(),
      ));

      // Find email and password fields
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);

      // Enter valid email and invalid password
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, '123');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Check that the validation error appears
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('successful login navigates to HomeScreen', (WidgetTester tester) async {
      // Mock successful login
      when(mockAuthService.login(email: 'test@example.com', password: '123456'))
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(),
      ));

      // Find email and password fields
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);

      // Enter valid credentials
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, '123456');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify that navigation to HomeScreen occurred
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('handles FirebaseAuthException - invalid credentials', (WidgetTester tester) async {
      // Mock FirebaseAuthException
      final exception = FirebaseAuthException(
        code: 'wrong-password',
        message: 'Invalid credentials',
      );
      when(mockAuthService.login(email: 'test@example.com', password: 'wrongpassword'))
          .thenThrow(exception);

      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(),
      ));

      // Find email and password fields
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);

      // Enter invalid credentials
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'wrongpassword');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify that the error message appears
      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('handles other exceptions', (WidgetTester tester) async {
      // Mock a general error
      when(mockAuthService.login(email: 'test@example.com', password: 'wrongpassword'))
          .thenThrow(Exception('Unknown error'));

      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(),
      ));

      // Find email and password fields
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);

      // Enter invalid credentials
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'wrongpassword');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify that the generic error message appears
      expect(find.text('An error occurred. Please try again.'), findsOneWidget);
    });
  });
}

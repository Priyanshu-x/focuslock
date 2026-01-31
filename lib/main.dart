import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focuslock/screens/timer_screen.dart';
import 'package:focuslock/screens/lock_screen.dart';
import 'package:focuslock/services/detox_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((_) => runApp(const DigitalDetoxApp()));
}

class DigitalDetoxApp extends StatelessWidget {
  const DigitalDetoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Detox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: const RootNavigator(),
    );
  }
}

class RootNavigator extends StatelessWidget {
  const RootNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the singleton service
    final service = DetoxService();
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        // If detox is active OR alarm is ringing, show the Lock Screen
        if (service.isRunning || service.alarmPlaying) {
          return const LockScreen();
        }
        // Otherwise, show the Setup/Input Screen
        return const TimerScreen();
      },
    );
  }
}

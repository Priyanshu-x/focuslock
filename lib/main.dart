import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focuslock/screens/timer_screen.dart';
import 'package:focuslock/screens/lock_screen.dart';
import 'package:focuslock/services/detox_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // Init Service (Preload audio etc)
  await DetoxService().init();

  runApp(const DigitalDetoxApp());
}
  
class DigitalDetoxApp extends StatefulWidget {
  const DigitalDetoxApp({super.key});

  @override
  State<DigitalDetoxApp> createState() => _DigitalDetoxAppState();
}

class _DigitalDetoxAppState extends State<DigitalDetoxApp> with WidgetsBindingObserver {
  final DetoxService _service = DetoxService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_service.isRunning) {
      if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
         // Attempt to bring back if user tries to leave
         if (!_service.isInLockTaskMode) {
             _service.bringAppToForeground(); 
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Detox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          // Switch between LockScreen and TimerScreen based on state
          return Stack(
            children: [
               const TimerScreen(), // Always there
               if (_service.isRunning || _service.alarmPlaying)
                  const LockScreen(), // Overlays when running
            ],
          );
        },
      ),
    );
  }
}

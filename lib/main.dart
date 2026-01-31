import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:focuslock/widgets/particle_painter.dart';

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
      home: const DetoxHome(),
    );
  }
}

class DetoxHome extends StatefulWidget {
  const DetoxHome({super.key});

  @override
  _DetoxHomeState createState() => _DetoxHomeState();
}

class _DetoxHomeState extends State<DetoxHome> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.example.focuslock/detox');
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  Timer? _timer;
  bool _isRunning = false;
  bool _alarmPlaying = false;
  bool _isInLockTaskMode = false; // New state variable
  final TextEditingController _timerController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);


    // Preload audio to avoid playback delays
    _audioPlayer.setSourceAsset('alarm_sound.mp3').catchError((e) {
      print('Error preloading audio: $e');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _timerController.dispose();
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isRunning) {
      if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
        _showExitWarningAndBringBack();
      }
    }
  }

  void _showExitWarningAndBringBack() {
    if (!mounted) return; // Ensure the widget is still mounted

    showDialog(
      context: context,
      barrierDismissible: false, // User must interact with the dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Warning!"),
          content: const Text("You are in a detox session. Leaving the app is not allowed."),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
                // Attempt to bring the app back to the foreground
                _bringAppToForeground();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _bringAppToForeground() async {
    // This is a platform-specific operation.
    // For Android, we can use the platform channel to bring the app to front.
    // For other platforms, this might require different native implementations or might not be fully supported.
    if (Theme.of(context).platform == TargetPlatform.android) {
      try {
        await platform.invokeMethod('bringAppToForeground');
      } on PlatformException catch (e) {
        print("Failed to bring app to foreground: '${e.message}'.");
      }
    }
    // For other platforms (iOS, Desktop), Flutter itself doesn't provide a direct way
    // to programmatically bring the app to the foreground if it's minimized or in the background.
    // This would typically require native code integration for each platform.
    // For now, we'll focus on Android as it has a more direct API for this.
  }

  void _startDetox(int? minutes) async {
    if (minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number of minutes (greater than 0)')),
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
    });

    // Keep screen awake
    await WakelockPlus.enable();

    // Platform-specific lock task for Android
    if (Theme.of(context).platform == TargetPlatform.android) {
      try {
        await platform.invokeMethod('startLockTask');
      } on PlatformException catch (e) {
        if (e.code == "NOT_ADMIN") {
          _showDeviceAdminDialog(
            "Device Administrator Required",
            "To use lock task mode, you need to enable FocusLock as a device administrator. Please enable it in the next screen.",
            _enableDeviceAdmin,
          );
        } else if (e.code == "NOT_WHITELISTED") {
          _showDeviceAdminDialog(
            "App Not Whitelisted",
            "FocusLock needs to be whitelisted for lock task mode. Please ensure device admin is active and the app is whitelisted.",
            null, // No specific action for whitelisting, user needs to do it manually
          );
        }
        print("Failed to start lock task: '${e.message}'.");
      }
    }

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        _stopDetox();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
    _checkLockTaskModeStatus(); // Check status after starting detox
  }

  void _stopDetox() async {
    setState(() {
      _isRunning = false;
      _remainingSeconds = 0;
      _alarmPlaying = true;
    });

    _timer?.cancel();

    // Platform-specific unlock task for Android
    if (Theme.of(context).platform == TargetPlatform.android) {
      try {
        await platform.invokeMethod('stopLockTask');
      } on PlatformException catch (e) {
        print("Failed to stop lock task: '${e.message}'.");
      }
    }

    // Play alarm sound for up to 20 seconds
    try {
      await _audioPlayer.play(AssetSource('alarm_sound.mp3'));
      await Future.delayed(const Duration(seconds: 20), () {
        if (_alarmPlaying) {
          _audioPlayer.stop();
          setState(() {
            _alarmPlaying = false;
          });
        }
      });
    } catch (e) {
      print('Error playing sound: $e');
      setState(() {
        _alarmPlaying = false;
      });
    }

    // Allow screen to sleep
    await WakelockPlus.disable();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _stopAlarm() async {
    if (_alarmPlaying) {
      await _audioPlayer.stop();
      setState(() {
        _alarmPlaying = false;
      });
    }
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    if (_totalSeconds == 0) return 0.0;
    return 1.0 - (_remainingSeconds / _totalSeconds);
  }

  @override
  Widget build(BuildContext context) {
    if (_isRunning || _alarmPlaying) {
      // Detox screen with dynamic wallpaper and centered timer
      return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          body: Stack(
            children: [
              // Static volcano background
              Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/volcano_background.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Dynamic particle animation
              // Centered UI elements
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Centered timer with progress ring
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isRunning)
                            CircularProgressIndicator(
                              value: _getProgress(),
                              strokeWidth: 6,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple.withOpacity(0.6)),
                            ),
                          Text(
                            _formatTime(_remainingSeconds),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_alarmPlaying)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: ElevatedButton(
                          onPressed: _stopAlarm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 134, 103, 192),
                            minimumSize: const Size(150, 50),
                          ),
                          child: const Text('Stop Alarm'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Input screen when not in detox
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Digital Detox',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 50),
                TextField(
                  controller: _timerController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Enter detox time (minutes)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white24,
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildPresetButton(5),
                    _buildPresetButton(10),
                    _buildPresetButton(15),
                    _buildPresetButton(30),
                    _buildPresetButton(60), 
                    _buildPresetButton(120),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _startDetox(int.tryParse(_timerController.text)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 103, 192),
                    minimumSize: const Size(150, 50),
                  ),
                  child: const Text('Start Custom Detox'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _enableDeviceAdmin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    minimumSize: const Size(150, 50),
                  ),
                  child: const Text('Enable Device Admin'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkLockTaskModeStatus() async {
    try {
      final bool inLockTaskMode = await platform.invokeMethod('isInLockTaskMode');
      final bool isPermitted = await platform.invokeMethod('isLockTaskPermitted');
      setState(() {
        _isInLockTaskMode = inLockTaskMode;
      });
      print("Is in Lock Task Mode: $_isInLockTaskMode, Is Lock Task Permitted: $isPermitted");
    } on PlatformException catch (e) {
      print("Failed to check lock task mode status: '${e.message}'.");
    }
  }

  void _showDeviceAdminDialog(String title, String content, Function? onOkPressed) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
                onOkPressed?.call();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _enableDeviceAdmin() async {
    try {
      await platform.invokeMethod('enableDeviceAdmin');
    } on PlatformException catch (e) {
      print("Failed to enable device admin: '${e.message}'.");
    }
  }

  Widget _buildPresetButton(int minutes) {
    return ElevatedButton(
      onPressed: () => _startDetox(minutes),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple.shade300,
        minimumSize: const Size(100, 40),
      ),
      child: Text('$minutes min'),
    );
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DetoxMode {
  standard,
  gravity,
  ghost,
  launcher
}

class DetoxService extends ChangeNotifier {
  static final DetoxService _instance = DetoxService._internal();
  factory DetoxService() => _instance;
  DetoxService._internal();

  static const platform = MethodChannel('com.example.focuslock/detox');
  static const String KEY_IS_LOCKED = "flutter.isLocked";
  
  // State
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  bool _isRunning = false;
  bool _alarmPlaying = false;
  bool _isInLockTaskMode = false;
  Set<DetoxMode> _activeModes = {DetoxMode.standard};
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription? _sensorSubscription;

  // Getters
  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  bool get isRunning => _isRunning;
  bool get alarmPlaying => _alarmPlaying;
  bool get isInLockTaskMode => _isInLockTaskMode;
  Set<DetoxMode> get activeModes => _activeModes;
  double get progress => _totalSeconds == 0 ? 0.0 : 1.0 - (_remainingSeconds / _totalSeconds);

  void toggleMode(DetoxMode mode) {
    if (mode == DetoxMode.standard) {
      _activeModes = {DetoxMode.standard};
    } else {
      if (_activeModes.contains(mode)) {
        _activeModes.remove(mode);
        if (_activeModes.isEmpty) _activeModes.add(DetoxMode.standard);
      } else {
        _activeModes.remove(DetoxMode.standard);
        _activeModes.add(mode);
      }
    }
    notifyListeners();
  }

  Future<void> init() async {
    // Preload audio
    try {
      if (kIsWeb) return; 
      await _audioPlayer.setSource(AssetSource('alarm_sound.mp3'));
      // We don't preload gravity sound to save memory until needed, or we can:
      // await _audioPlayer.setSource(AssetSource('gravity_sound.mp3')); 
      // Multi-sound support with single player is tricky, best to set source on play.
      await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
    } catch (e) {
      debugPrint('Error preloading audio: $e');
    }
    checkLockTaskModeStatus();
    // Ensure we start unlocked
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_IS_LOCKED, false);
  }

  void startDetox(int minutes) async {
    if (minutes <= 0) return;

    _totalSeconds = minutes * 60;
    _remainingSeconds = _totalSeconds;
    _isRunning = true;
    notifyListeners();

    // Enable wakelock
    await WakelockPlus.enable();

    // Set Shared Prefs for Accessibility Service
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_IS_LOCKED, true);

    // Also try standard pinning as fallback
    try {
      await platform.invokeMethod('startLockTask');
    } on PlatformException catch (e) {
      debugPrint("Failed to start lock task: '${e.message}'.");
    }
    
    _checkLockTaskModeStatus();

    // Start Gravity Check if needed
    if (_activeModes.contains(DetoxMode.gravity)) {
      _startGravityCheck();
    }
    
    // Force Max Volume
    await setMaxVolume();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        // Enforce Max Volume consistently
        setMaxVolume(); // Volume Guardian
        notifyListeners();
      } else {
        stopDetox();
      }
    });
  }

  void stopDetox() async {
    _sensorSubscription?.cancel(); // Stop sensor check
    
    _isRunning = false;
    _remainingSeconds = 0;
    _alarmPlaying = true;
    _timer?.cancel();
    notifyListeners();

    // Disable Shared Prefs Lock
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_IS_LOCKED, false);

    // Stop Lock Task
    try {
      await platform.invokeMethod('stopLockTask');
    } on PlatformException catch (e) {
       debugPrint("Failed to stop lock task: '${e.message}'.");
    }
    _checkLockTaskModeStatus();

    // Play Alarm (Success/Done)
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.release); // Don't loop success alarm forever
      await _audioPlayer.play(AssetSource('alarm_sound.mp3'));
      Future.delayed(const Duration(seconds: 20), () {
        if (_alarmPlaying) stopAlarm();
      });
    } catch (e) {
      debugPrint('Error playing sound: $e');
      _alarmPlaying = false;
      notifyListeners();
    }

    await WakelockPlus.disable();
  }

  void triggerAlarm() {
    if (!_alarmPlaying && _isRunning) {
      _alarmPlaying = true;
      notifyListeners();
      _audioPlayer.setReleaseMode(ReleaseMode.loop);
      _audioPlayer.play(AssetSource('gravity_sound.mp3')); // Use annoying sound
      WakelockPlus.enable();
    }
  }

  void stopAlarm() async {
    if (_alarmPlaying) {
      await _audioPlayer.stop();
      _alarmPlaying = false;
      notifyListeners();
    }
  }

  void _startGravityCheck() {
    _sensorSubscription?.cancel();
    _sensorSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      // Logic: If Z axis is NOT close to 9.8 (or -9.8), assume picked up
      // Threshold: 9.75 means almost ZERO tolerance (approx 5 degrees tilt allowed)
      // Note: If your table isn't level, this might trigger continuously!
      bool isFlat = event.z.abs() > 9.75;

      if (!isFlat && !_alarmPlaying && _isRunning) {
        // PUNISHMENT!
        _alarmPlaying = true;
        notifyListeners();
        _audioPlayer.setReleaseMode(ReleaseMode.loop);
        _audioPlayer.play(AssetSource('gravity_sound.mp3')); // USE NEW SOUND
        WakelockPlus.enable(); // Force screen on
      } else if (isFlat && _alarmPlaying && _isRunning) {
        // MERCY (Put back down)
        _audioPlayer.stop();
        _alarmPlaying = false;
        notifyListeners();
      }
    });
  }



  Future<void> setBackGestureExclusion() async {
    try {
      await platform.invokeMethod('setBackGestureExclusion');
    } on PlatformException catch (e) {
      debugPrint("Failed to set gesture exclusion: '${e.message}'.");
    }
  }

  Future<Map<String, int>> getRealScreenSize() async {
    try {
      final result = await platform.invokeMethod('getRealScreenSize');
      return Map<String, int>.from(result);
    } catch (e) {
      debugPrint("Failed to get real screen size: $e");
      return {'width': 0, 'height': 0};
    }
  }

  Future<void> showOverlay() async {
    try {
      await platform.invokeMethod('showOverlay');
    } catch (e) {
      debugPrint("Overlay Config Error: $e");
    }
  }

  Future<void> hideOverlay() async {
     try {
      await platform.invokeMethod('hideOverlay');
    } catch (e) {
      debugPrint("Overlay Config Error: $e");
    }
  }

  Future<bool> checkOverlayPermission() async {
    try {
      return await platform.invokeMethod('checkOverlayPermission') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await platform.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint("Permission Request Error: $e");
    }
  }

  Future<void> setMaxVolume() async {
    await platform.invokeMethod('setMaxVolume');
  }

  Future<bool> isAdminActive() async {
    try {
      return await platform.invokeMethod('isAdminActive') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isAccessibilityEnabled() async {
    try {
      return await platform.invokeMethod('isAccessibilityEnabled') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint("Settings Error: $e");
    }
  }

  Future<void> enableDeviceAdmin() async {
    try {
      await platform.invokeMethod('enableDeviceAdmin');
    } catch (e) {
      debugPrint("Admin Error: $e");
    }
  }

  Future<void> checkLockTaskModeStatus() async {
    try {
      final bool inLockTaskMode = await platform.invokeMethod('isInLockTaskMode');
      _isInLockTaskMode = inLockTaskMode;
      notifyListeners();
    } on PlatformException catch (e) {
      debugPrint("Failed to check lock task mode status: '${e.message}'.");
    }
  }
  
  // Checks
  Future<bool> isLockTaskPermitted() async {
    try {
      return await platform.invokeMethod('isLockTaskPermitted');
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<void> bringAppToForeground() async {
      try {
        await platform.invokeMethod('bringAppToForeground');
      } on PlatformException catch (e) {
        debugPrint("Failed to bring app to foreground: '${e.message}'.");
      }
  }
  
  Future<bool> isDeviceOwner() async {
     try {
        return await platform.invokeMethod('isDeviceOwner');
     } catch (_) {
        return false;
     }
  }

  void _checkLockTaskModeStatus() {
      checkLockTaskModeStatus(); 
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}


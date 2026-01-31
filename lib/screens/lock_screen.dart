import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focuslock/services/detox_service.dart';


class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final DetoxService _service = DetoxService();
  late AnimationController _controller;
  
  // Loophole State
  Timer? _loopholeTimer;
  int _loopholeSecondsHeld = 0;
  bool _isHolding = false;
  
  // Ghost UI State
  bool _ghostWarningVisible = false;
  Timer? _ghostWarningTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Hide Status Bar and Navigation Bar (Immersive Sticky)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Request System Gesture Exclusion (Blocks "Back" swipe on edges)
    _service.setBackGestureExclusion();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _loopholeTimer?.cancel();
    _ghostWarningTimer?.cancel();
    // Restore System UI when leaving (optional, but good practice)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_service.isRunning) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // User left the app (or Floating Window logic might pause it)
      // Trigger Native Overlay!
      _service.showOverlay();
    } else if (state == AppLifecycleState.resumed) {
      // User came back
      _service.hideOverlay();
    }
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    if (_service.totalSeconds == 0) return 0.0;
    return 1.0 - (_service.remainingSeconds / _service.totalSeconds);
  }

  void _onPointerDown(PointerDownEvent event) {
    setState(() {
      _isHolding = true;
      _loopholeSecondsHeld = 0;
    });

    _loopholeTimer?.cancel();
    _loopholeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _loopholeSecondsHeld++;
      });
      
      if (_loopholeSecondsHeld >= 10) {
        // Unlock triggered!
        _loopholeTimer?.cancel();
        _service.stopDetox();
        setState(() {
          _isHolding = false;
        });
      }
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _resetLoophole();
  }
  
  void _onPointerCancel(PointerCancelEvent event) {
    _resetLoophole();
  }

  void _resetLoophole() {
    _loopholeTimer?.cancel();
    setState(() {
      _isHolding = false;
      _loopholeSecondsHeld = 0;
    });
  }

  void _triggerGhostWarning() {
    if (_ghostWarningVisible) return;
    setState(() => _ghostWarningVisible = true);
    _ghostWarningTimer?.cancel();
    _ghostWarningTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _ghostWarningVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to service changes
    return ListenableBuilder(
      listenable: _service,
      builder: (context, child) {
         if (!_service.isRunning && !_service.alarmPlaying) {
             return const SizedBox.shrink(); 
         }

        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: _service.activeModes.contains(DetoxMode.ghost) ? Colors.black : null,
            body: Stack(
                children: [
                  // Background
                  if (!_service.activeModes.contains(DetoxMode.ghost))
                   Container(
                     decoration: const BoxDecoration(
                       image: DecorationImage(
                         image: AssetImage('assets/volcano_background.png'),
                         fit: BoxFit.cover,
                       ),
                     ),
                   )
                  else
                   GestureDetector(
                     onTap: _triggerGhostWarning,
                     behavior: HitTestBehavior.opaque,
                     child: Container(color: Colors.black),
                   ),

                  // Centered timer with progress ring
                  // GESTURE TRAP: Detect if system steals touch (Home Swipe)
                  Listener(
                    onPointerDown: (event) {
                       // Check if touch starts at bottom 10% of screen
                       final screenHeight = MediaQuery.of(context).size.height;
                       if (event.position.dy > screenHeight * 0.9) {
                         // Potential Home Swipe
                         debugPrint("Bottom Touch Detected");
                       }
                    },
                    onPointerCancel: (event) {
                       // System stole the touch! (Home Gesture likely)
                       if (_service.isRunning) {
                         _service.triggerAlarm(); // Immediate Punishment
                       }
                    },
                    child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Listener(
                          onPointerDown: _onPointerDown,
                          onPointerUp: _onPointerUp,
                          onPointerCancel: _onPointerCancel,
                          behavior: HitTestBehavior.opaque,
                          child: _service.activeModes.contains(DetoxMode.ghost) 
                            ? Container(width: 150, height: 150, color: Colors.transparent) // Invisible target
                            : Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (_service.isRunning)
                                      CircularProgressIndicator(
                                        value: _getProgress(),
                                        strokeWidth: 6,
                                        backgroundColor: Colors.transparent,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple.withOpacity(0.6)),
                                      ),
                                    Text(
                                      _formatTime(_service.remainingSeconds),
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
                        ),
                         
                        if (_service.alarmPlaying && !_service.isRunning)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: ElevatedButton(
                              onPressed: _service.stopAlarm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 134, 103, 192),
                                minimumSize: const Size(150, 50),
                              ),
                              child: const Text('Stop Alarm', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ),

                  // Ghost Warning
                  if (_service.activeModes.contains(DetoxMode.ghost) && _ghostWarningVisible)
                    const Center(
                      child: Text("SYSTEM LOCKED", style: TextStyle(color: Colors.red, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                    )
                ],
              ),
          ),
        );
      },
    );
  }
}

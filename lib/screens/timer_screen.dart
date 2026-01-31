import 'package:flutter/material.dart';
import 'package:focuslock/services/detox_service.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final TextEditingController _timerController = TextEditingController();
  final DetoxService _service = DetoxService();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    // Check all permissions
    bool overlay = await _service.checkOverlayPermission();
    bool admin = await _service.isAdminActive();
    bool accessibility = await _service.isAccessibilityEnabled();

    if (!overlay || !admin || !accessibility) {
      if (mounted) _showSetupDialog(overlay, admin, accessibility);
    }
  }

  void _showSetupDialog(bool overlay, bool admin, bool accessibility) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SetupDialog(
        service: _service,
        initialOverlay: overlay,
        initialAdmin: admin,
        initialAccessibility: accessibility,
      ),
    );
  }

  void _startCustomDetox() {
    final int? minutes = int.tryParse(_timerController.text);
    if (minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number of minutes (greater than 0)')),
      );
      return;
    }
    _service.startDetox(minutes);
  }

  Widget _buildPresetButton(int minutes) {
    return ElevatedButton(
      onPressed: () => _service.startDetox(minutes),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple.shade300,
        minimumSize: const Size(100, 40),
      ),
      child: Text('$minutes min', style: const TextStyle(color: Colors.white)),
    );
  }

  void _showModeSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Mode"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListenableBuilder(
              listenable: _service,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogOption(DetoxMode.standard, "Standard", Icons.lock_outline, "Just the timer."),
                    _buildDialogOption(DetoxMode.gravity, "Gravity Trap", Icons.screen_rotation, "Alarm if lifted."),
                    _buildDialogOption(DetoxMode.ghost, "Ghost UI", Icons.visibility_off, "Black screen."),
                    _buildDialogOption(DetoxMode.launcher, "Takeover", Icons.home_filled, "Trap in app."),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Done"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogOption(DetoxMode mode, String title, IconData icon, String subtitle) {
    final isSelected = _service.activeModes.contains(mode);
    return CheckboxListTile(
      value: isSelected,
      onChanged: (_) => _service.toggleMode(mode),
      title: Row(children: [Icon(icon, size: 20, color: Colors.deepPurple), const SizedBox(width: 10), Text(title)]),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      activeColor: Colors.deepPurple,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: IconButton(
                  icon: const Icon(Icons.tune, color: Colors.white70),
                  tooltip: "Select Penalty Modes",
                  onPressed: () => _showModeSelectionDialog(context),
                ),
              );
            }
          ),
        ],
      ),
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
                onPressed: _startCustomDetox,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 134, 103, 192),
                  minimumSize: const Size(150, 50),
                ),
                child: const Text('Start Custom Detox', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _service.enableDeviceAdmin(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  minimumSize: const Size(150, 50),
                ),
                child: const Text('Enable Device Admin', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupDialog extends StatefulWidget {
  final DetoxService service;
  final bool initialOverlay;
  final bool initialAdmin;
  final bool initialAccessibility;

  const _SetupDialog({
    required this.service,
    required this.initialOverlay,
    required this.initialAdmin,
    required this.initialAccessibility,
  });

  @override
  State<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<_SetupDialog> with WidgetsBindingObserver {
  late bool overlay;
  late bool admin;
  late bool accessibility;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    overlay = widget.initialOverlay;
    admin = widget.initialAdmin;
    accessibility = widget.initialAccessibility;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final o = await widget.service.checkOverlayPermission();
    final ad = await widget.service.isAdminActive();
    final ac = await widget.service.isAccessibilityEnabled();
    if (mounted) {
      setState(() {
        overlay = o;
        admin = ad;
        accessibility = ac;
      });
    }
  }

  Widget _buildStep(String title, String subtitle, bool isDone, VoidCallback onAction) {
    return ListTile(
      leading: Icon(
        isDone ? Icons.check_circle : Icons.error_outline,
        color: isDone ? Colors.green : Colors.red,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: isDone 
          ? null 
          : ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 30),
              ),
              child: const Text("Fix"),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool allDone = overlay && admin && accessibility;

    return AlertDialog(
      title: const Text("Required Setup"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStep(
            "1. Allow Overlays", 
            "Required to block floating windows.", 
            overlay, 
            () => widget.service.requestOverlayPermission(),
          ),
          const Divider(),
          _buildStep(
            "2. Enable Device Admin", 
            "Required to lock the screen.", 
            admin, 
            () => widget.service.enableDeviceAdmin(),
          ),
          const Divider(),
          _buildStep(
            "3. Enable Accessibility", 
            "Go to Downloaded Apps > FocusLock > ON.", 
            accessibility, 
            () => widget.service.openAccessibilitySettings(),
          ),
        ],
      ),
      actions: [
        
          TextButton(
            onPressed: allDone ? () => Navigator.pop(context) : null,
            child: Text("Done! Let's Go", style: TextStyle(color: allDone ? Colors.blue : Colors.grey)),
          )
        
      ],
    );
  }
}

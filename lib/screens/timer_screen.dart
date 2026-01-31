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
  void dispose() {
    _timerController.dispose();
    super.dispose();
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

  Future<void> _checkPermissions() async {
    bool hasOverlay = await _service.checkOverlayPermission();
    if (!hasOverlay) {
      if (mounted) _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Permission Required"),
        content: const Text("To prevent 'Floating Window' monitoring, FocusLock needs 'Display over other apps' permission."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _service.requestOverlayPermission();
            },
            child: const Text("Grant Permission"),
          ),
        ],
      ),
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
      backgroundColor: Colors.black, // Explicit black background (Step 14)
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
                'Digital Detox', // Original Title
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
                  labelText: 'Enter detox time (minutes)', // Original label
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white24, // Original fill
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
                  _buildPresetButton(10), // Original buttons had 10
                  _buildPresetButton(15),
                  _buildPresetButton(30),
                  _buildPresetButton(60),
                  _buildPresetButton(120), // Original had 120
                ],
              ),
              const SizedBox(height: 20),
              
              const SizedBox(height: 10),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _startCustomDetox,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 134, 103, 192), // Original color
                  minimumSize: const Size(150, 50),
                ),
                child: const Text('Start Custom Detox', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _service.enableDeviceAdmin(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey, // Original color
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

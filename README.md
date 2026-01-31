# FocusLock 🛡️📵

![FocusLock Hero Banner](hero_banner.png)

> **The Unescapable Digital Detox Solution**

[![Download APK](https://img.shields.io/badge/Download-FocusLock_v1.0.apk-purple?style=for-the-badge&logo=android)](FocusLock.apk)

FocusLock is a high-security productivity application engineered to enforce genuine digital disconnects. Unlike standard blocking apps that are easily bypassed via task managers or system gestures, FocusLock leverages low-level Android APIs and a specialized hybrid architecture to ensure total compliance during detox sessions.

## 📸 Functionality Gallery
| Setup Checklist | Detox Timer | Lock Screen |
|:---:|:---:|:---:|
| ![Setup Checklist](screenshots/setup.png) | ![Timer Screen](screenshots/timer.png) | ![Lock Screen](screenshots/lock.png) |
| *Ensures Permissions* | *Set your goal* | *No Escape* |

---

## 🚀 Features

### 1. Hybrid Native Architecture
FocusLock is not just a Flutter UI; it is a **native Android enforcer** wrapped in a modern Dart shell. We utilize high-performance **MethodChannels** to bridge the Flutter framework directly with Android's `WindowManager`, `AudioManager`, and `DevicePolicyManager`.

### 2. Multi-Layered Security "Trap"
We implemented a defense-in-depth strategy to prevent bypass attempts:
*   **System Alert Window Overlay**: A `TYPE_APPLICATION_OVERLAY` view is injected directly into the Window Manager stack, detecting `onPause` lifecycles (e.g., floating windows or split-screen attempts) and instantly occluding the screen.
*   **Touch Event Interception**: A custom **Accessibility Service** (`FocusLockAccessibilityService`) runs at the system level to intercept and consume specific `KeyEvent` signals.
*   **Gesture Exclusion Rects**: We programmatically set `systemGestureExclusionRects` to nullify Android 10+ edge-swipe "Back" gestures.

### 3. Hardware-Level Volume Guardian
To prevent users from silencing alarms during a session:
*   **Audio Focus Seizure**: The app programmatically forces the `STREAM_MUSIC` channel to logical maximum on session start.
*   **Input Consumption**: The Accessibility Service actively listens for `KEYCODE_VOLUME_DOWN` and `KEYCODE_VOLUME_MUTE`. These events are "eaten" (consumed) before they reach the OS, rendering the physical volume buttons inert.

### 4. Admin-Level Kiosk Mode
FocusLock requests **Device Admin** privileges to invoke `startLockTask()`, putting the device into a pinned state that disables the Status Bar, Notification Shade, and Home Button.

---

## 🛠️ Technical Stack

*   **Frontend**: Flutter (Dart 3.x) - *Null Safety, Material 3 Design*
*   **Backend Enforcer**: Kotlin - *Android Native Development Kit*
*   **State Management**: `ListenableBuilder` / `ChangeNotifier` service pattern.
*   **Sensors**: `sensors_plus` for Accelerometer-based "Gravity Trap".

---

## 🔐 Required Permissions
Due to the aggressive nature of the locking mechanism, FocusLock requires sensitive permissions. A built-in **Setup Checklist Dialogue** ensures these are granted before use:

1.  **Display Over Other Apps (`SYSTEM_ALERT_WINDOW`)**: To block floating windows.
2.  **Device Admin (`BIND_DEVICE_ADMIN`)**: To enable Screen Pinning.
3.  **Accessibility Service (`BIND_ACCESSIBILITY_SERVICE`)**: To block Recents/Home gestures and Volume buttons.

---

## ⚡ Deployment
FocusLock is designed for Android.

```bash
# Clone the repository
git clone https://github.com/Priyanshu-x/focuslock.git

# Install Dependencies
flutter pub get

# Run on Device (Release Mode recommended for full performance)
flutter run --release
```

---

*This application demonstrates advanced usage of Android System APIs and should be used responsibly.*

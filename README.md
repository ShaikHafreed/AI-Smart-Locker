# 🔐 AI Smart Cupboard — Intelligent Security Locker System

> Final Year Minor Project | B.Tech | 2026

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.13-green)](https://python.org)
[![Flask](https://img.shields.io/badge/Flask-3.x-red)](https://flask.palletsprojects.com)
[![DeepFace](https://img.shields.io/badge/DeepFace-ArcFace-orange)](https://github.com/serengil/deepface)
[![ESP32](https://img.shields.io/badge/ESP32-CAM-yellow)](https://www.espressif.com)

---

## 📌 Project Overview

AI Smart Cupboard is an intelligent IoT security system that uses **facial recognition** to identify the owner of a locker/cupboard. When someone opens the locker, the ESP32-CAM captures a photo and sends it to a Flask backend running DeepFace AI. If the person is the owner, access is granted silently. If an unknown person is detected, the owner receives an instant push notification on their phone to **Approve or Reject** access. On rejection, a buzzer alarm activates and 10 evidence photos are captured automatically.

---

## 🏗️ System Architecture

```
┌─────────────────┐     WiFi      ┌──────────────────┐     ngrok      ┌─────────────────┐
│   ESP32-CAM     │ ──────────── │  Flask Backend   │ ──────────── │  Flutter App    │
│  (Hardware)     │              │  (AI Server)     │              │  (Mobile App)   │
│                 │              │                  │              │                 │
│ • Reed Switch   │ POST /verify │ • DeepFace AI    │ GET /status  │ • Dashboard     │
│ • Buzzer        │ ──────────→  │ • ArcFace Model  │ ←──────────  │ • Logs Screen   │
│ • Mute Button   │              │ • JWT Auth       │              │ • Owner Faces   │
│ • Camera        │ POST /evidence│ • SQLite DB     │ FCM Push     │ • Approve/Reject│
└─────────────────┘              │ • Firebase FCM   │ ──────────→  │ • OTP Login     │
                                 │ • MSG91 OTP      │              │ • Google Sign-In│
                                 └──────────────────┘              └─────────────────┘
```

---

## 🛠️ Tech Stack

### Hardware
| Component | Specification | Purpose |
|---|---|---|
| ESP32-CAM | AI Thinker Module | Camera + WiFi + Processing |
| Reed Switch | GPIO13 | Door open/close detection |
| Active Buzzer | GPIO15 (active-LOW) | Intruder alarm |
| Mute Button | GPIO14 | Silence alarm |
| USB-to-TTL | FTDI Adapter | Programming ESP32 |

### Software — Backend
| Technology | Version | Purpose |
|---|---|---|
| Python | 3.13 | Backend language |
| Flask | 3.x | REST API framework |
| DeepFace | Latest | Facial recognition library |
| ArcFace | Model | Face verification model |
| MTCNN | Detector | Face detection |
| SQLite | 3.x | Local database |
| PyJWT | 2.8 | JWT token generation |
| Firebase Admin | 6.x | FCM push notifications |
| ngrok | 3.x | Local server tunneling |

### Software — Mobile App
| Technology | Version | Purpose |
|---|---|---|
| Flutter | 3.x | Cross-platform mobile framework |
| Dart | 3.x | Programming language |
| HTTP | 1.2 | API calls |
| SharedPreferences | 2.2 | Local token storage |
| Firebase Messaging | 16.x | Push notifications |
| Google Sign-In | 6.2 | OAuth authentication |
| Flutter Local Notifications | 19.x | Local notification display |

---

## 📁 Project Structure

```
AI_SMART_LOCKER/
├── backend/
│   ├── app.py                 # Main Flask application
│   ├── fcm_service.py         # Firebase push notification service
│   ├── firebase_key.json      # Firebase service account (excluded from git)
│   ├── locker.db              # SQLite database
│   ├── uploads/               # Visitor captured images
│   ├── owner_faces/           # Owner reference photos
│   └── venv/                  # Python virtual environment
│
├── mobile_app_new/
│   ├── lib/
│   │   ├── main.dart          # App entry point + navigation
│   │   ├── api_service.dart   # API calls with JWT auth
│   │   ├── notification_service.dart  # FCM handler
│   │   └── screens/
│   │       ├── auth_screen.dart       # Login (OTP + Google)
│   │       ├── dashboard_screen.dart  # Home screen with stats
│   │       ├── logs_screen.dart       # Event history
│   │       ├── profile_screen.dart    # User profile + settings
│   │       ├── owner_faces_screen.dart # Manage owner photos
│   │       ├── gallery_screen.dart    # Visitor image gallery
│   │       └── approval_request_screen.dart # Approve/Reject
│   └── android/
│       └── app/
│           ├── google-services.json   # Firebase config
│           └── src/main/kotlin/
│               └── MainActivity.kt    # Native camera/gallery
│
└── esp32_cam/
    ├── esp32_cam.ino          # Main Arduino sketch
    └── board_config.h         # ESP32-CAM pin definitions
```

---

## 🔐 Security Architecture

### Authentication Flow
```
User opens app
      ↓
SplashRouter checks JWT token in SharedPreferences
      ↓
Token exists? → Home Screen
Token missing? → Auth Screen
      ↓
Phone OTP Login:
  1. User enters phone number
  2. Flask generates 6-digit OTP (valid 5 min)
  3. MSG91 sends real SMS (demo: shown in app)
  4. User enters OTP → Flask verifies
  5. JWT token generated (30-day expiry)
  6. Token saved to SharedPreferences
  7. User goes to Home Screen

Google Sign-In:
  1. User taps Google button
  2. Google OAuth flow
  3. ID token sent to Flask
  4. Flask verifies with Google servers
  5. JWT token generated
  6. User goes to Home Screen
```

### JWT Protection
Every API call sends:
```
Authorization: Bearer <jwt_token>
```

ESP32 sends:
```
Authorization: Device ESP32_DEVICE_SECRET_TOKEN_2026
```

### Password Security
- Passwords hashed with SHA-256 + salt
- No plaintext passwords stored in database
- JWT tokens expire after 30 days

---

## 🤖 AI Face Recognition Flow

```
Door Opens (Reed Switch triggered)
        ↓
ESP32-CAM captures JPEG photo
        ↓
HTTP POST to /verify with auth header
        ↓
Flask receives image
        ↓
Step 1: MTCNN detects face in image
        ↓
  No face? → Log "No Face Detected" → Stop
        ↓
Step 2: ArcFace compares with all owner photos
        ↓
  Match (similarity ≥ 50%)? → Log "Owner Verified"
                             → Send FCM notification
                             → Access Granted ✅
        ↓
  No match? → Log "Intruder Detected"
            → Send FCM alert to owner
            → Start 60-second approval window
            → Poll /pending_access every 200ms
                    ↓
            Owner Approves → Access Granted ✅
            Owner Rejects  → Buzzer ON 🚨
                           → Capture 10 evidence photos
                           → Send to Telegram
            No Response    → Treat as Intruder
```

---

## 🗄️ Database Schema

```sql
-- Users table (authentication)
CREATE TABLE users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT,
    email         TEXT UNIQUE,
    phone         TEXT UNIQUE,
    password_hash TEXT,          -- SHA-256 hashed
    google_id     TEXT UNIQUE,
    auth_method   TEXT,          -- 'phone' or 'google'
    created_at    TEXT,
    last_login    TEXT
);

-- Visitor event logs
CREATE TABLE visitor_logs (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    event_time TEXT,
    result     TEXT,             -- Owner Verified / Intruder Detected
    similarity REAL,             -- Face similarity percentage
    image_name TEXT
);

-- FCM tokens for push notifications
CREATE TABLE mobile_tokens (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    INTEGER,
    token      TEXT,
    created_at TEXT
);

-- System event audit trail
CREATE TABLE system_events (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    event_time  TEXT,
    description TEXT
);
```

---

## 📱 App Screens

| Screen | Description |
|---|---|
| Splash Screen | Auto-checks JWT token → routes to Login or Home |
| Auth Screen | Phone OTP + Google Sign-In with animated lock logo |
| Dashboard | Real-time stats, locker status, recent activity |
| Logs Screen | Color-coded event history with similarity scores |
| Profile Screen | User info, system stats, sign out |
| Owner Faces | Add/delete owner reference photos (camera/gallery) |
| Gallery | All captured visitor images |
| Approval Request | Approve or Reject unknown visitor |

---

## 🚀 How to Run

### Prerequisites
- Python 3.13+
- Flutter 3.x
- Android phone (API 21+)
- ngrok account
- Firebase project

### Backend Setup
```bash
# Clone repo
git clone https://github.com/ShaikHafreed/AI-Smart-Locker.git
cd AI_SMART_LOCKER/backend

# Create virtual environment
python -m venv venv
venv\Scripts\Activate.ps1  # Windows
source venv/bin/activate   # Linux/Mac

# Install dependencies
pip install flask flask-cors deepface PyJWT firebase-admin requests

# Run server
python app.py
```

### ngrok Setup
```bash
ngrok http 5000
# Copy the https://xxxx.ngrok-free.dev URL
# Update baseUrl in lib/api_service.dart
```

### Flutter App Setup
```bash
cd mobile_app_new
flutter pub get
flutter run
```

### ESP32 Setup
1. Open `esp32_cam.ino` in Arduino IDE
2. Update WiFi credentials and Flask server IP
3. Select board: AI Thinker ESP32-CAM
4. Upload sketch

---

## ⚙️ API Reference

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | /auth/send_otp | Public | Send OTP to phone |
| POST | /auth/verify_otp | Public | Verify OTP, get JWT |
| POST | /auth/google | Public | Google Sign-In |
| GET | /status | JWT | Locker status + stats |
| GET | /logs | JWT | Event history |
| GET | /owner_faces | JWT | List owner photos |
| POST | /upload_owner_face | JWT | Add owner photo |
| DELETE | /owner_faces/<file> | JWT | Delete owner photo |
| GET | /approve | JWT | Approve visitor |
| GET | /reject | JWT | Reject visitor |
| POST | /verify | Device Token | ESP32 face verification |
| POST | /evidence | Device Token | ESP32 evidence upload |
| GET | /pending_access | Device Token | Check approval status |

---

## ⚔️ Challenges & Solutions

### Hardware Challenges

**Challenge 1: ESP32-CAM not uploading sketch**
- Problem: Boot mode issue — GPIO0 must be grounded during upload
- Solution: Hold GPIO0 to GND, press RST button, then upload

**Challenge 2: Camera capture failing intermittently**
- Problem: Insufficient power causing camera init failure
- Solution: Added retry logic (3 attempts with 5s delay between)

**Challenge 3: Buzzer not working**
- Problem: Buzzer is active-LOW — HIGH = OFF, LOW = ON
- Solution: Inverted logic — `digitalWrite(BUZZER_PIN, LOW)` to activate

### Software Challenges

**Challenge 4: image_picker package — 65 build errors**
- Problem: Kotlin version incompatibility with image_picker_android
- Solution: Replaced with native Android platform channel (MethodChannel) in Kotlin

**Challenge 5: JWT auth blocking image preview**
- Problem: Flutter's `Image.network()` doesn't support custom auth headers
- Solution: Fetch image bytes manually with `http.get()` + auth header, display with `Image.memory()`

**Challenge 6: ngrok ERR_NGROK_6024**
- Problem: ngrok shows browser warning page instead of forwarding to Flask
- Solution: Added `ngrok-skip-browser-warning: true` header to all API calls

**Challenge 7: Owner face routes returning 404**
- Problem: New routes were accidentally added after `app.run()` — Flask never registers them
- Solution: Moved all routes above the `if __name__ == "__main__":` block

**Challenge 8: Google Sign-In ApiException 10**
- Problem: SHA-1 fingerprint not registered in Firebase console
- Solution: Generated SHA-1 with keytool, added to Firebase project settings

**Challenge 9: API loading too slow**
- Problem: Status and logs were fetched sequentially (one after other)
- Solution: Used `Future.wait()` to fetch both in parallel — cut load time in half

**Challenge 10: "Reply already submitted" crash**
- Problem: Platform channel sending result twice when camera permission denied
- Solution: Added `safeReply()` wrapper that clears pendingResult before replying

---

## 📊 Results

| Metric | Value |
|---|---|
| Face Recognition Accuracy | ~85-95% (good lighting) |
| Verification Time | 3-8 seconds |
| Notification Delivery | < 2 seconds |
| Approval Window | 60 seconds |
| Evidence Photos | 10 photos on rejection |
| JWT Token Expiry | 30 days |
| OTP Expiry | 5 minutes |
| Supported Android | API 21+ (Android 5.0+) |

---

## 👨‍💻 Author

**Shaik Hafreed**
- GitHub: [@ShaikHafreed](https://github.com/ShaikHafreed)
- Project: AI Smart Cupboard — B.Tech Minor Project 2026

---

## 📄 License

This project is built for educational purposes as part of B.Tech Minor Project.

---

*Built with ❤️ using ESP32, Python, Flutter and DeepFace AI*

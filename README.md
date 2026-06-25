# 🔐 AI-Powered Smart Reflective Security Locker

> Final Year IoT + AI Engineering Project  
> ESP32-CAM · DeepFace · Flutter · Flask · Firebase FCM

---

## 📱 Demo Screenshots

| Home — Secure | Home — Alert | Access Logs | Profile |
|---|---|---|---|
| Green pulsing lock | Red intruder alert | Filtered log cards | PIN login + stats |

---

## 🧠 How It Works

```
Door Opens
    ↓
ESP32-CAM captures photo
    ↓
Photo sent to Flask backend (Wi-Fi)
    ↓
DeepFace runs ArcFace + MTCNN facial recognition
    ↓
Owner?  ──YES──▶  "Access Granted" + FCM notification
  │
  NO
  ↓
"Intruder Detected" + FCM notification
  ↓
Owner taps Approve / Reject on Flutter app
  ↓
Reject? ──YES──▶  Buzzer ON + 10 evidence photos captured
```

---

## ⚙️ Tech Stack

| Layer | Technology |
|---|---|
| Hardware | ESP32-CAM (AI Thinker) |
| Face Recognition | DeepFace — ArcFace model + MTCNN detector |
| Backend | Python · Flask · SQLite |
| Mobile App | Flutter (Dart) · Firebase FCM |
| Notifications | Firebase Cloud Messaging (FCM) + Telegram |
| Auth | SharedPreferences PIN login |

---

## 🗂️ Project Structure

```
AI_SMART_LOCKER/
├── backend/
│   ├── app.py                  # Flask server — all API routes
│   ├── owner_faces/            # Reference photos for recognition
│   └── uploads/                # Visitor captures (gitignored)
├── mobile_app_new/
│   └── lib/
│       ├── main.dart
│       └── screens/
│           ├── dashboard_screen.dart   # Live security hub
│           ├── logs_screen.dart        # Access logs + filters
│           ├── profile_screen.dart     # PIN login + stats
│           ├── gallery_screen.dart     # Photo gallery
│           └── approval_request_screen.dart  # Approve/Reject
└── ai_recognition/             # Standalone face recognition tests
```

---

## 🚀 How to Run

### Backend
```bash
cd backend
venv\Scripts\Activate.ps1      # Windows
python app.py
# → Running on http://192.168.31.172:5000
```

### Flutter App
```bash
cd mobile_app_new
flutter pub get
flutter run
# Phone must be on same WiFi as backend
```

### ESP32
- Open `esp32_cam.ino` in Arduino IDE
- Set WiFi credentials and Flask server IP
- Upload to ESP32-CAM board

---

## 🔌 Hardware Setup

| Pin | Component |
|---|---|
| GPIO13 | Reed switch (door sensor) |
| GPIO14 | Mute button |
| GPIO15 | Buzzer (active-LOW) |
| 5V | Buzzer VCC |
| GND | All components shared ground |

---

## 📡 Flask API Routes

| Method | Route | Description |
|---|---|---|
| POST | `/verify` | Face recognition — returns Owner/Intruder |
| GET | `/pending_access` | Current approval status |
| GET | `/approve` | Owner approves visitor |
| GET | `/reject` | Owner rejects — triggers buzzer + evidence |
| POST | `/evidence` | ESP32 uploads evidence photo |
| GET | `/status` | Locker status + log counts |
| GET | `/logs` | All visitor logs from SQLite |
| GET | `/images` | Image list newest-first |
| POST | `/register_token` | Register FCM token |

---

## ✅ Features

- 🎯 **Face Recognition** — ArcFace + MTCNN, similarity ≥ 50% threshold
- 🔔 **Push Notifications** — FCM alerts on every door event
- ✅ **Approve / Reject** — Owner controls access from anywhere
- 📸 **Evidence Capture** — 10 photos taken automatically on rejection
- 🔊 **Buzzer Alert** — Active on rejection, mutable via button
- 📊 **Live Dashboard** — Animated lock status, real-time stats
- 📋 **Access Logs** — Filterable by Owner/Intruder/Approved/Rejected
- 🔐 **PIN Login** — 4-digit secure profile screen
- 🖼️ **Photo Gallery** — All captures sorted newest-first

---

## 👨‍💻 Developer

**Shaik Hafreed**  
Final Year Engineering Student  
GitHub: [@ShaikHafreed](https://github.com/ShaikHafreed)

---

> ⚠️ `firebase_key.json`, `uploads/`, `locker.db`, and `venv/` are excluded from this repo for security and size reasons.
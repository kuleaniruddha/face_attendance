# 📍 FaceNet AI Attendance & Geofencing System

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![TensorFlow Lite](https://img.shields.io/badge/TensorFlow%20Lite-FaceNet%20192d-FF6F00?logo=tensorflow&logoColor=white)](https://www.tensorflow.org/lite)
[![Google ML Kit](https://img.shields.io/badge/Google%20ML%20Kit-Face%20Detection-4285F4?logo=google&logoColor=white)](https://developers.google.com/ml-kit)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows-brightgreen)](#)

A smart, enterprise-grade mobile attendance tracking application powered by **on-device facial recognition (MobileFaceNet TFLite)**, **real-time geofencing (GPS)**, **biometric security**, and a **cloud-backed Admin Dashboard (Firebase Firestore & Auth)**.

Designed for organizations, institutes, and enterprises (e.g., **Xavier Institute of Engineering (XIE)** & **Vasundhara Bhavan (ONGC)**) to eliminate proxy attendance and automate daily movement logging.

---

## 🌟 Key Highlights

- 📸 **On-Device AI Face Verification**: Uses Google ML Kit for face bounding-box detection and MobileFaceNet TFLite to extract 192-dimensional vector embeddings with Cosine Similarity verification.
- 📍 **Dual Geofencing & GPS Enforcement**: Attendance can only be marked if the employee is physically located within the office/campus perimeter (e.g., 50m to 5 km customizable radius).
- 🔄 **Automated Background Tracking**: Background service monitors IN/OUT movements across the office boundary throughout the day.
- 🛡️ **Role-Based Access**:
  - **Employee / Student**: View attendance history, calendar, mark daily IN/OUT with face scan, apply for leaves, biometric quick login.
  - **Administrator**: Approve signup requests, manage users, set office geofence coordinates, inspect real-time movement logs, and export reports to CSV/Excel.
- 🔒 **Biometric Login**: Support for fingerprint and face unlock via `local_auth`.
- 🔐 **Hidden Admin Access**: Secret 5-tap gesture on the home screen logo reveals the Administrator Portal.

---

## 🏗️ Architecture & Workflow

```
┌───────────────────────────────────────────────────────────┐
│                      Employee Mobile App                   │
└─────────────────────────────┬─────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
    [ 1. Geofence Check ]           [ 2. Face Recognition ]
    • Device GPS Position           • Google ML Kit Detection
    • Firestore Geofence Radius     • MobileFaceNet (192-d Vector)
    • Haversine Distance Check      • Cosine Similarity (Threshold: 0.55)
              │                               │
              └───────────────┬───────────────┘
                              │ (Both Validated)
                              ▼
┌───────────────────────────────────────────────────────────┐
│              Firebase Cloud Infrastructure                │
├─────────────────────────────┬─────────────────────────────┤
│ • Firebase Auth             │ Secure JWT-based auth        │
│ • Cloud Firestore           │ Attendance, users, settings │
│ • Cloud Functions           │ Approval email notifications │
└─────────────────────────────┴─────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│                   Administrator Portal                    │
│   Approve Users | Geofence Control | CSV Export | Logs    │
└───────────────────────────────────────────────────────────┘
```

---

## 📱 Features Breakdown

### 👤 User / Employee Portal
- **Self-Service Registration**: Submit an access request with employee ID, department, and email.
- **Biometric & Saved Login**: Remember Me and native Fingerprint/Face biometric login.
- **Face Registration**: Capture multiple sample images to train on-device embeddings.
- **Mark Attendance**:
  - 1-Tap Location Verification (checks device GPS against office center).
  - Live camera face verification with single-face validation.
  - Automatically records timestamp and location coordinates.
- **Attendance Timeline & Calendar**: View monthly summaries, daily attendance status, total hours worked, and detailed IN/OUT timestamps.

### 🛡️ Administrator Portal
- **Secret Access**: Tap the logo on the Welcome page **5 times** to show the "ADMIN LOGIN" button.
- **Office Location Settings**:
  - 📍 **Use Current GPS Location**: Auto-fill coordinates directly from device GPS.
  - ⚡ **Location Presets**: One-tap presets for Vasundhara Bhavan (ONGC) and Xavier Institute of Engineering (XIE).
  - 📏 **Allowed Radius**: Quick presets (500m, 1km, 2km, 5km, 10km) or custom meters.
  - 🔄 **Instant Synchronization**: Automatically syncs across Firestore collections (`settings/attendance` and `office_locations`).
- **User Management**: View all employees, search by ID/name, enable/disable access, or delete records.
- **Signup Approvals**: Review pending signup requests, approve employees, and trigger automated welcome/login emails.
- **Attendance Logs & Export**:
  - Filter logs by date and department.
  - Export attendance data directly to **CSV / Excel** for payroll and HR systems.

---

## 📂 Project Structure

```
mod_attend/
├── assets/
│   ├── images/              # Logos and UI assets
│   └── models/
│       └── mobile_facenet.tflite  # Pre-trained MobileFaceNet model
├── functions/               # Firebase Cloud Functions (Email triggers)
│   ├── index.js
│   └── package.json
├── lib/
│   ├── admin/               # Admin Portal
│   │   ├── admin_dashboard.dart
│   │   ├── admin_login.dart
│   │   ├── attendance_export.dart
│   │   ├── attendance_records.dart
│   │   ├── manage_users.dart
│   │   ├── signup_requests.dart
│   │   ├── update_location.dart       # Geofence & GPS configuration
│   │   └── user_detail.dart
│   ├── auth/                # Authentication
│   │   ├── login.dart
│   │   └── signin_request.dart
│   ├── ml/                  # Machine Learning Engine
│   │   ├── face_detector.dart         # Google ML Kit Face Detection
│   │   └── facenet_service.dart       # TFLite Embeddings & Cosine Similarity
│   ├── services/            # Core Services
│   │   ├── auth_service.dart
│   │   ├── background_service.dart    # Continuous background tracking
│   │   ├── database_service.dart      # Firestore attendance operations
│   │   ├── email_service.dart
│   │   └── location_service.dart      # Geofencing & GPS calculations
│   ├── user/                # Employee Dashboard
│   │   ├── attendance_day_details.dart
│   │   ├── mark_attendance.dart       # GPS Check + Face Verification
│   │   ├── register_face.dart
│   │   └── user_dashboard.dart
│   ├── app_config.dart      # Default coordinates, thresholds & metadata
│   ├── firebase_options.dart# FlutterFire generated config
│   ├── main.dart            # App entry point & routing
│   └── splash_screen.dart   # Animated splash with non-blocking GPS init
├── android/                 # Android native config & build files
└── pubspec.yaml             # Flutter dependencies
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.19+ recommended)
- [Android Studio](https://developer.android.com/studio) or VS Code with Flutter extension
- An active [Firebase Project](https://console.firebase.google.com/) with:
  - **Firebase Authentication** (Email/Password enabled)
  - **Cloud Firestore**
  - **Firebase Storage**
- A physical Android/iOS device (camera & GPS required for full features)

### 1. Clone the Repository
```bash
git clone https://github.com/kuleaniruddha/face_attendance.git
cd face_attendance
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Firebase
- Ensure your `google-services.json` is placed in `android/app/google-services.json`.
- If reconfiguring for your own Firebase project:
```bash
flutterfire configure
```

### 4. Run the Application
Connect your physical device with USB debugging enabled, then run:
```bash
flutter run
```

---

## ⚙️ Configuration & Secrets

### Default Admin Credentials
| Field | Value |
|---|---|
| **Admin Email** | `admin@faceattendance.com` |
| **Admin Password** | `admin123` |
| **Activation** | Tap the center logo on the Welcome screen **5 times** |

### Office Location Settings (`app_config.dart` & Firestore)
```dart
static const double officeLatitude = 19.04525;
static const double officeLongitude = 72.84168;
static const double officeRadiusMeters = 5000.0; // 5 km radius
static const double faceMatchThreshold = 0.55;   // Cosine similarity threshold
```

---

## 🧪 Machine Learning Details

- **Face Detection**: Google ML Kit detects facial contours, orientation, and bounds.
- **Model**: MobileFaceNet quantized TFLite (`112x112x3` input shape).
- **Embedding Output**: 192-dimensional floating point vector.
- **Matching Metric**: **Cosine Similarity**
  $$\text{Similarity} = \frac{\mathbf{A} \cdot \mathbf{B}}{\|\mathbf{A}\| \|\mathbf{B}\|}$$
  - A threshold of **`≥ 0.55`** indicates a successful match with high confidence.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!
1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<p align="center">
  Developed for <b>Xavier Institute of Engineering</b> &bull; Powered by <b>Flutter & TensorFlow</b>
</p>

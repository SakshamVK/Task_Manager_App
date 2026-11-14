Task Manager

A cross-platform task management application built with Flutter, designed to help gig workers organise their work, track deadlines, and manage tasks reliably—even with an intermittent internet connection.

Built as part of a Flutter Developer Internship assignment.

Features

Authentication

- Email and password registration and login.
- Google Sign-In.
- Password reset through email.
- Persistent authentication sessions.
- User-specific task data.

Task Management

- Create, view, edit, and delete tasks.
- Set task titles, descriptions, due dates, and priorities.
- Organise tasks by category:
  - Client Work
  - Delivery
  - Personal
  - Other
- Mark tasks as completed or pending.
- Search and filter tasks by category, status, and priority.

Offline-First Architecture

- Local persistence using SQLite.
- Tasks remain accessible without an internet connection.
- Local changes are queued for cloud synchronisation.
- Firestore synchronisation restores tasks when signing in on another device.
- Connectivity status is displayed through an offline indicator.

User Experience

- Onboarding flow for new users.
- Custom application theme and reusable UI components.
- Native splash screen for Android and iOS.
- Form validation and authentication error handling.

Tech Stack

Technology| Purpose
Flutter & Dart| Cross-platform application
Firebase Authentication| User authentication
Cloud Firestore| Cloud database and synchronisation
SQLite ("sqflite")| Local persistence
Riverpod| State management
GoRouter| Declarative navigation
SharedPreferences| Onboarding state persistence
Google Sign-In| Google authentication
Internet Connection Checker Plus| Connectivity monitoring

Architecture

The project follows a layer-based architecture to separate application responsibilities.

lib/
├── constants/       # Theme, colours, dimensions, strings
├── models/          # Data models
├── providers/       # Riverpod state providers
├── screens/         # Application screens
├── services/        # Authentication, database and sync logic
├── widgets/         # Reusable UI components
└── main.dart        # Application entry point

Data Flow

        Flutter UI
             |
        Riverpod
             |
        Task Service
          /     \
      SQLite   Firestore
       Local     Cloud
       Store     Store

SQLite provides local persistence, while Cloud Firestore provides remote storage and cross-device synchronisation.

Each user's tasks are stored under their own Firestore collection:

users/{userId}/tasks/{taskId}

Firestore security rules enforce user-level data ownership.

Getting Started

Prerequisites

- Flutter SDK
- Dart SDK
- Android Studio or VS Code
- Firebase project
- Xcode for iOS development (macOS only)

1. Clone the repository

git clone https://github.com/SakshamVK/Task_Manager_App.git

cd Task_Manager_App

2. Install dependencies

flutter pub get

3. Configure Firebase

Create a Firebase project and register your Android and iOS applications.

Enable the following Firebase Authentication providers:

- Email/Password
- Google

Create a Cloud Firestore database.

Configure FlutterFire:

dart pub global activate flutterfire_cli
flutterfire configure

Ensure the generated "firebase_options.dart" is available under "lib/".

Add the platform-specific Firebase configuration files:

- Android: "android/app/google-services.json"
- iOS: "ios/Runner/GoogleService-Info.plist"

Configure Google Sign-In OAuth credentials and the appropriate platform URL scheme.

Deploy the Firestore security rules for user-owned task and profile documents.

4. Generate the native splash screen

dart run flutter_native_splash:create --path=flutter_native_splash.yaml

5. Run the application

flutter run

Build

Android APK

flutter build apk --release

Android App Bundle

flutter build appbundle --release

iOS

flutter build ios --release

iOS builds require macOS and Xcode.

Testing and Code Quality

Format the project:

dart format .

Run static analysis:

flutter analyze

Run tests:

flutter test

Screenshots

Application screenshots can be added here.

Suggested screenshots:

- Onboarding
- Login and registration
- Dashboard
- Task creation and editing
- Offline mode

Security

- Firebase Authentication manages user identity.
- Firestore rules restrict access to each user's own data.
- Authentication credentials are not stored directly in the application database.
- Private signing credentials and service-account keys should never be committed to source control.

Author

Saksham Khare

GitHub: "@SakshamVK" (https://github.com/SakshamVK)

---

Developed with Flutter.
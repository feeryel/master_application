# 🌱 Ecominds — Mobile Application

A Flutter-based mobile application designed to connect **students, universities, and sponsors** through volunteering and community initiatives.

Ecominds provides a digital ecosystem where universities can create volunteering activities, students can participate and earn recognition through a points-based system, and sponsors can support initiatives through financial or material contributions.

---

## 📱 About Ecominds

**Ecominds** is a multi-actor volunteering platform built around three main stakeholders:

### 🎓 Universities

Universities can:

* Create volunteering activities
* Publish and manage community initiatives
* Define activity information and requirements
* Manage student participation
* Monitor volunteering activities

### 👩‍🎓 Students

Students can:

* Discover available volunteering opportunities
* Browse activity details
* Participate in volunteering activities
* Track their participation
* Earn points through completed activities
* Progress through different engagement levels
* Receive certificates and badges based on accumulated points

### 🤝 Sponsors

Sponsors can support volunteering initiatives by providing:

* 💰 Financial contributions
* 📦 Material resources
* 🎁 Resources needed for specific activities

This creates a complete ecosystem connecting **students, universities, and organizations** around social and community engagement.

---

## ✨ Key Features

### 🔐 Authentication

* Secure user authentication
* Firebase Authentication
* User-specific access and experience
* Role-oriented application flows

### 🔎 Discover Volunteering Activities

Students can:

* Browse available volunteering opportunities
* Explore activity details
* Discover initiatives created by universities
* View relevant information before participating

### 🙋‍♀️ Participation Management

Students can:

* Join volunteering activities
* Track their participation
* Follow their volunteering journey
* Earn points based on their involvement

### 🏆 Points & Gamification

Ecominds includes a **points-based engagement system** designed to encourage students to participate in community initiatives.

```text
Participate in activities
          ↓
      Earn points
          ↓
   Reach thresholds
          ↓
   Unlock new levels
          ↓
 Receive badges & certificates
```

The accumulated points determine the student's engagement level and allow them to obtain corresponding **badges and certificates**.

### 🏅 Badges & Certificates

Students can receive recognition based on their volunteering progress.

The system allows users to:

* Track their earned points
* Reach predefined thresholds
* Unlock achievement levels
* Obtain badges
* Generate certificates
* Keep a record of their volunteering achievements

### 🔔 Notifications

The application supports notifications to keep users informed about relevant activities and updates.

Technologies include:

* Firebase Cloud Messaging
* Flutter Local Notifications

### 📄 Certificate Generation

Certificates can be generated and handled directly through the application.

The project uses Flutter PDF and printing capabilities to support:

* PDF generation
* Certificate creation
* Document preview
* Printing/sharing workflows

### ☁️ Firebase Integration

The application uses Firebase as a core part of its backend infrastructure.

Implemented Firebase services include:

* **Firebase Authentication**
* **Cloud Firestore**
* **Firebase Cloud Messaging**

---

## 🏗️ Application Architecture

```text
                    ECOMINDS
                       │
       ┌───────────────┼────────────────┐
       │               │                │
       ▼               ▼                ▼
   Students       Universities       Sponsors
       │               │                │
       └───────────────┼────────────────┘
                       │
                       ▼
                 Flutter App
                       │
              ┌────────┴────────┐
              │                 │
              ▼                 ▼
        Firebase Auth      Cloud Firestore
              │                 │
              └────────┬────────┘
                       │
                       ▼
              Firebase Messaging
                       │
                       ▼
                Notifications
```

---

## 🛠️ Tech Stack

### Mobile Development

* **Flutter**
* **Dart**
* Material Design
* Responsive UI

### Backend & Cloud Services

* **Firebase Authentication**
* **Cloud Firestore**
* **Firebase Cloud Messaging**

### Notifications

* **Firebase Messaging**
* **Flutter Local Notifications**

### Documents

* **PDF**
* **Printing**

### UI & Experience

* **Flutter SVG**
* **Flutter Animate**
* **Intl**

---

## 📦 Dependencies

The application currently uses several Flutter packages, including:

| Package                       | Purpose                             |
| ----------------------------- | ----------------------------------- |
| `firebase_core`               | Firebase initialization             |
| `firebase_auth`               | User authentication                 |
| `cloud_firestore`             | Cloud database                      |
| `firebase_messaging`          | Push notifications                  |
| `flutter_local_notifications` | Local notifications                 |
| `pdf`                         | PDF generation                      |
| `printing`                    | PDF preview and printing            |
| `flutter_svg`                 | SVG assets                          |
| `flutter_animate`             | UI animations                       |
| `intl`                        | Internationalization and formatting |

These dependencies are defined in the project's `pubspec.yaml`.

---

## 📂 Project Structure

```text
master_application/
│
├── android/
├── ios/
├── web/
├── linux/
├── macos/
├── windows/
│
├── assets/
│   └── images/
│
├── lib/
│   └── ...
│
├── firebase.json
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

The project is configured with assets under `assets/images/` and Firebase configuration through `firebase.json`.

---

## ⚙️ Getting Started

### Prerequisites

Make sure you have installed:

* Flutter SDK
* Dart SDK
* Android Studio or another Flutter-compatible IDE
* Git

### Clone the repository

```bash
git clone https://github.com/feeryel/master_application.git

cd master_application
```

### Install dependencies

```bash
flutter pub get
```

### Run the application

For a connected device or emulator:

```bash
flutter run
```

For a specific platform:

```bash
flutter run -d chrome
```

or:

```bash
flutter run -d windows
```

---

## 🔥 Firebase Configuration

Ecominds relies on Firebase services for authentication, cloud data management, and notifications.

Before running the application, make sure the Firebase project is correctly configured for the target platform.

Required services include:

* Firebase Authentication
* Cloud Firestore
* Firebase Cloud Messaging

> Firebase configuration files and credentials should be handled securely and should not expose sensitive project secrets.

---

## 🔄 User Journey

### Student

```text
Login / Register
      ↓
Discover Activities
      ↓
View Activity Details
      ↓
Participate
      ↓
Complete Activity
      ↓
Earn Points
      ↓
Reach a Threshold
      ↓
Unlock Badge
      ↓
Receive Certificate
```

### University

```text
Login
  ↓
Create Volunteering Activity
  ↓
Publish Activity
  ↓
Manage Participants
  ↓
Follow Activity
  ↓
Validate Participation
```

### Sponsor

```text
Support an Initiative
        ↓
 ┌──────┴──────┐
 │             │
Money       Materials
 │             │
 └──────┬──────┘
        ↓
Volunteering Activity
```

---

## 🎯 Project Objectives

The main objectives of Ecominds are to:

* Encourage student volunteering
* Connect universities with students
* Facilitate the organization of community initiatives
* Give sponsors a way to support volunteering activities
* Motivate participation through gamification
* Reward students for their social engagement
* Digitize volunteering certificates and achievements
* Build a connected ecosystem around social impact

---

## 💡 Highlights

### Multi-Actor Platform

The application is designed around three different stakeholders:

**Students • Universities • Sponsors**

### Gamification

A points and achievement system encourages continued participation and creates a sense of progression.

### Digital Recognition

Students can build a record of their volunteering activities through **points, levels, badges, and certificates**.

### Cloud-Based Architecture

Firebase provides authentication, real-time cloud data management, and notification capabilities.

---

## 👩‍💻 Author

### Feryel Dadi

**Software Engineer — Software Engineering**
**Master's Degree in Mobile Development Engineering**

🌐 **Portfolio:**
https://portfolio-feryel.vercel.app

💼 **LinkedIn:**
https://www.linkedin.com/in/feeryel-dadi

🐙 **GitHub:**
https://github.com/feeryel

---

## 📄 License

This project was developed as part of an academic and professional software engineering project.

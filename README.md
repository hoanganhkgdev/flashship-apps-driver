# Flashship Driver App

Driver-facing mobile application for **Flashship**, a multi-service local delivery and on-demand services platform.

The app connects delivery drivers with Flashship's Laravel backend and Firebase realtime infrastructure to support driver availability, job notifications, order processing, location-aware workflows, and delivery operations.

## Product Overview

Flashship operates as a multi-role ecosystem with dedicated applications for customers, drivers, shops, and internal operations.

The Driver App is responsible for the driver side of the delivery workflow: maintaining driver state, receiving relevant updates and notifications, interacting with assigned jobs, and communicating operational status back to the Flashship platform.

## Tech Stack

- Flutter / Dart
- Riverpod — state management
- GoRouter — navigation
- Dio — REST API networking
- Firebase Core
- Firebase Authentication
- Firebase Cloud Messaging
- Firebase Realtime Database
- Geolocator — device location
- Flutter Local Notifications
- Shared Preferences
- Permission Handler
- AudioPlayers
- QR Flutter
- Image Picker

## Application Architecture

```text
Driver App (Flutter)
       │
       ├── REST API ─────────► Laravel Backend
       │                        ├── Authentication
       │                        ├── Driver
       │                        ├── Orders
       │                        ├── Pricing
       │                        └── Core Services
       │
       ├── Firebase Realtime ► Driver / operational state
       │
       ├── FCM ──────────────► Job & system notifications
       │
       └── GPS ──────────────► Location-aware workflows
```

## Key Engineering Areas

This project demonstrates mobile engineering across:

- REST API integration using Dio
- Riverpod-based application state
- Declarative routing with GoRouter
- Firebase Authentication
- Firebase Cloud Messaging
- Firebase Realtime Database integration
- GPS and runtime location permissions
- Driver online/offline operational state
- Location availability and reliability handling
- Local notifications and notification-related workflows
- Audio alerts for driver-facing events
- Persistent local application state
- Android and iOS development

## Driver Operations

The application is designed around real delivery operations where driver availability and location data must remain reliable. The driver workflow integrates application state, device location, realtime data, backend APIs, and push notifications rather than relying on GPS alone.

## Flashship Ecosystem

- **Customer App** — creates and manages service orders
- **Driver App** — receives and processes delivery jobs
- **Shop App** — supports partner-shop delivery operations
- **Laravel Backend** — APIs, authentication, orders, pricing, permissions, payments, and integrations
- **Admin Platform** — internal operations and management

## Getting Started

### Requirements

- Flutter SDK compatible with Dart `^3.6.0`
- Android Studio and/or Xcode
- Configured Firebase project
- Access to the Flashship backend API
- Location permissions configured for the target platform

### Install dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Analyze

```bash
flutter analyze
```

### Test

```bash
flutter test
```

## Configuration & Security

Production API credentials, Firebase configuration, signing credentials, and other sensitive environment-specific values should not be committed to source control.

## Project Context

Flashship Driver is an actively developed real-world driver application. Its architecture reflects practical delivery-platform concerns including realtime communication, location reliability, push notifications, and coordination with a Laravel-based backend.

---

**Flashship** — Local delivery and on-demand services platform.

# Data Flow Architecture

This document explains exactly how data moves through your Real-Time Messaging App, from the user's phone to the cloud and back.

## 1. High-Level Data Map

```mermaid
graph TD
    A[Flutter App] <-->|Auth| B[Firebase Auth]
    A <-->|Real-Time Streams| C[Cloud Firestore]
    A <-->|Push Tokens| D[Firebase Cloud Messaging]
    A <-->|Network Status| E[connectivity_plus]
```

---

## 2. Authentication & User Profile Flow
When a user registers or logs in, their identity is synced across the system.

```mermaid
sequenceDiagram
    participant User as RegisterScreen
    participant Auth as Firebase Auth
    participant DB as Firestore (users collection)

    User->>Auth: 1. Email/Password
    Auth-->>User: 2. UID Created
    User->>DB: 3. Save {uid, email, fcmToken}
    Note Right of DB: Triggers Real-Time User List
```

- **Key Logic**: Found in `lib/screens/register_screen.dart` and the `AuthWrapper` in `lib/main.dart`.
- **Impact**: Any change in the `users` collection instantly updates the Home Screen for every other user.

---

## 3. Real-Time Messaging Flow
Messaging is built on shared "Chat Rooms" in Firestore.

```mermaid
sequenceDiagram
    participant P1 as Phone A (Sender)
    participant FS as Firestore (chat_rooms)
    participant P2 as Phone B (Receiver)

    P1->>FS: 1. Add Message {text, senderId, timestamp}
    Note Over FS: Shared chat_room_id = sorted([uidA, uidB])
    FS-->>P1: 2. Stream Update (Blue Bubble)
    FS-->>P2: 3. Stream Update (Grey Bubble)
```

- **Room Logic**: `_getChatRoomId` in `lib/screens/chat_screen.dart` ensures both users land in the same private collection.
- **Auto-Sync**: Uses `StreamBuilder` so messages appear without an "Inbox Refresh."

---

## 4. Push Notification Data Flow
How the app pings you when it's closed.

```mermaid
flowchart LR
    A[User Profile] -->|Contains| B[FCM Token]
    B -->|Passed to| C[Firebase Server]
    C -->|Pings| D[Android System Tray]
    D -->|Opens| E[App Foreground]
```

- **Key Logic**: `FirebaseMessaging.instance.getToken()` in `main.dart` captures the unique phone ID.
- **Handling**: `_firebaseMessagingBackgroundHandler` handles messages when the app is completely closed.

---

## 5. Offline & Recovery Flow
The app is designed to work without Wi-Fi using local caching.

```mermaid
graph LR
    A[connectivity_plus] -->|No Internet| B[Offline Banner UI]
    C[Firestore Writes] -->|Offline| D[Local SQLite Cache]
    D -->|Re-connect| E[Auto-Sync to Cloud]
```

- **Persistence**: FlutterFirestore has "Offline Persistence" enabled by default on mobile.
- **UX**: The `OfflineBanner` widget in `lib/widgets/offline_banner.dart` warns the user while the caching logic manages the data.

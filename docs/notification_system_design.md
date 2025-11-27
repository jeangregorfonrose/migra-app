# Proximity-Based Notification System Design

## Overview

This document outlines the recommended architecture for implementing a proximity-based notification system that alerts users when immigration enforcement reports are submitted near their location.

---

## 🎯 System Requirements

- Notify users within a configurable radius (e.g., 5km) when a new report is submitted
- Privacy-preserving (no constant location tracking)
- Scalable to thousands of users
- Battery-efficient
- Works even when app is in background/closed

---

## 📊 Architecture Comparison

### ❌ Approach 1: Periodic Location Updates (NOT Recommended)

**How it works:**
- Store user locations in database
- Update every X minutes
- Query database for nearby users when report submitted

**Cons:**
- ⚠️ Privacy concerns - constant location tracking
- ⚠️ Battery drain - frequent GPS updates
- ⚠️ High server load - millions of location updates
- ⚠️ Stale data - location outdated between updates
- ⚠️ Database bloat - huge location history
- ⚠️ Doesn't scale well

### ✅ Approach 2: Grid-Based FCM Topics (RECOMMENDED)

**How it works:**
- Divide coverage area into geographic grid cells
- Users subscribe to FCM topics for nearby cells
- When report submitted, publish to relevant cell topics
- FCM distributes notifications to subscribed users

**Pros:**
- ✅ Privacy-friendly - only general area known
- ✅ No constant tracking
- ✅ Battery efficient
- ✅ Scalable - FCM handles distribution
- ✅ Works in background
- ✅ Real-time delivery

---

## 🗺️ Grid Cell Logic Explained

### Core Concept

The world is divided into a grid using latitude/longitude coordinates. Each cell gets a unique identifier.

### Grid Cell Calculation

```javascript
function getGridCell(lat, lng, precision = 2) {
  const cellLat = Math.floor(lat * precision) / precision;
  const cellLng = Math.floor(lng * precision) / precision;
  return `cell_${cellLat}_${cellLng}`;
}
```

**Example:**
- Location: Santo Domingo (18.4861°, -69.9312°)
- Precision: 2
- Calculation:
  - lat: floor(18.4861 × 2) / 2 = 18.0
  - lng: floor(-69.9312 × 2) / 2 = -70.0
- Result: `cell_18.0_-70.0`

### Cell Size by Precision

| Precision | Degrees | Approx Size | Use Case |
|-----------|---------|-------------|----------|
| 1 | 1.0° | ~111 km | Country-level |
| **2** | **0.5°** | **~55 km** | **City-level ✅** |
| 3 | 0.33° | ~37 km | District-level |
| 4 | 0.25° | ~28 km | Neighborhood |

**Recommended: Precision = 2**
- Good balance between coverage and specificity
- Each cell covers ~55km × 55km
- Covers typical city areas well

### Getting Nearby Cells

To receive notifications within a radius, subscribe to current cell + adjacent cells:

```javascript
function getNearbyCells(lat, lng, radius = 5) {
  const cells = [];
  const precision = 2;
  const offset = Math.ceil(radius / 50); // ~50km per 0.5 degree
  
  for (let latOffset = -offset; latOffset <= offset; latOffset++) {
    for (let lngOffset = -offset; lngOffset <= offset; lngOffset++) {
      const newLat = lat + (latOffset / precision);
      const newLng = lng + (lngOffset / precision);
      cells.push(getGridCell(newLat, newLng, precision));
    }
  }
  return cells;
}
```

**Visual Example (5km radius):**

```
        -70.5      -70.0      -69.5
      ┌──────────┬──────────┬──────────┐
18.5  │ cell_1   │ cell_2   │ cell_3   │
      ├──────────┼──────────┼──────────┤
18.0  │ cell_4   │ cell_5🔵 │ cell_6   │  ← Your cell
      ├──────────┼──────────┼──────────┤
17.5  │ cell_7   │ cell_8   │ cell_9   │
      └──────────┴──────────┴──────────┘

Subscribe to all 9 cells to receive notifications
within ~5km radius
```

---

## 💻 Implementation

### Backend (Express + MongoDB)

#### 1. Setup Firebase Admin SDK

```javascript
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
```

#### 2. Grid Cell Helper Functions

```javascript
// Convert lat/lng to grid cell ID
function getGridCell(lat, lng, precision = 2) {
  const cellLat = Math.floor(lat * precision) / precision;
  const cellLng = Math.floor(lng * precision) / precision;
  return `cell_${cellLat}_${cellLng}`;
}

// Get nearby cells within radius
function getNearbyCells(lat, lng, radius = 5) {
  const cells = [];
  const precision = 2;
  const offset = Math.ceil(radius / 50);
  
  for (let latOffset = -offset; latOffset <= offset; latOffset++) {
    for (let lngOffset = -offset; lngOffset <= offset; lngOffset++) {
      cells.push(getGridCell(
        lat + latOffset/precision,
        lng + lngOffset/precision,
        precision
      ));
    }
  }
  return cells;
}
```

#### 3. Report Submission Endpoint

```javascript
app.post('/api/reports', async (req, res) => {
  try {
    const { location, description } = req.body;
    
    // Save report to MongoDB
    const report = await Report.create({
      location,
      description,
      timestamp: new Date()
    });
    
    // Get cells within notification radius (5km)
    const nearbyCells = getNearbyCells(
      location.coordinates[1], // lat
      location.coordinates[0], // lng
      5 // radius in km
    );
    
    // Send notification to all nearby cells
    const notificationPromises = nearbyCells.map(cell =>
      admin.messaging().send({
        topic: cell,
        notification: {
          title: '⚠️ New Report Nearby',
          body: 'Immigration enforcement activity reported in your area',
        },
        data: {
          reportId: report._id.toString(),
          lat: location.coordinates[1].toString(),
          lng: location.coordinates[0].toString(),
          type: 'new_report'
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'reports'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              alert: {
                title: '⚠️ New Report Nearby',
                body: 'Immigration enforcement activity reported in your area'
              }
            }
          }
        }
      })
    );
    
    await Promise.all(notificationPromises);
    
    res.json({
      success: true,
      report,
      notifiedCells: nearbyCells.length
    });
    
  } catch (error) {
    console.error('Error creating report:', error);
    res.status(500).json({ error: 'Failed to create report' });
  }
});
```

### Frontend (Flutter)

#### 1. Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  firebase_messaging: ^14.7.0
  firebase_core: ^2.24.0
```

#### 2. Location Notification Service

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:math';

class LocationNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  Set<String> _subscribedTopics = {};
  String? _lastCell;
  
  // Initialize FCM
  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }
    
    // Get FCM token (optional - for direct messaging)
    String? token = await _fcm.getToken();
    print('FCM Token: $token');
  }
  
  // Subscribe to topics based on current location
  Future<void> updateLocationSubscriptions(double lat, double lng) async {
    final nearbyCells = _getNearbyCells(lat, lng, radius: 10); // 10km
    
    // Unsubscribe from old topics
    for (final topic in _subscribedTopics) {
      if (!nearbyCells.contains(topic)) {
        await _fcm.unsubscribeFromTopic(topic);
        print('Unsubscribed from: $topic');
      }
    }
    
    // Subscribe to new topics
    for (final cell in nearbyCells) {
      if (!_subscribedTopics.contains(cell)) {
        await _fcm.subscribeToTopic(cell);
        print('Subscribed to: $cell');
      }
    }
    
    _subscribedTopics = nearbyCells.toSet();
  }
  
  // Only update if moved to different cell
  Future<void> updateIfNeeded(double lat, double lng) async {
    final currentCell = _getGridCell(lat, lng, 2);
    
    if (currentCell != _lastCell) {
      await updateLocationSubscriptions(lat, lng);
      _lastCell = currentCell;
    }
  }
  
  // Grid cell calculation
  String _getGridCell(double lat, double lng, int precision) {
    final cellLat = (lat * precision).floor() / precision;
    final cellLng = (lng * precision).floor() / precision;
    return 'cell_${cellLat}_${cellLng}';
  }
  
  // Get nearby cells
  Set<String> _getNearbyCells(double lat, double lng, {required double radius}) {
    final cells = <String>{};
    const precision = 2;
    final offset = (radius / 50).ceil();
    
    for (int latOffset = -offset; latOffset <= offset; latOffset++) {
      for (int lngOffset = -offset; lngOffset <= offset; lngOffset++) {
        cells.add(_getGridCell(
          lat + latOffset / precision,
          lng + lngOffset / precision,
          precision,
        ));
      }
    }
    return cells;
  }
}
```

#### 3. Handle Notifications

```dart
// In main.dart or app initialization
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background message: ${message.messageId}');
  
  // Handle the notification
  if (message.data['type'] == 'new_report') {
    // Show local notification or update app state
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final LocationNotificationService _notificationService = 
      LocationNotificationService();
  
  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }
  
  Future<void> _setupNotifications() async {
    await _notificationService.initialize();
    
    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message in foreground!');
      print('Message data: ${message.data}');
      
      if (message.notification != null) {
        // Show in-app notification
        _showInAppNotification(message);
      }
    });
    
    // Handle notification tap (app opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tapped!');
      _handleNotificationTap(message);
    });
  }
  
  void _showInAppNotification(RemoteMessage message) {
    // Show snackbar or custom notification UI
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.notification?.body ?? 'New notification'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _handleNotificationTap(message),
        ),
      ),
    );
  }
  
  void _handleNotificationTap(RemoteMessage message) {
    // Navigate to report details
    final reportId = message.data['reportId'];
    final lat = double.parse(message.data['lat']);
    final lng = double.parse(message.data['lng']);
    
    // Navigate to map centered on report location
    Navigator.pushNamed(
      context,
      '/map',
      arguments: {'lat': lat, 'lng': lng, 'reportId': reportId},
    );
  }
}
```

#### 4. Update Subscriptions on Location Change

```dart
// In MapScreen or location tracking service
class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationNotificationService _notificationService = 
      LocationNotificationService();
  
  @override
  void initState() {
    super.initState();
    _updateNotificationSubscriptions();
  }
  
  Future<void> _updateNotificationSubscriptions() async {
    // Get user location
    final position = await getUserLocation();
    
    // Update FCM topic subscriptions
    await _notificationService.updateIfNeeded(
      position.latitude,
      position.longitude,
    );
  }
}
```

---

## 🔧 Configuration

### Notification Radius

Adjust the radius in both frontend and backend:

```javascript
// Backend - when sending notifications
const nearbyCells = getNearbyCells(lat, lng, 5); // 5km radius
```

```dart
// Frontend - when subscribing
final nearbyCells = _getNearbyCells(lat, lng, radius: 10); // 10km radius
```

**Recommendation:** Frontend radius should be larger than backend radius to ensure users receive all relevant notifications.

### Grid Precision

Adjust precision for different coverage areas:

```javascript
// Smaller cells (more precise, more topics)
const precision = 3; // ~37km cells

// Larger cells (less precise, fewer topics)
const precision = 1; // ~111km cells
```

---

## 📱 Platform-Specific Setup

### Android

1. Add `google-services.json` to `android/app/`
2. Update `android/app/build.gradle`:
```gradle
dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```

3. Create notification channel in `MainActivity.kt`:
```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
    val channel = NotificationChannel(
        "reports",
        "Report Notifications",
        NotificationManager.IMPORTANCE_HIGH
    )
    val manager = getSystemService(NotificationManager::class.java)
    manager.createNotificationChannel(channel)
}
```

### iOS

1. Add `GoogleService-Info.plist` to `ios/Runner/`
2. Enable Push Notifications capability in Xcode
3. Upload APNs certificate to Firebase Console

---

## 📊 Scalability Analysis

### For Dominican Republic

- **Area:** ~48,000 km²
- **With precision = 2:** ~16 cells total
- **User subscribes to:** ~9 cells (3×3 grid)
- **FCM topic limit:** 2,000 topics per device

**Conclusion:** Highly scalable - only need ~20 topics for entire country.

### Performance Metrics

- **Notification latency:** < 1 second (FCM)
- **Battery impact:** Minimal (no background location)
- **Server load:** Low (FCM handles distribution)
- **Database queries:** None (topic-based)

---

## 🔒 Privacy Considerations

1. **No exact location storage** - Only cell IDs are used
2. **No location history** - Subscriptions updated only when needed
3. **User control** - Can disable notifications anytime
4. **Anonymous** - No user identification in topics

---

## 🚀 Implementation Checklist

- [ ] Add Firebase to project (both iOS and Android)
- [ ] Install Firebase Admin SDK on backend
- [ ] Implement grid cell logic (backend + frontend)
- [ ] Create report submission endpoint with FCM
- [ ] Add LocationNotificationService to Flutter app
- [ ] Setup notification handlers (foreground, background, terminated)
- [ ] Test notification delivery
- [ ] Configure notification channels (Android)
- [ ] Setup APNs certificates (iOS)
- [ ] Add notification settings screen
- [ ] Test with multiple devices
- [ ] Monitor FCM quota and delivery rates

---

## 📚 Resources

- [Firebase Cloud Messaging Docs](https://firebase.google.com/docs/cloud-messaging)
- [FCM Topic Messaging](https://firebase.google.com/docs/cloud-messaging/android/topic-messaging)
- [Flutter Firebase Messaging Plugin](https://pub.dev/packages/firebase_messaging)
- [H3 Geospatial Indexing](https://h3geo.org/) (Alternative to simple grid)

---

## 🎯 Future Enhancements

1. **Notification preferences** - Let users set custom radius
2. **Quiet hours** - Don't send notifications at night
3. **Report categories** - Filter by type of activity
4. **Notification history** - Show past alerts
5. **Analytics** - Track notification delivery and engagement
6. **A/B testing** - Test different notification messages

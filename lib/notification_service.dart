import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;


class NotificationService {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final String _apiBaseUrl = 'http://192.168.1.14:8002/fcm';

  Future<void> initFCM() async {
    await _firebaseMessaging.requestPermission();

    final fcmToken = await _firebaseMessaging.getToken();
    print("FCM Token: $fcmToken");

    if (fcmToken != null) {
      await _registerFcmToken(fcmToken); // Register token with your backend
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Message opened from terminated state: ${message.notification?.title}");
      print("Message body: ${message.notification?.body}");
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground Message: ${message.notification?.title}");
      print("Foreground Message body: ${message.notification?.body}");
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _registerFcmToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/register_fcm_token?token=$token'),
        headers: {
          'accept': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        print('Successfully registered FCM token');
      } else {
        print('Failed to register FCM token: ${response.body}');
      }
    } catch (e) {
      print('Error registering FCM token: $e');
    }
  }
}

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background Message: ${message.notification?.title}");
  print("Background Message body: ${message.notification?.body}");
}
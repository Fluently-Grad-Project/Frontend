import 'package:cloud_firestore/cloud_firestore.dart';

Future<int?> getBackendUserIdFromFirebaseUid(String firebaseUid) async {
  print("📡 Fetching backend user_id for Firebase UID: $firebaseUid");

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUid)
        .get();

    if (!doc.exists) {
      print("❌ Document does NOT exist for UID $firebaseUid");
      return null;
    }

    final data = doc.data();
    print("📄 Fetched data: $data");

    if (data != null && data.containsKey('user_id')) {
      final backendId = data['user_id'];
      print("✅ Found user_id: $backendId");
      return backendId;
    } else {
      print("❌ 'user_id' field missing in document");
    }
  } catch (e) {
    print("❌ Exception while fetching backend user_id: $e");
  }

  // return null;
}

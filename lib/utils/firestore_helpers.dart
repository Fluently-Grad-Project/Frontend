import 'package:cloud_firestore/cloud_firestore.dart';

Future<int?> getBackendUserIdFromFirebaseUid(String firebaseUid) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUid)
        .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['user_id'] != null) {
        return data['user_id'] as int;
      }
    }
  } catch (e) {
    print("❌ Error fetching backend user_id for UID $firebaseUid: $e");
  }
  return null;
}

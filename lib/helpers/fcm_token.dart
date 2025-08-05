import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FcmTokenHelper {
  static Future<void> saveToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    final uid   = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token])
      }, SetOptions(merge: true));
    }
  }
}

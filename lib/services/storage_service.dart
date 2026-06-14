import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UploadTask uploadNoteImage({
    required File imageFile,
    required String noteId,
    required String fileName,
  }) {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final ref = _storage
        .ref()
        .child('users')
        .child(user.uid)
        .child('notes')
        .child(noteId)
        .child(fileName);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'userId': user.uid,
        'noteId': noteId,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    return ref.putFile(imageFile, metadata);
  }

  Future<void> deleteNoteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (_) {}
  }
}
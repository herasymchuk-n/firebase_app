import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _notesCollection {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    return _firestore.collection('users').doc(user.uid).collection('notes');
  }

  Future<String> createNote(String title, String content, String? imageUrl) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final docRef = await _notesCollection.add({
      'title': title,
      'content': content,
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'imageUrl': imageUrl,
    });
    return docRef.id;
  }

  Stream<List<Note>> getNotes() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _notesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Note.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> updateNote(String noteId, String title, String content, String? imageUrl) async {
    await _notesCollection.doc(noteId).update({
      'title': title,
      'content': content,
      'updatedAt': FieldValue.serverTimestamp(),
      'imageUrl': imageUrl,
    });
  }

  Future<void> deleteNote(String noteId) async {
    await _notesCollection.doc(noteId).delete();
  }
}
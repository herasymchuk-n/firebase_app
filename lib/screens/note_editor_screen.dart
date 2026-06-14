import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/note.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _picker = ImagePicker();

  File? _imageFile;
  String? _imageUrl;
  bool _isSaving = false;
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _imageUrl = widget.note!.imageUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final size = await file.length();

      if (size > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image is too large! Max size is 5MB. Current: ${(size / (1024 * 1024)).toStringAsFixed(2)}MB')),
          );
        }
        return;
      }

      setState(() {
        _imageFile = file;
        _imageUrl = null;
      });
    } catch (_) {}
  }

  Future<void> _deleteImage() async {
    if (_imageUrl != null) {
      setState(() => _isSaving = true);
      await _storageService.deleteNoteImage(_imageUrl!);
      if (widget.note != null) {
        await _firestoreService.updateNote(
          widget.note!.id,
          _titleController.text.trim(),
          _contentController.text.trim(),
          null,
        );
      }
    }
    setState(() {
      _imageFile = null;
      _imageUrl = null;
      _isSaving = false;
    });
  }

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    try {
      String? finalImageUrl = _imageUrl;
      String noteId = widget.note?.id ?? '';

      if (noteId.isEmpty && widget.note == null) {
        noteId = await _firestoreService.createNote(
          _titleController.text.trim(),
          _contentController.text.trim(),
          null,
        );
      }

      if (_imageFile != null) {
        final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final task = _storageService.uploadNoteImage(
          imageFile: _imageFile!,
          noteId: noteId,
          fileName: fileName,
        );

        task.snapshotEvents.listen((snapshot) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        });

        final snapshot = await task;
        finalImageUrl = await snapshot.ref.getDownloadURL();
      }

      await _firestoreService.updateNote(
        noteId,
        _titleController.text.trim(),
        _contentController.text.trim(),
        finalImageUrl,
      );

      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (e) {
      setState(() => _isSaving = false);
      String msg = 'Upload failed: ${e.message}';
      if (e.code == 'unauthorized') msg = 'No permission to upload';
      if (e.code == 'canceled') msg = 'Upload canceled';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: _isSaving ? null : _pickImage,
          ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _saveNote,
                ),
        ],
      ),
      body: Column(
        children: [
          if (_uploadProgress != null)
            LinearProgressIndicator(value: _uploadProgress),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_imageFile != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_imageFile!, fit: BoxFit.cover, height: 200, width: double.infinity),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white),
                              onPressed: _deleteImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_imageUrl != null && _imageUrl!.isNotEmpty)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _imageUrl!,
                            fit: BoxFit.cover,
                            height: 200,
                            width: double.infinity,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 200,
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Icon(Icons.error, size: 50),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white),
                              onPressed: _deleteImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: 'Start typing...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
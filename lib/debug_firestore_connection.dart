// Debug widget to test Firestore connection
// Add this to your main screen temporarily to test the connection

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class FirestoreDebugWidget extends StatefulWidget {
  const FirestoreDebugWidget({super.key});

  @override
  State<FirestoreDebugWidget> createState() => _FirestoreDebugWidgetState();
}

class _FirestoreDebugWidgetState extends State<FirestoreDebugWidget> {
  String _status = 'Not tested';
  List<Map<String, dynamic>> _documents = [];

  Future<void> _testFirestoreConnection() async {
    setState(() {
      _status = 'Testing...';
    });

    try {
      developer.log('🔍 Testing Firestore connection...');
      
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      developer.log('📱 Firebase App: ${firestore.app.name}');
      developer.log('🆔 Project ID: ${firestore.app.options.projectId}');
      
      // Test basic connection
      final QuerySnapshot snapshot = await firestore
          .collection('educational_content')
          .limit(10)
          .get();
      
      developer.log('📊 Found ${snapshot.docs.length} documents');
      
      final List<Map<String, dynamic>> docs = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        docs.add({
          'id': doc.id,
          'title': data['title'] ?? 'No title',
          'isPublished': data['isPublished'] ?? false,
          'category': data['category'] ?? 'No category',
          'hasContent': (data['content']?.toString().isNotEmpty ?? false),
          'contentLength': data['content']?.toString().length ?? 0,
          'allKeys': data.keys.toList(),
        });
        
        developer.log('📄 Doc ${doc.id}: ${data['title']} (${data.keys.length} fields)');
      }

      setState(() {
        _status = 'Connected! Found ${snapshot.docs.length} documents';
        _documents = docs;
      });
      
    } catch (error) {
      developer.log('❌ Firestore connection error: $error');
      setState(() {
        _status = 'Error: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Firestore Debug',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _testFirestoreConnection,
              child: const Text('Test Firestore Connection'),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Status: $_status',
              style: TextStyle(
                color: _status.contains('Error') ? Colors.red : Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            if (_documents.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Documents found:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              ...(_documents.map((doc) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${doc['id']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('Title: ${doc['title']}'),
                    Text('Published: ${doc['isPublished']}'),
                    Text('Category: ${doc['category']}'),
                    Text('Has Content: ${doc['hasContent']} (${doc['contentLength']} chars)'),
                    Text('Fields: ${doc['allKeys'].join(', ')}', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ))),
            ],
          ],
        ),
      ),
    );
  }
}
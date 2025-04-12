import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PSUToAirport extends StatefulWidget {
  // ... (existing code)
}

class _PSUToAirportState extends State<PSUToAirport> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _tripStatus = '';

  @override
  Widget build(BuildContext context) {
    return Container(); // Replace with your actual UI
  }

  Future<void> _updateTripStatus(String status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update trip status
        await _firestore.collection('psuToAirport').doc(widget.tripId).update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Save to history collection
        final tripData = await _firestore.collection('psuToAirport').doc(widget.tripId).get();
        if (tripData.exists) {
          final data = tripData.data() as Map<String, dynamic>;
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('history')
              .add({
            'pickup': data['pickup'] ?? '',
            'destination': data['destination'] ?? '',
            'status': status,
            'timestamp': FieldValue.serverTimestamp(),
            'tripId': widget.tripId,
          });
        }

        setState(() {
          _tripStatus = status;
        });
      }
    } catch (e) {
      print('Error updating trip status: $e');
    }
  }

  // ... (rest of the existing code)
} 
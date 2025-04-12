import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_firestore/firebase_firestore.dart';

class PSUToAirport extends StatefulWidget {
  // ... (existing code)
}

class _PSUToAirportState extends State<PSUToAirport> {
  // ... (existing code)

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
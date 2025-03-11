import 'package:firebase_database/firebase_database.dart';

class User {
  late String fullName;
  late String email;
  late String phone;
  late String id;

  User({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.id,
  });

  User.fromSnapshot(DataSnapshot snapshot) {
    id = snapshot.key ?? '';
    phone = (snapshot.value as Map)['phone'] ?? '';
    fullName = (snapshot.value as Map)['fullName'] ?? '';
    email = (snapshot.value as Map)['email'] ?? '';
  }
}
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
    Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
    phone = values['phone']?.toString() ?? '';
    fullName = values['fullname']?.toString() ?? '';
    email = values['email']?.toString() ?? '';
    
    print('Firebase에서 받은 데이터:');
    print('id: $id');
    print('phone: $phone');
    print('fullName: $fullName');
    print('email: $email');
  }
}
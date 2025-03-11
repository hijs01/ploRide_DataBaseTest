import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cabrider/datamodels/user.dart';

String mapKey = 'AIzaSyAknGQdA7yAS5SICTW8lOKilEN7FBpNS-U';

final CameraPosition googlePlex = CameraPosition(
  target: LatLng(37.42796133580664, -122.085749655962),
  zoom: 14.4746,
);

auth.User? currentFirebaseUser;
User? currentUserInfo;
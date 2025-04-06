class PsuLocation {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  PsuLocation({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class PsuLocationsData {
  static final List<PsuLocation> locations = [
    PsuLocation(
      name: 'Penn State University - HUB',
      address: 'Hetzel Union Building, University Park, PA 16802',
      latitude: 40.798431,
      longitude: -77.859728,
    ),
    PsuLocation(
      name: 'Penn State University - Pollock Commons',
      address: 'Pollock Commons, University Park, PA 16802',
      latitude: 40.800735,
      longitude: -77.865509,
    ),
    PsuLocation(
      name: 'Penn State University - East Halls',
      address: 'East Halls, University Park, PA 16802',
      latitude: 40.806178,
      longitude: -77.855179,
    ),
    PsuLocation(
      name: 'Penn State University - North Halls',
      address: 'North Halls, University Park, PA 16802',
      latitude: 40.806847,
      longitude: -77.865033,
    ),
    PsuLocation(
      name: 'Penn State University - West Halls',
      address: 'West Halls, University Park, PA 16802',
      latitude: 40.801917,
      longitude: -77.867226,
    ),
    PsuLocation(
      name: 'Penn State University - South Halls',
      address: 'South Halls, University Park, PA 16802',
      latitude: 40.793833,
      longitude: -77.863107,
    ),
    PsuLocation(
      name: 'Penn State University - IST Building',
      address:
          'Information Sciences & Technology Building, University Park, PA 16802',
      latitude: 40.794758,
      longitude: -77.867096,
    ),
    PsuLocation(
      name: 'Penn State University - Beaver Stadium',
      address: 'Beaver Stadium, University Park, PA 16802',
      latitude: 40.812106,
      longitude: -77.856178,
    ),
  ];
}

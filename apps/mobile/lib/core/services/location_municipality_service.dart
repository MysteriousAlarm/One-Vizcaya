import 'package:geolocator/geolocator.dart';

/// Approximate town-centre coordinates for the 15 municipalities of Nueva
/// Vizcaya (mirrors NV_MUNICIPALITY_COORDS in the Cloud Functions). Used to map
/// a device's GPS fix to the nearest municipality.
const Map<String, List<double>> kNvMunicipalityCoords = {
  'Alfonso Castañeda': [16.1833, 121.2167],
  'Ambaguio': [16.2167, 121.1167],
  'Aritao': [16.3, 121.0333],
  'Bagabag': [16.5833, 121.2333],
  'Bambang': [16.3833, 121.0667],
  'Bayombong': [16.4833, 121.15],
  'Diadi': [16.6, 121.3],
  'Dupax del Norte': [16.5, 121.1],
  'Dupax del Sur': [16.4667, 121.0833],
  'Kasibu': [16.3167, 121.2667],
  'Kayapa': [16.35, 120.9167],
  'Quezon': [16.2333, 121.0167],
  'Santa Fe': [16.1667, 120.9833],
  'Solano': [16.5167, 121.1833],
  'Villaverde': [16.65, 121.2667],
};

class LocationMunicipalityService {
  const LocationMunicipalityService._();

  /// Returns the Nueva Vizcaya municipality nearest to the device's current
  /// location, or null when location is unavailable/denied (caller keeps the
  /// user's manual selection in that case). Never throws.
  static Future<String?> detectNearest() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return null;

      String? nearest;
      double best = double.infinity;
      for (final entry in kNvMunicipalityCoords.entries) {
        final d = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          entry.value[0],
          entry.value[1],
        );
        if (d < best) {
          best = d;
          nearest = entry.key;
        }
      }
      return nearest;
    } catch (_) {
      return null;
    }
  }
}

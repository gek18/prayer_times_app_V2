import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final locationRepositoryProvider = Provider((ref) => LocationRepository());

class LocationData {
  final double latitude;
  final double longitude;
  final String city;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
  });
}

class LocationRepository {
  static const String _kCachedLat = 'cached_lat';
  static const String _kCachedLon = 'cached_lon';
  static const String _kCachedCity = 'cached_city';

  // ---------------------------------------------------------------------------
  // LOAD CACHED LOCATION
  // ---------------------------------------------------------------------------
  Future<LocationData?> loadCachedLocation() async {
    final prefs = await SharedPreferences.getInstance();

    final lat = prefs.getDouble(_kCachedLat);
    final lon = prefs.getDouble(_kCachedLon);
    final city = prefs.getString(_kCachedCity);

    if (lat != null && lon != null && city != null) {
      return LocationData(latitude: lat, longitude: lon, city: city);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // FETCH CURRENT LOCATION
  // ---------------------------------------------------------------------------
  Future<LocationData> fetchCurrentLocation({
    double? oldLat,
    double? oldLon,
  }) async {
    // 1) التأكد من أن خدمات الموقع مفعّلة
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      throw Exception("Location services are disabled.");
    }

    // 2) فحص الصلاحيات
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission permanently denied.");
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied.");
      }
    }

    // 3) الحصول على موقع سابق (قد يكون أسرع)
    Position? position = await Geolocator.getLastKnownPosition();

    // 4) الحصول على موقع محدث مع timeout لحماية التطبيق من التعليق
    try {
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Location timed out"),
      );
    } catch (_) {
      throw Exception("Failed to get location");
    }

    // 5) منطق الخلفية: تحديث فقط إذا تغير الموقع أكثر من 1 كم
    if (oldLat != null && oldLon != null) {
      final distance = Geolocator.distanceBetween(
        oldLat,
        oldLon,
        position.latitude,
        position.longitude,
      );

      if (distance < 1000) {
        final cached = await loadCachedLocation();
        return LocationData(
          latitude: oldLat,
          longitude: oldLon,
          city: cached?.city ?? "مدينة غير معروفة",
        );
      }
    }

    // 6) معرفة اسم المدينة عبر geocoding
    String cityName = "مدينة غير معروفة";

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        cityName =
            p.locality?.trim().isNotEmpty == true
                ? p.locality!
                : p.administrativeArea ?? "مدينة غير معروفة";
      }
    } catch (_) {
      cityName = "مدينة غير معروفة";
    }

    // 7) تخزين البيانات
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kCachedLat, position.latitude);
    await prefs.setDouble(_kCachedLon, position.longitude);
    await prefs.setString(_kCachedCity, cityName);

    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      city: cityName,
    );
  }
}

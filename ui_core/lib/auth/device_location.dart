import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// DeviceLocation captures the physical and locale context of the device
/// at the time of an action. Embedded into audit trails alongside user identity.
class DeviceLocation {
  const DeviceLocation({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.country,
    this.countryCode,
    this.administrativeArea,
    this.subAdministrativeArea,
    this.locality,
    this.subLocality,
    this.postalCode,
    this.timezone,
    this.language,
    this.locale,
    this.platformName,
    this.error,
  });

  // GPS coordinates
  final double? latitude;
  final double? longitude;
  final double? accuracy; // meters

  // Reverse-geocoded address components
  final String? country;
  final String? countryCode; // ISO 3166-1 alpha-2
  final String? administrativeArea; // state/province/county
  final String? subAdministrativeArea; // district
  final String? locality; // city/town
  final String? subLocality; // suburb/neighborhood
  final String? postalCode;

  // Device locale context
  final String? timezone;
  final String? language; // e.g. "en", "sw"
  final String? locale; // e.g. "en_KE", "sw_TZ"
  final String? platformName; // "web", "android", "ios", "linux", etc.

  // If location acquisition failed
  final String? error;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasAddress => locality != null || country != null;

  /// Human-readable location summary, e.g. "Nairobi, Kenya"
  String get displayLabel {
    final parts = <String>[];
    if (locality != null && locality!.isNotEmpty) parts.add(locality!);
    if (administrativeArea != null &&
        administrativeArea!.isNotEmpty &&
        administrativeArea != locality) {
      parts.add(administrativeArea!);
    }
    if (country != null && country!.isNotEmpty) parts.add(country!);
    if (parts.isEmpty && hasCoordinates) {
      return '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
    }
    if (parts.isEmpty) return error ?? 'Unknown location';
    return parts.join(', ');
  }

  /// Serializes to a map for embedding in audit trail properties.
  Map<String, String> toMap() {
    return {
      if (latitude != null) 'latitude': latitude!.toStringAsFixed(6),
      if (longitude != null) 'longitude': longitude!.toStringAsFixed(6),
      if (accuracy != null) 'accuracy_meters': accuracy!.toStringAsFixed(1),
      'country': ?country,
      'country_code': ?countryCode,
      'administrative_area': ?administrativeArea,
      'sub_administrative_area': ?subAdministrativeArea,
      'locality': ?locality,
      'sub_locality': ?subLocality,
      'postal_code': ?postalCode,
      'timezone': ?timezone,
      'language': ?language,
      'locale': ?locale,
      'platform': ?platformName,
      'location_error': ?error,
    };
  }
}

/// Resolves the current device location with reverse geocoding.
/// Handles permission requests and gracefully degrades if location is unavailable.
final deviceLocationProvider = FutureProvider<DeviceLocation>((ref) async {
  // Gather locale info (always available, no permissions needed)
  final platformLocale = ui.PlatformDispatcher.instance.locale;
  final language = platformLocale.languageCode;
  final locale = platformLocale.toLanguageTag();
  final timezone = DateTime.now().timeZoneName;
  final platformName = _getPlatformName();

  // Attempt to get GPS coordinates
  Position? position;
  String? locationError;

  try {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      locationError = 'Location services disabled';
    } else {
      // Check and request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        locationError = 'Location permission denied';
      } else {
        // Get position with timeout
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
      }
    }
  } catch (e) {
    locationError = 'Location unavailable: ${e.runtimeType}';
  }

  // Reverse geocode if we have coordinates
  String? country,
      countryCode,
      adminArea,
      subAdminArea,
      locality,
      subLocality,
      postalCode;

  if (position != null) {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        country = place.country;
        countryCode = place.isoCountryCode;
        adminArea = place.administrativeArea;
        subAdminArea = place.subAdministrativeArea;
        locality = place.locality;
        subLocality = place.subLocality;
        postalCode = place.postalCode;
      }
    } catch (e) {
      // Reverse geocoding failed — we still have coordinates
      debugPrint('Reverse geocoding failed: $e');
    }
  }

  return DeviceLocation(
    latitude: position?.latitude,
    longitude: position?.longitude,
    accuracy: position?.accuracy,
    country: country,
    countryCode: countryCode,
    administrativeArea: adminArea,
    subAdministrativeArea: subAdminArea,
    locality: locality,
    subLocality: subLocality,
    postalCode: postalCode,
    timezone: timezone,
    language: language,
    locale: locale,
    platformName: platformName,
    error: locationError,
  );
});

String _getPlatformName() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}

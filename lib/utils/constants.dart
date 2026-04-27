import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'NebengYuk';
  static const String appTagline = 'Sharing Kendaraan, hemat bersama!';

  // Matching Radius for pickup (in km)
  static const double matchingRadiusKm = 2.0;

  // Matching Radius for destination (in km) — flexible like pickup
  static const double matchingDestRadiusKm = 2.0;

  // Matching Time Window (in minutes) — ±90 min flexibility
  static const int matchingTimeWindowMinutes = 90;

  // Vehicle Types
  static const String vehicleCar = 'car';
  static const String vehicleMotorcycle = 'motorcycle';

  // Ride Status
  static const String statusScheduled = 'scheduled';
  static const String statusFullyBooked = 'fully_booked';
  static const String statusEnRoute = 'en_route';
  static const String statusPickedUp = 'picked_up';
  static const String statusCompleted = 'completed';

  // Booking Status
  static const String bookingPending = 'pending';
  static const String bookingAccepted = 'accepted';
  static const String bookingRejected = 'rejected';
  static const String bookingCompleted = 'completed';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String ridesCollection = 'rides';
  static const String bookingsCollection = 'bookings';
  static const String notificationsCollection = 'notifications';
  static const String driverLocationsCollection = 'driver_locations';

  // History Collections (completed/archived data)
  static const String rideHistoryCollection = 'ride_history';
  static const String bookingHistoryCollection = 'booking_history';
}

class AppColors {
  // Primary Palette - Deep Teal / Cyan
  static const Color primary = Color(0xFF00897B);
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color primaryDark = Color(0xFF00695C);

  // Secondary Palette - Warm Amber
  static const Color secondary = Color(0xFFFFB300);
  static const Color secondaryLight = Color(0xFFFFCA28);
  static const Color secondaryDark = Color(0xFFF57F17);

  // Background
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF2F6);

  // Text
  static const Color textPrimary = Color(0xFF1A2138);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Ride Status Colors
  static const Color scheduled = Color(0xFF3B82F6);
  static const Color fullyBooked = Color(0xFFF59E0B);
  static const Color enRoute = Color(0xFF8B5CF6);
  static const Color pickedUp = Color(0xFF10B981);
  static const Color completed = Color(0xFF6B7280);
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import 'active_booking.dart';

class RideDetailsScreen extends StatefulWidget {
  final RideModel ride;
  final double passengerOriginLat;
  final double passengerOriginLng;

  const RideDetailsScreen({
    super.key,
    required this.ride,
    required this.passengerOriginLat,
    required this.passengerOriginLng,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _notificationService = NotificationService();
  bool _isRequesting = false;

  late LatLng _pickupLocation;
  late String _pickupAddress;

  @override
  void initState() {
    super.initState();
    // Auto-fill pickup location from the passenger's search origin
    _pickupLocation = LatLng(widget.passengerOriginLat, widget.passengerOriginLng);
    _pickupAddress =
        '${widget.passengerOriginLat.toStringAsFixed(4)}, ${widget.passengerOriginLng.toStringAsFixed(4)}';
  }

  Future<void> _requestSeat() async {
    setState(() => _isRequesting = true);

    try {
      final user = _authService.currentUser;
      final userModel = await _authService.getUserModel(user!.uid);

      final booking = BookingModel(
        bookingId: '',
        rideId: widget.ride.rideId,
        passengerId: user.uid,
        passengerName: userModel?.displayName ?? user.displayName ?? 'Penumpang',
        passengerPhone: userModel?.phone ?? '',
        pickupLat: _pickupLocation.latitude,
        pickupLng: _pickupLocation.longitude,
        pickupAddress: _pickupAddress,
        status: AppConstants.bookingPending,
        createdAt: DateTime.now(),
      );

      final bookingId = await _firestoreService.createBooking(booking);

      // Send notification to driver
      await _notificationService.notifyBookingRequested(
        driverId: widget.ride.driverId,
        passengerName: userModel?.displayName ?? 'Penumpang',
        rideId: widget.ride.rideId,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveBookingScreen(
              bookingId: bookingId,
              rideId: widget.ride.rideId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final departureStr = DateFormat('EEEE, dd MMM yyyy • HH:mm').format(ride.departureTime);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Detail Tebengan')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map showing route + pickup
            SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    (ride.originLat + ride.destLat) / 2,
                    (ride.originLng + ride.destLng) / 2,
                  ),
                  initialZoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.nebengyuk',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(ride.originLat, ride.originLng),
                        width: 36, height: 36,
                        child: const Icon(Icons.circle, color: Colors.green, size: 16),
                      ),
                      Marker(
                        point: LatLng(ride.destLat, ride.destLng),
                        width: 36, height: 36,
                        child: const Icon(Icons.flag, color: Colors.red, size: 24),
                      ),
                      // Passenger pickup marker
                      Marker(
                        point: _pickupLocation,
                        width: 36, height: 36,
                        child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 28),
                      ),
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          LatLng(ride.originLat, ride.originLng),
                          LatLng(ride.destLat, ride.destLng),
                        ],
                        strokeWidth: 3,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver Info
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            ride.driverName.isNotEmpty ? ride.driverName[0].toUpperCase() : '?',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ride.driverName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  ride.vehicleType == 'car'
                                      ? Icons.directions_car
                                      : Icons.two_wheeler,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ride.vehicleType == 'car' ? 'Mobil' : 'Motor',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Departure Time
                  _InfoRow(
                    icon: Icons.access_time_rounded,
                    label: 'Waktu Keberangkatan',
                    value: departureStr,
                  ),
                  const SizedBox(height: 14),

                  // Route
                  _InfoRow(
                    icon: Icons.circle,
                    iconColor: AppColors.success,
                    iconSize: 10,
                    label: 'Dari',
                    value: ride.originAddress,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.flag_rounded,
                    iconColor: AppColors.error,
                    label: 'Ke',
                    value: ride.destAddress,
                  ),
                  const SizedBox(height: 14),

                  // Available seats
                  _InfoRow(
                    icon: Icons.event_seat_rounded,
                    iconColor: AppColors.success,
                    label: 'Kursi Tersedia',
                    value: '${ride.availableSeats} dari ${ride.totalSeats}',
                  ),
                  const SizedBox(height: 24),

                  // Pickup location (auto-filled from search)
                  Text(
                    'Titik Jemput Kamu',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_pin_circle_rounded,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _pickupAddress,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Auto',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Request Seat Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isRequesting ? null : _requestSeat,
                      icon: _isRequesting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.airline_seat_recline_normal),
                      label: Text(_isRequesting ? 'Memproses...' : 'Minta Kursi'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final double? iconSize;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    this.iconColor,
    this.iconSize,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: iconSize ?? 18, color: iconColor ?? AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class PickupNavigationScreen extends StatefulWidget {
  final String rideId;
  final RideModel ride;

  const PickupNavigationScreen({
    super.key,
    required this.rideId,
    required this.ride,
  });

  @override
  State<PickupNavigationScreen> createState() => _PickupNavigationScreenState();
}

class _PickupNavigationScreenState extends State<PickupNavigationScreen> {
  final _firestoreService = FirestoreService();
  final _notificationService = NotificationService();
  final _mapController = MapController();

  // Navigation phases
  // Phase 1: origin → pickup (driver heading to pick up passenger)
  // Phase 2: pickup → destination (driving to destination)
  int _phase = 0; // 0 = loading, 1 = going to pickup, 2 = going to destination
  bool _journeyComplete = false;

  // Mock GPS state
  Timer? _moveTimer;
  LatLng _currentPos = const LatLng(0, 0);
  LatLng _startPoint = const LatLng(0, 0);
  LatLng _endPoint = const LatLng(0, 0);
  double _progress = 0.0; // 0.0 to 1.0

  // Route points
  late LatLng _driverOrigin;
  late LatLng _driverDest;
  LatLng? _passengerPickup;

  // Booking reference
  BookingModel? _acceptedBooking;

  String _statusText = 'Memulai navigasi...';

  // Speed: number of steps to complete a leg
  static const int _totalSteps = 30; // ~30 seconds per leg at 1s interval

  @override
  void initState() {
    super.initState();
    _driverOrigin = LatLng(widget.ride.originLat, widget.ride.originLng);
    _driverDest = LatLng(widget.ride.destLat, widget.ride.destLng);
    _startPhase1();
  }

  Future<void> _startPhase1() async {
    // Update ride status to en-route
    await _firestoreService.updateRideStatus(
      widget.rideId,
      AppConstants.statusEnRoute,
    );

    // Get the first accepted booking to find passenger pickup point
    final bookings = await _firestoreService
        .getRideBookings(widget.rideId)
        .first;

    BookingModel? accepted;
    for (final booking in bookings) {
      if (booking.status == AppConstants.bookingAccepted) {
        accepted = booking;
        break;
      }
    }

    if (accepted != null) {
      _acceptedBooking = accepted;
      _passengerPickup = LatLng(accepted.pickupLat, accepted.pickupLng);

      // Notify passenger that driver is on the way
      final driverName = FirebaseAuth.instance.currentUser?.displayName ?? 'Driver';
      await _notificationService.notifyDriverEnRoute(
        passengerId: accepted.passengerId,
        driverName: driverName,
        rideId: widget.rideId,
      );
    } else {
      // No accepted booking — use driver destination as fallback
      _passengerPickup = _driverDest;
    }

    // Start Phase 1: driver origin → passenger pickup
    _startPoint = _driverOrigin;
    _endPoint = _passengerPickup!;
    _currentPos = _startPoint;
    _progress = 0.0;

    setState(() {
      _phase = 1;
      _statusText = 'Menuju titik jemput penumpang...';
    });

    _startMockMovement();
  }

  void _startMockMovement() {
    _moveTimer?.cancel();
    _progress = 0.0;

    _moveTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      _progress += 1.0 / _totalSteps;

      if (_progress >= 1.0) {
        _progress = 1.0;
        timer.cancel();
        _onLegComplete();
      }

      final lat = _startPoint.latitude +
          (_endPoint.latitude - _startPoint.latitude) * _progress;
      final lng = _startPoint.longitude +
          (_endPoint.longitude - _startPoint.longitude) * _progress;

      setState(() {
        _currentPos = LatLng(lat, lng);
      });

      // Update Firestore driver location for passenger's live map
      _firestoreService.updateDriverLocation(
        widget.rideId,
        FirebaseAuth.instance.currentUser?.uid ?? '',
        lat,
        lng,
      );

      // Move map camera to follow the dot
      try {
        _mapController.move(_currentPos, _mapController.camera.zoom);
      } catch (_) {}
    });
  }

  void _onLegComplete() {
    if (_phase == 1) {
      // Arrived at passenger pickup
      _notifyDriverArrived();
      setState(() {
        _statusText = 'Sampai di titik jemput! Menunggu penumpang naik...';
      });
    } else if (_phase == 2) {
      // Arrived at destination
      setState(() {
        _journeyComplete = true;
        _statusText = 'Sampai di tujuan! Perjalanan selesai.';
      });
    }
  }

  Future<void> _notifyDriverArrived() async {
    if (_acceptedBooking == null) return;
    final driverName = FirebaseAuth.instance.currentUser?.displayName ?? 'Driver';
    await _notificationService.notifyDriverArrived(
      passengerId: _acceptedBooking!.passengerId,
      driverName: driverName,
      rideId: widget.rideId,
    );
  }

  void _passengerPickedUp() async {
    // Update ride status
    await _firestoreService.updateRideStatus(
      widget.rideId,
      AppConstants.statusPickedUp,
    );

    // Start Phase 2: passenger pickup → destination
    _startPoint = _passengerPickup!;
    _endPoint = _driverDest;
    _currentPos = _startPoint;

    setState(() {
      _phase = 2;
      _statusText = 'Menuju tujuan...';
    });

    _startMockMovement();
  }

  Future<void> _completeJourney() async {
    // Stop timer
    _moveTimer?.cancel();

    // Remove driver location tracking
    await _firestoreService.removeDriverLocation(widget.rideId);

    // Update ride status
    await _firestoreService.updateRideStatus(
      widget.rideId,
      AppConstants.statusCompleted,
    );

    // Update all accepted bookings to completed
    final bookings = await _firestoreService
        .getRideBookings(widget.rideId)
        .first;

    for (final booking in bookings) {
      if (booking.status == AppConstants.bookingAccepted) {
        await _firestoreService.updateBookingStatus(
          booking.bookingId,
          AppConstants.bookingCompleted,
        );
        await _notificationService.notifyRideCompleted(
          userId: booking.passengerId,
          rideId: widget.rideId,
        );
      }
    }

    // Notify driver too
    await _notificationService.notifyRideCompleted(
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      rideId: widget.rideId,
    );

    // Archive: move ride + bookings to history collections
    await _firestoreService.archiveCompletedRide(widget.rideId);

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build markers
    final markers = <Marker>[
      // Driver origin (green)
      Marker(
        point: _driverOrigin,
        width: 40, height: 40,
        child: const Tooltip(
          message: 'Titik Asal',
          child: Icon(Icons.circle, color: Colors.green, size: 16),
        ),
      ),
      // Destination (red flag)
      Marker(
        point: _driverDest,
        width: 40, height: 40,
        child: const Tooltip(
          message: 'Tujuan',
          child: Icon(Icons.flag_rounded, color: Colors.red, size: 28),
        ),
      ),
    ];

    // Passenger pickup marker (blue)
    if (_passengerPickup != null) {
      markers.add(Marker(
        point: _passengerPickup!,
        width: 40, height: 40,
        child: const Tooltip(
          message: 'Titik Jemput',
          child: Icon(Icons.person_pin_circle, color: Colors.blue, size: 28),
        ),
      ));
    }

    // Moving driver dot (only during movement)
    if (_phase > 0) {
      markers.add(Marker(
        point: _currentPos,
        width: 48, height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_car,
            color: Colors.white,
            size: 22,
          ),
        ),
      ));
    }

    // Build polylines
    final polylines = <Polyline>[];

    if (_passengerPickup != null) {
      // Leg 1: origin → pickup (blue)
      polylines.add(Polyline(
        points: [_driverOrigin, _passengerPickup!],
        strokeWidth: 4,
        color: _phase == 1 ? Colors.blue : Colors.blue.withValues(alpha: 0.3),
      ));

      // Leg 2: pickup → destination (primary)
      polylines.add(Polyline(
        points: [_passengerPickup!, _driverDest],
        strokeWidth: 4,
        color: _phase == 2 ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
      ));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Navigasi Perjalanan'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _driverOrigin,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.nebengyuk',
                ),
                PolylineLayer(polylines: polylines),
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // Control Panel
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Phase indicator
                Row(
                  children: [
                    _PhaseChip(
                      label: 'Jemput',
                      isActive: _phase == 1,
                      isDone: _phase > 1,
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 16, color: AppColors.textLight),
                    const SizedBox(width: 8),
                    _PhaseChip(
                      label: 'Antar',
                      isActive: _phase == 2,
                      isDone: _journeyComplete,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Status text
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _journeyComplete
                            ? AppColors.success
                            : (_phase > 0 ? AppColors.enRoute : AppColors.textLight),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusText,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),

                // Progress bar
                if (_phase > 0 && !_journeyComplete) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: AppColors.textLight.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(
                        _phase == 1 ? Colors.blue : AppColors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // Action Buttons
                // Phase 1 complete: show "Penumpang Sudah Naik"
                if (_phase == 1 && _progress >= 1.0)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _passengerPickedUp,
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('Penumpang Sudah Naik'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                // Phase 2 complete: show "Selesaikan Perjalanan"
                if (_journeyComplete)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _completeJourney,
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('Selesaikan Perjalanan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDone;

  const _PhaseChip({
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData? icon;

    if (isDone) {
      bg = AppColors.success.withValues(alpha: 0.15);
      fg = AppColors.success;
      icon = Icons.check_circle;
    } else if (isActive) {
      bg = AppColors.enRoute.withValues(alpha: 0.15);
      fg = AppColors.enRoute;
      icon = Icons.directions_car;
    } else {
      bg = AppColors.textLight.withValues(alpha: 0.1);
      fg = AppColors.textLight;
      icon = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

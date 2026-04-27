import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';
import '../models/ride_model.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import 'driver_dashboard.dart';
import 'active_booking.dart';

class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Aktivitas'),
          automaticallyImplyLeading: false,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            indicatorColor: AppColors.secondary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Sebagai Penumpang'),
              Tab(text: 'Sebagai Driver'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PassengerHistory(),
            _DriverHistory(),
          ],
        ),
      ),
    );
  }
}

class _PassengerHistory extends StatelessWidget {
  final _firestore = FirestoreService();

  _PassengerHistory();

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Listen to active bookings
    return StreamBuilder<List<BookingModel>>(
      stream: _firestore.getPassengerBookings(userId),
      builder: (context, activeSnapshot) {
        // Also listen to archived bookings
        return StreamBuilder<List<BookingModel>>(
          stream: _firestore.getPassengerBookingHistory(userId),
          builder: (context, historySnapshot) {
            if (activeSnapshot.connectionState == ConnectionState.waiting &&
                historySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final active = activeSnapshot.data ?? [];
            final history = historySnapshot.data ?? [];

            // Merge and sort by createdAt descending
            final allBookings = [...active, ...history];
            allBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (allBookings.isEmpty) {
              return _buildEmptyState(
                icon: Icons.search_off_rounded,
                message: 'Belum ada riwayat nebeng',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allBookings.length,
              itemBuilder: (context, index) {
                final booking = allBookings[index];
                final isArchived = history.any((b) => b.bookingId == booking.bookingId);
                return GestureDetector(
                  onTap: isArchived
                      ? null // Archived bookings are read-only
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ActiveBookingScreen(
                                bookingId: booking.bookingId,
                                rideId: booking.rideId,
                              ),
                            ),
                          );
                        },
                  child: _BookingCard(booking: booking),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _DriverHistory extends StatelessWidget {
  final _firestore = FirestoreService();

  _DriverHistory();

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Listen to active rides
    return StreamBuilder<List<RideModel>>(
      stream: _firestore.getDriverRides(userId),
      builder: (context, activeSnapshot) {
        // Also listen to archived rides
        return StreamBuilder<List<RideModel>>(
          stream: _firestore.getDriverRideHistory(userId),
          builder: (context, historySnapshot) {
            if (activeSnapshot.connectionState == ConnectionState.waiting &&
                historySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final active = activeSnapshot.data ?? [];
            final history = historySnapshot.data ?? [];

            // Merge and sort by createdAt descending
            final allRides = [...active, ...history];
            allRides.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (allRides.isEmpty) {
              return _buildEmptyState(
                icon: Icons.directions_car_outlined,
                message: 'Belum ada riwayat beri tebengan',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allRides.length,
              itemBuilder: (context, index) {
                final ride = allRides[index];
                final isArchived = history.any((r) => r.rideId == ride.rideId);
                return GestureDetector(
                  onTap: isArchived
                      ? null // Archived rides are read-only
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DriverDashboardScreen(rideId: ride.rideId),
                            ),
                          );
                        },
                  child: _RideHistoryCard(ride: ride),
                );
              },
            );
          },
        );
      },
    );
  }
}

Widget _buildEmptyState({required IconData icon, required String message}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 72, color: AppColors.textLight),
        const SizedBox(height: 16),
        Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking #${booking.bookingId.substring(0, 8)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                _StatusBadge(status: booking.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    booking.pickupAddress.isNotEmpty ? booking.pickupAddress : 'Pickup location',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RideHistoryCard extends StatelessWidget {
  final RideModel ride;
  const _RideHistoryCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${ride.originAddress} → ${ride.destAddress}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: ride.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  ride.vehicleType == 'car' ? Icons.directions_car : Icons.two_wheeler,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${ride.availableSeats}/${ride.totalSeats} kursi tersedia',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    String label;

    switch (status) {
      case AppConstants.statusScheduled:
        bgColor = AppColors.scheduled;
        label = 'Terjadwal';
        break;
      case AppConstants.statusFullyBooked:
        bgColor = AppColors.fullyBooked;
        label = 'Penuh';
        break;
      case AppConstants.statusEnRoute:
        bgColor = AppColors.enRoute;
        label = 'Di Jalan';
        break;
      case AppConstants.statusPickedUp:
        bgColor = AppColors.pickedUp;
        label = 'Dijemput';
        break;
      case AppConstants.statusCompleted:
        bgColor = AppColors.completed;
        label = 'Selesai';
        break;
      case AppConstants.bookingPending:
        bgColor = AppColors.fullyBooked;
        label = 'Menunggu';
        break;
      case AppConstants.bookingAccepted:
        bgColor = AppColors.success;
        label = 'Diterima';
        break;
      case AppConstants.bookingRejected:
        bgColor = AppColors.error;
        label = 'Ditolak';
        break;
      default:
        bgColor = AppColors.textLight;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: bgColor,
        ),
      ),
    );
  }
}

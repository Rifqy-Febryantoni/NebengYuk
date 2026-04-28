import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import 'pickup_navigation.dart';

class DriverDashboardScreen extends StatelessWidget {
  final String rideId;

  const DriverDashboardScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final notificationService = NotificationService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard Driver'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: StreamBuilder<RideModel?>(
        stream: firestoreService.getRideStream(rideId),
        builder: (context, rideSnapshot) {
          if (rideSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final ride = rideSnapshot.data;
          if (ride == null) {
            return const Center(child: Text('Ride tidak ditemukan'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ride Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            ride.vehicleType == 'car'
                                ? Icons.directions_car
                                : Icons.two_wheeler,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            ride.vehicleType == 'car' ? 'Mobil' : 'Motor',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${ride.availableSeats}/${ride.totalSeats} kursi',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Route
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ride.originAddress,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.flag_rounded, size: 10, color: Colors.redAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ride.destAddress,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        DateFormat('EEEE, dd MMM yyyy • HH:mm').format(ride.departureTime),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Start Journey Button (only when there are accepted bookings)
                if (ride.status == AppConstants.statusScheduled ||
                    ride.status == AppConstants.statusFullyBooked)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PickupNavigationScreen(
                              rideId: rideId,
                              ride: ride,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Mulai Perjalanan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.enRoute,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Pending Booking Requests
                Text(
                  'Permintaan Nebeng',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                StreamBuilder<List<BookingModel>>(
                  stream: firestoreService.getRideBookings(rideId),
                  builder: (context, bookingSnapshot) {
                    if (bookingSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final bookings = bookingSnapshot.data ?? [];

                    if (bookings.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.inbox_rounded,
                              size: 48,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada permintaan nebeng',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: bookings.map((booking) {
                        return _BookingRequestCard(
                          booking: booking,
                          ride: ride,
                          onAccept: () async {
                            await firestoreService.updateBookingStatus(
                              rideId, 
                              booking.bookingId,
                              AppConstants.bookingAccepted,
                            );
                            await notificationService.notifyBookingAccepted(
                              passengerId: booking.passengerId,
                              driverName: ride.driverName,
                              rideId: rideId,
                            );
                          },
                          onReject: () async {
                            await firestoreService.rejectBooking(
                              booking.bookingId,
                              rideId,
                            );
                            await notificationService.notifyBookingRejected(
                              passengerId: booking.passengerId,
                              driverName: ride.driverName,
                              rideId: rideId,
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BookingRequestCard extends StatelessWidget {
  final BookingModel booking;
  final RideModel ride;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _BookingRequestCard({
    required this.booking,
    required this.ride,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = booking.status == AppConstants.bookingPending;
    Color statusColor;
    String statusLabel;

    switch (booking.status) {
      case AppConstants.bookingPending:
        statusColor = AppColors.warning;
        statusLabel = 'Menunggu';
        break;
      case AppConstants.bookingAccepted:
        statusColor = AppColors.success;
        statusLabel = 'Diterima';
        break;
      case AppConstants.bookingRejected:
        statusColor = AppColors.error;
        statusLabel = 'Ditolak';
        break;
      default:
        statusColor = AppColors.textLight;
        statusLabel = booking.status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    booking.passengerName.isNotEmpty
                        ? booking.passengerName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.passengerName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      booking.passengerPhone,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (booking.pickupAddress.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.pin_drop_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Dijemput di: ${booking.pickupAddress}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Terima'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

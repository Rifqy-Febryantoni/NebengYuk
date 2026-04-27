import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ride_model.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/geo_utils.dart';
import 'package:intl/intl.dart';
import 'ride_details.dart';

class RideResultsScreen extends StatelessWidget {
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final DateTime departureTime;
  final String vehiclePreference;

  const RideResultsScreen({
    super.key,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.departureTime,
    required this.vehiclePreference,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Hasil Pencarian')),
      body: StreamBuilder<List<RideModel>>(
        stream: firestoreService.getAvailableRides(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allRides = snapshot.data ?? [];

          debugPrint('🔍 Total rides from Firestore: ${allRides.length}');
          for (final r in allRides) {
            debugPrint('  📌 Ride by ${r.driverName}: origin(${r.originLat}, ${r.originLng}) dest(${r.destLat}, ${r.destLng}) time: ${r.departureTime} seats: ${r.availableSeats}');
          }
          debugPrint('🔍 Search params: origin($originLat, $originLng) dest($destLat, $destLng) time: $departureTime');

          // Filter rides by radius, time, and vehicle preference
          final matchingRides = allRides.where((ride) {
            // Check origin within 2km radius
            final originDist = GeoUtils.haversineDistance(
              originLat, originLng,
              ride.originLat, ride.originLng,
            );
            final originClose = originDist <= AppConstants.matchingRadiusKm;

            // Check destination within flexible radius (same as pickup)
            final destDist = GeoUtils.haversineDistance(
              destLat, destLng,
              ride.destLat, ride.destLng,
            );
            final destClose = destDist <= AppConstants.matchingDestRadiusKm;

            // Check departure time within flexible time window
            final timeDiff = ride.departureTime.difference(departureTime).inMinutes.abs();
            final timeClose = timeDiff <= AppConstants.matchingTimeWindowMinutes;

            // Check vehicle preference
            final vehicleMatch = vehiclePreference == 'both' ||
                ride.vehicleType == vehiclePreference;

            debugPrint('  ➡️ ${ride.driverName}: originDist=${originDist.toStringAsFixed(2)}km($originClose) destDist=${destDist.toStringAsFixed(2)}km($destClose) timeDiff=${timeDiff}min($timeClose) vehicle($vehicleMatch)');

            return originClose && destClose && timeClose && vehicleMatch;
          }).toList();

          debugPrint('✅ Matching rides: ${matchingRides.length}');

          if (matchingRides.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.search_off_rounded,
                      size: 80,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tidak ada tebengan ditemukan',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Coba perluas area pencarian atau ubah waktu keberangkatan.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: matchingRides.length,
            itemBuilder: (context, index) {
              final ride = matchingRides[index];
              return _RideResultCard(
                ride: ride,
                userOriginLat: originLat,
                userOriginLng: originLng,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RideDetailsScreen(
                        ride: ride,
                        passengerOriginLat: originLat,
                        passengerOriginLng: originLng,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _RideResultCard extends StatelessWidget {
  final RideModel ride;
  final double userOriginLat;
  final double userOriginLng;
  final VoidCallback onTap;

  const _RideResultCard({
    required this.ride,
    required this.userOriginLat,
    required this.userOriginLng,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final distanceKm = GeoUtils.haversineDistance(
      userOriginLat, userOriginLng,
      ride.originLat, ride.originLng,
    );
    final departureStr = DateFormat('dd MMM, HH:mm').format(ride.departureTime);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver info row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      ride.driverName.isNotEmpty ? ride.driverName[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.primary,
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
                        ride.driverName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        departureStr,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Vehicle icon + distance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      ride.vehicleType == 'car'
                          ? Icons.directions_car_rounded
                          : Icons.two_wheeler_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Route info
            Row(
              children: [
                const Icon(Icons.circle, size: 8, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.originAddress,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Container(
                width: 2,
                height: 16,
                color: AppColors.textLight.withValues(alpha: 0.3),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.circle, size: 8, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.destAddress,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom row: seats
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_seat, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        '${ride.availableSeats} kursi tersedia',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
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

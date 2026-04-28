import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/booking_model.dart';
import '../models/ride_model.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';

class ActiveBookingScreen extends StatelessWidget {
  final String bookingId;
  final String rideId;

  const ActiveBookingScreen({
    super.key,
    required this.bookingId,
    required this.rideId,
  });

  void _contactViaWhatsApp(BuildContext context, String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nomor telepon driver tidak tersedia'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Convert local phone (08xx) to international (+628xx)
    String formattedPhone = phone;
    if (phone.startsWith('0')) {
      formattedPhone = '62${phone.substring(1)}';
    }

    final url = Uri.parse('https://wa.me/$formattedPhone?text=Halo, saya penumpang NebengYuk!');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Status Perjalanan')),
      body: StreamBuilder<BookingModel?>(
        stream: firestoreService.getBookingStream(rideId, bookingId),
        builder: (context, bookingSnapshot) {
          if (bookingSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final booking = bookingSnapshot.data;
          if (booking == null) {
            return const Center(child: Text('Booking tidak ditemukan'));
          }

          return StreamBuilder<RideModel?>(
            stream: firestoreService.getRideStream(rideId),
            builder: (context, rideSnapshot) {
              final ride = rideSnapshot.data;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Status Card
                    _StatusCard(
                      bookingStatus: booking.status,
                      rideStatus: ride?.status ?? '',
                    ),
                    const SizedBox(height: 20),

                    // Map with driver location (when en-route)
                    if (ride?.status == AppConstants.statusEnRoute) ...[
                      _LiveDriverMap(rideId: rideId, booking: booking),
                      const SizedBox(height: 20),
                    ],

                    // Driver Info
                    if (ride != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Info Driver',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      ride.driverName.isNotEmpty
                                          ? ride.driverName[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ride.driverName,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            ride.vehicleType == 'car'
                                                ? Icons.directions_car
                                                : Icons.two_wheeler,
                                            size: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            ride.vehicleType == 'car' ? 'Mobil' : 'Motor',
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // WhatsApp Button (visible when accepted/en-route)
                    if (booking.status == AppConstants.bookingAccepted ||
                        ride?.status == AppConstants.statusEnRoute)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => _contactViaWhatsApp(
                            context,
                            ride?.driverPhone ?? '',
                          ),
                          icon: const Icon(Icons.chat_rounded, size: 20),
                          label: const Text('Hubungi via WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Back to home (when completed or rejected)
                    if (booking.status == AppConstants.bookingCompleted ||
                        booking.status == AppConstants.bookingRejected)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          child: const Text('Kembali ke Beranda'),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String bookingStatus;
  final String rideStatus;

  const _StatusCard({required this.bookingStatus, required this.rideStatus});

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    IconData icon;
    Color color;

    switch (bookingStatus) {
      case AppConstants.bookingPending:
        title = 'Menunggu Konfirmasi';
        subtitle = 'Driver sedang mempertimbangkan permintaanmu...';
        icon = Icons.hourglass_top_rounded;
        color = AppColors.warning;
        break;
      case AppConstants.bookingAccepted:
        if (rideStatus == AppConstants.statusEnRoute) {
          title = 'Driver Menuju ke Kamu';
          subtitle = 'Driver sedang dalam perjalanan ke titik jemput!';
          icon = Icons.directions_car_rounded;
          color = AppColors.enRoute;
        } else if (rideStatus == AppConstants.statusPickedUp) {
          title = 'Kamu Sudah Dijemput';
          subtitle = 'Selamat menikmati perjalanan!';
          icon = Icons.check_circle_rounded;
          color = AppColors.success;
        } else {
          title = 'Booking Diterima!';
          subtitle = 'Menunggu driver memulai perjalanan...';
          icon = Icons.thumb_up_rounded;
          color = AppColors.success;
        }
        break;
      case AppConstants.bookingRejected:
        title = 'Permintaan Ditolak';
        subtitle = 'Maaf, driver tidak dapat menerima permintaanmu.';
        icon = Icons.cancel_rounded;
        color = AppColors.error;
        break;
      case AppConstants.bookingCompleted:
        title = 'Perjalanan Selesai!';
        subtitle = 'Terima kasih telah nebeng!';
        icon = Icons.flag_rounded;
        color = AppColors.primary;
        break;
      default:
        title = 'Status Tidak Diketahui';
        subtitle = '';
        icon = Icons.help_outline;
        color = AppColors.textLight;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LiveDriverMap extends StatelessWidget {
  final String rideId;
  final BookingModel booking;

  const _LiveDriverMap({required this.rideId, required this.booking});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.hardEdge,
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: firestoreService.getDriverLocationStream(rideId),
        builder: (context, snapshot) {
          final driverData = snapshot.data;
          final driverLat = driverData?['lat']?.toDouble() ?? 0.0;
          final driverLng = driverData?['lng']?.toDouble() ?? 0.0;

          final pickupPoint = LatLng(booking.pickupLat, booking.pickupLng);
          final driverPoint = (driverLat != 0 && driverLng != 0)
              ? LatLng(driverLat, driverLng)
              : pickupPoint;

          return FlutterMap(
            options: MapOptions(
              initialCenter: driverPoint,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.nebengyuk',
              ),
              MarkerLayer(
                markers: [
                  // Pickup pin
                  Marker(
                    point: pickupPoint,
                    width: 40, height: 40,
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
                  ),
                  // Driver location
                  if (driverLat != 0 && driverLng != 0)
                    Marker(
                      point: driverPoint,
                      width: 40, height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

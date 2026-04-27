import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../models/ride_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
import 'driver_dashboard.dart';

class GiveRideScreen extends StatefulWidget {
  const GiveRideScreen({super.key});

  @override
  State<GiveRideScreen> createState() => _GiveRideScreenState();
}

class _GiveRideScreenState extends State<GiveRideScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  LatLng? _origin;
  LatLng? _destination;
  String _originAddress = '';
  String _destAddress = '';
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 1));
  String _vehicleType = 'car';
  int _availableSeats = 1;
  bool _isSelectingOrigin = true;
  bool _isLoading = false;

  void _selectOnMap(bool isOrigin) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _MapPickerScreen(
          title: isOrigin ? 'Pilih Titik Awal' : 'Pilih Tujuan',
          initialPosition: isOrigin ? _origin : _destination,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isOrigin) {
          _origin = result['latLng'] as LatLng;
          _originAddress = result['address'] as String;
        } else {
          _destination = result['latLng'] as LatLng;
          _destAddress = result['address'] as String;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departureTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      setState(() {
        _departureTime = DateTime(
          date.year, date.month, date.day,
          _departureTime.hour, _departureTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departureTime),
    );
    if (time != null) {
      setState(() {
        _departureTime = DateTime(
          _departureTime.year, _departureTime.month, _departureTime.day,
          time.hour, time.minute,
        );
      });
    }
  }

  Future<void> _postRide() async {
    if (_origin == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pilih titik asal dan tujuan terlebih dahulu'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      final userModel = await _authService.getUserModel(user!.uid);

      final ride = RideModel(
        rideId: '',
        driverId: user.uid,
        driverName: userModel?.displayName ?? user.displayName ?? 'Driver',
        driverPhone: userModel?.phone ?? '',
        originLat: _origin!.latitude,
        originLng: _origin!.longitude,
        originAddress: _originAddress,
        destLat: _destination!.latitude,
        destLng: _destination!.longitude,
        destAddress: _destAddress,
        departureTime: _departureTime,
        vehicleType: _vehicleType,
        totalSeats: _availableSeats,
        availableSeats: _availableSeats,
        status: AppConstants.statusScheduled,
        createdAt: DateTime.now(),
      );

      final rideId = await _firestoreService.createRide(ride);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverDashboardScreen(rideId: rideId),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Beri Tebengan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Origin
            _buildLabel('Titik Asal'),
            const SizedBox(height: 8),
            _LocationTile(
              address: _originAddress.isNotEmpty ? _originAddress : 'Pilih di peta',
              icon: Icons.trip_origin,
              color: AppColors.success,
              onTap: () => _selectOnMap(true),
            ),
            const SizedBox(height: 20),

            // Destination
            _buildLabel('Tujuan'),
            const SizedBox(height: 8),
            _LocationTile(
              address: _destAddress.isNotEmpty ? _destAddress : 'Pilih di peta',
              icon: Icons.flag_rounded,
              color: AppColors.error,
              onTap: () => _selectOnMap(false),
            ),
            const SizedBox(height: 20),

            // Departure Time
            _buildLabel('Waktu Keberangkatan'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('dd MMM yyyy').format(_departureTime),
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('HH:mm').format(_departureTime),
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Vehicle Type
            _buildLabel('Jenis Kendaraan'),
            const SizedBox(height: 8),
            Row(
              children: [
                _VehicleOption(
                  label: 'Mobil',
                  icon: Icons.directions_car,
                  isSelected: _vehicleType == 'car',
                  onTap: () => setState(() {
                    _vehicleType = 'car';
                    if (_availableSeats > 4) _availableSeats = 4;
                  }),
                ),
                const SizedBox(width: 12),
                _VehicleOption(
                  label: 'Motor',
                  icon: Icons.two_wheeler,
                  isSelected: _vehicleType == 'motorcycle',
                  onTap: () => setState(() {
                    _vehicleType = 'motorcycle';
                    _availableSeats = 1;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Available Seats
            _buildLabel('Kursi Tersedia'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _availableSeats > 1
                        ? () => setState(() => _availableSeats--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 24),
                  Text(
                    '$_availableSeats',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    onPressed: (_vehicleType == 'motorcycle' || _availableSeats >= 6)
                        ? null
                        : () => setState(() => _availableSeats++),
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Post Ride Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _postRide,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isLoading ? 'Memposting...' : 'Posting Tebengan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final String address;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _LocationTile({
    required this.address,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                address,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: address == 'Pilih di peta' ? AppColors.textLight : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class _VehicleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: isSelected ? null : Border.all(color: AppColors.surfaceVariant),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: isSelected ? Colors.white : AppColors.textSecondary),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== MAP PICKER ====================

class _MapPickerScreen extends StatefulWidget {
  final String title;
  final LatLng? initialPosition;

  const _MapPickerScreen({required this.title, this.initialPosition});

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  late LatLng _selected;
  final MapController _mapController = MapController();
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialPosition ?? const LatLng(-6.2088, 106.8456);
    if (widget.initialPosition == null) {
      _goToCurrentLocation();
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final locationService = LocationService();
      final hasPermission = await locationService.checkAndRequestPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Izin lokasi diperlukan untuk mendeteksi posisi'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      final position = await locationService.getCurrentPosition();
      final newLatLng = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _selected = newLatLng);
        _mapController.move(newLatLng, 16);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal mendapatkan lokasi GPS'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'latLng': _selected,
              'address': '${_selected.latitude.toStringAsFixed(4)}, ${_selected.longitude.toStringAsFixed(4)}',
            }),
            child: Text('Pilih', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 15,
              onTap: (_, point) => setState(() => _selected = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.nebengyuk',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selected,
                    width: 40, height: 40,
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 24, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_selected.latitude.toStringAsFixed(5)}, ${_selected.longitude.toStringAsFixed(5)}',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLocating)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          onPressed: _isLocating ? null : _goToCurrentLocation,
          backgroundColor: AppColors.primary,
          child: _isLocating
              ? const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Icon(Icons.my_location, color: Colors.white),
        ),
      ),
    );
  }
}

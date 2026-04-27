import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
import 'ride_results.dart';

class AskRideScreen extends StatefulWidget {
  const AskRideScreen({super.key});

  @override
  State<AskRideScreen> createState() => _AskRideScreenState();
}

class _AskRideScreenState extends State<AskRideScreen> {
  LatLng? _origin;
  LatLng? _destination;
  String _originAddress = '';
  String _destAddress = '';
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 1));
  String _vehiclePreference = 'both'; // car, motorcycle, both
  bool _isSelectingOrigin = true;

  void _selectOnMap() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _MapPickerScreen(
          title: _isSelectingOrigin ? 'Pilih Titik Jemput' : 'Pilih Tujuan',
          initialPosition: _isSelectingOrigin ? _origin : _destination,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (_isSelectingOrigin) {
          _origin = result['latLng'] as LatLng;
          _originAddress = result['address'] as String;
        } else {
          _destination = result['latLng'] as LatLng;
          _destAddress = result['address'] as String;
        }
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
          _departureTime.year,
          _departureTime.month,
          _departureTime.day,
          time.hour,
          time.minute,
        );
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
          date.year,
          date.month,
          date.day,
          _departureTime.hour,
          _departureTime.minute,
        );
      });
    }
  }

  void _searchRides() {
    if (_origin == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pilih titik jemput dan tujuan terlebih dahulu'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideResultsScreen(
          originLat: _origin!.latitude,
          originLng: _origin!.longitude,
          destLat: _destination!.latitude,
          destLng: _destination!.longitude,
          departureTime: _departureTime,
          vehiclePreference: _vehiclePreference,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cari Tebengan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Origin
            Text(
              'Titik Jemput',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _LocationPickerTile(
              address: _originAddress.isNotEmpty ? _originAddress : 'Pilih di peta',
              icon: Icons.my_location_rounded,
              color: AppColors.success,
              onTap: () {
                setState(() => _isSelectingOrigin = true);
                _selectOnMap();
              },
            ),
            const SizedBox(height: 20),

            // Destination
            Text(
              'Tujuan',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _LocationPickerTile(
              address: _destAddress.isNotEmpty ? _destAddress : 'Pilih di peta',
              icon: Icons.flag_rounded,
              color: AppColors.error,
              onTap: () {
                setState(() => _isSelectingOrigin = false);
                _selectOnMap();
              },
            ),
            const SizedBox(height: 20),

            // Departure Time
            Text(
              'Waktu Keberangkatan',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
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

            // Vehicle Preference
            Text(
              'Preferensi Kendaraan',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _VehicleChip(
                  label: 'Semua',
                  isSelected: _vehiclePreference == 'both',
                  onTap: () => setState(() => _vehiclePreference = 'both'),
                ),
                const SizedBox(width: 8),
                _VehicleChip(
                  label: 'Mobil',
                  icon: Icons.directions_car,
                  isSelected: _vehiclePreference == 'car',
                  onTap: () => setState(() => _vehiclePreference = 'car'),
                ),
                const SizedBox(width: 8),
                _VehicleChip(
                  label: 'Motor',
                  icon: Icons.two_wheeler,
                  isSelected: _vehiclePreference == 'motorcycle',
                  onTap: () => setState(() => _vehiclePreference = 'motorcycle'),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // Search Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _searchRides,
                icon: const Icon(Icons.search),
                label: const Text('Cari Tebengan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPickerTile extends StatelessWidget {
  final String address;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _LocationPickerTile({
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
                  color: address == 'Pilih di peta'
                      ? AppColors.textLight
                      : AppColors.textPrimary,
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

class _VehicleChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MAP PICKER SCREEN ====================

class _MapPickerScreen extends StatefulWidget {
  final String title;
  final LatLng? initialPosition;

  const _MapPickerScreen({required this.title, this.initialPosition});

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  // Default to a central location in Indonesia (Jakarta)
  late LatLng _selectedPosition;
  final MapController _mapController = MapController();
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition ?? const LatLng(-6.2088, 106.8456);
    // Auto-locate only if no initial position was provided
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
        setState(() => _selectedPosition = newLatLng);
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
            onPressed: () {
              Navigator.pop(context, {
                'latLng': _selectedPosition,
                'address':
                    '${_selectedPosition.latitude.toStringAsFixed(4)}, ${_selectedPosition.longitude.toStringAsFixed(4)}',
              });
            },
            child: Text(
              'Pilih',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              initialZoom: 15,
              onTap: (tapPosition, point) {
                setState(() => _selectedPosition = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.nebengyuk',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPosition,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Coordinates display
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_selectedPosition.latitude.toStringAsFixed(5)}, ${_selectedPosition.longitude.toStringAsFixed(5)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Loading indicator
          if (_isLocating)
            const Center(
              child: CircularProgressIndicator(),
            ),
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


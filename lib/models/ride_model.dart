import 'package:cloud_firestore/cloud_firestore.dart';

class RideModel {
  final String rideId;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final double originLat;
  final double originLng;
  final String originAddress;
  final double destLat;
  final double destLng;
  final String destAddress;
  final DateTime departureTime;
  final String vehicleType; // 'car' or 'motorcycle'
  final int totalSeats;
  final int availableSeats;
  final String status; // scheduled, fully_booked, en_route, picked_up, completed
  final DateTime createdAt;

  RideModel({
    required this.rideId,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.originLat,
    required this.originLng,
    required this.originAddress,
    required this.destLat,
    required this.destLng,
    required this.destAddress,
    required this.departureTime,
    required this.vehicleType,
    required this.totalSeats,
    required this.availableSeats,
    required this.status,
    required this.createdAt,
  });

  factory RideModel.fromMap(Map<String, dynamic> map, String docId) {
    return RideModel(
      rideId: docId,
      driverId: map['driverId'] ?? '',
      driverName: map['driverName'] ?? '',
      driverPhone: map['driverPhone'] ?? '',
      originLat: (map['originLat'] ?? 0).toDouble(),
      originLng: (map['originLng'] ?? 0).toDouble(),
      originAddress: map['originAddress'] ?? '',
      destLat: (map['destLat'] ?? 0).toDouble(),
      destLng: (map['destLng'] ?? 0).toDouble(),
      destAddress: map['destAddress'] ?? '',
      departureTime: (map['departureTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      vehicleType: map['vehicleType'] ?? 'car',
      totalSeats: map['totalSeats'] ?? 1,
      availableSeats: map['availableSeats'] ?? 0,
      status: map['status'] ?? 'scheduled',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'originLat': originLat,
      'originLng': originLng,
      'originAddress': originAddress,
      'destLat': destLat,
      'destLng': destLng,
      'destAddress': destAddress,
      'departureTime': Timestamp.fromDate(departureTime),
      'vehicleType': vehicleType,
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  RideModel copyWith({
    String? rideId,
    String? driverId,
    String? driverName,
    String? driverPhone,
    double? originLat,
    double? originLng,
    String? originAddress,
    double? destLat,
    double? destLng,
    String? destAddress,
    DateTime? departureTime,
    String? vehicleType,
    int? totalSeats,
    int? availableSeats,
    String? status,
    DateTime? createdAt,
  }) {
    return RideModel(
      rideId: rideId ?? this.rideId,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      originAddress: originAddress ?? this.originAddress,
      destLat: destLat ?? this.destLat,
      destLng: destLng ?? this.destLng,
      destAddress: destAddress ?? this.destAddress,
      departureTime: departureTime ?? this.departureTime,
      vehicleType: vehicleType ?? this.vehicleType,
      totalSeats: totalSeats ?? this.totalSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

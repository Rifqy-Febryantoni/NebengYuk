import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String bookingId;
  final String rideId;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final String status; // pending, accepted, rejected, completed
  final DateTime createdAt;

  BookingModel({
    required this.bookingId,
    required this.rideId,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.status,
    required this.createdAt,
  });

  factory BookingModel.fromMap(Map<String, dynamic> map, String docId) {
    return BookingModel(
      bookingId: docId,
      rideId: map['rideId'] ?? '',
      passengerId: map['passengerId'] ?? '',
      passengerName: map['passengerName'] ?? '',
      passengerPhone: map['passengerPhone'] ?? '',
      pickupLat: (map['pickupLat'] ?? 0).toDouble(),
      pickupLng: (map['pickupLng'] ?? 0).toDouble(),
      pickupAddress: map['pickupAddress'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'pickupAddress': pickupAddress,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  BookingModel copyWith({
    String? bookingId,
    String? rideId,
    String? passengerId,
    String? passengerName,
    String? passengerPhone,
    double? pickupLat,
    double? pickupLng,
    String? pickupAddress,
    String? status,
    DateTime? createdAt,
  }) {
    return BookingModel(
      bookingId: bookingId ?? this.bookingId,
      rideId: rideId ?? this.rideId,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

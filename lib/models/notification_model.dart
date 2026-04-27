import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notifId;
  final String userId;
  final String title;
  final String body;
  final String type; // booking_request, booking_accepted, driver_arrived, ride_completed, etc.
  final String? rideId;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.notifId,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.rideId,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationModel(
      notifId: docId,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? '',
      rideId: map['rideId'],
      read: map['read'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'rideId': rideId,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

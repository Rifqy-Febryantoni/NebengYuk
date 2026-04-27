import '../models/notification_model.dart';
import '../utils/constants.dart';
import 'firestore_service.dart';
import 'local_notification_service.dart';

class NotificationService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Send notification: stored in Firestore AND shown as Android system notification.
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? rideId,
  }) async {
    // 1. Store in Firestore (in-app notification history)
    final notification = NotificationModel(
      notifId: '',
      userId: userId,
      title: title,
      body: body,
      type: type,
      rideId: rideId,
      read: false,
      createdAt: DateTime.now(),
    );

    await _firestoreService.createNotification(notification);

    // 2. Show Android system tray notification (native)
    await LocalNotificationService.show(
      title: title,
      body: body,
    );
  }

  // Pre-built notification templates
  Future<void> notifyBookingRequested({
    required String driverId,
    required String passengerName,
    String? rideId,
  }) async {
    await sendNotification(
      userId: driverId,
      title: 'Permintaan Nebeng Baru',
      body: '$passengerName ingin nebeng di perjalananmu!',
      type: 'booking_request',
      rideId: rideId,
    );
  }

  Future<void> notifyBookingAccepted({
    required String passengerId,
    required String driverName,
    String? rideId,
  }) async {
    await sendNotification(
      userId: passengerId,
      title: 'Nebeng Diterima!',
      body: '$driverName menerima permintaan nebengmu.',
      type: 'booking_accepted',
      rideId: rideId,
    );
  }

  Future<void> notifyBookingRejected({
    required String passengerId,
    required String driverName,
    String? rideId,
  }) async {
    await sendNotification(
      userId: passengerId,
      title: 'Permintaan Ditolak',
      body: '$driverName tidak dapat menerima nebengmu saat ini.',
      type: 'booking_rejected',
      rideId: rideId,
    );
  }

  Future<void> notifyDriverEnRoute({
    required String passengerId,
    required String driverName,
    String? rideId,
  }) async {
    await sendNotification(
      userId: passengerId,
      title: 'Driver Sedang Menuju',
      body: '$driverName sedang dalam perjalanan ke titik jemputmu!',
      type: 'driver_en_route',
      rideId: rideId,
    );
  }

  Future<void> notifyDriverArrived({
    required String passengerId,
    required String driverName,
    String? rideId,
  }) async {
    await sendNotification(
      userId: passengerId,
      title: 'Driver Sudah Sampai!',
      body: '$driverName sudah tiba di titik jemput.',
      type: 'driver_arrived',
      rideId: rideId,
    );
  }

  Future<void> notifyRideCompleted({
    required String userId,
    String? rideId,
  }) async {
    await sendNotification(
      userId: userId,
      title: 'Perjalanan Selesai',
      body: 'Perjalananmu telah selesai. Terima kasih telah menggunakan NebengYuk!',
      type: 'ride_completed',
      rideId: rideId,
    );
  }
}

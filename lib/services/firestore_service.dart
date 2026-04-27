import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ==================== RIDES ====================

  // Create a new ride
  Future<String> createRide(RideModel ride) async {
    final docId = _uuid.v4();
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(docId)
        .set(ride.copyWith(rideId: docId).toMap());
    return docId;
  }

  // Get available rides (scheduled, with seats > 0)
  // Note: Using minimal Firestore filters to avoid requiring composite indexes.
  // Additional filtering (seats, time) is done client-side in ride_results.dart.
  Stream<List<RideModel>> getAvailableRides() {
    return _firestore
        .collection(AppConstants.ridesCollection)
        .where('status', isEqualTo: AppConstants.statusScheduled)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideModel.fromMap(doc.data(), doc.id))
            .where((ride) => ride.availableSeats > 0)
            .toList());
  }

  // Get rides by driver
  Stream<List<RideModel>> getDriverRides(String driverId) {
    return _firestore
        .collection(AppConstants.ridesCollection)
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
      final rides = snapshot.docs
          .map((doc) => RideModel.fromMap(doc.data(), doc.id))
          .toList();
      rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rides;
    });
  }

  // Get a single ride stream
  Stream<RideModel?> getRideStream(String rideId) {
    return _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return RideModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  // Update ride status
  Future<void> updateRideStatus(String rideId, String status) async {
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .update({'status': status});
  }

  // Update available seats
  Future<void> updateAvailableSeats(String rideId, int seats) async {
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .update({'availableSeats': seats});
  }

  // Delete ride
  Future<void> deleteRide(String rideId) async {
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .delete();
  }

  // ==================== BOOKINGS ====================

  // Create a booking and decrement seats atomically
  Future<String> createBooking(BookingModel booking) async {
    final docId = _uuid.v4();

    await _firestore.runTransaction((transaction) async {
      // Read the ride document
      final rideRef = _firestore
          .collection(AppConstants.ridesCollection)
          .doc(booking.rideId);
      final rideDoc = await transaction.get(rideRef);

      if (!rideDoc.exists) {
        throw Exception('Ride not found');
      }

      final currentSeats = rideDoc.data()!['availableSeats'] as int;
      if (currentSeats <= 0) {
        throw Exception('No seats available');
      }

      // Decrement seats
      transaction.update(rideRef, {'availableSeats': currentSeats - 1});

      // If this was the last seat, mark as fully booked
      if (currentSeats - 1 == 0) {
        transaction.update(rideRef, {'status': AppConstants.statusFullyBooked});
      }

      // Create the booking
      final bookingRef = _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(docId);
      transaction.set(bookingRef, booking.copyWith(bookingId: docId).toMap());
    });

    return docId;
  }

  // Get bookings for a ride
  Stream<List<BookingModel>> getRideBookings(String rideId) {
    return _firestore
        .collection(AppConstants.bookingsCollection)
        .where('rideId', isEqualTo: rideId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
          .toList();
      bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bookings;
    });
  }

  // Get bookings by passenger
  Stream<List<BookingModel>> getPassengerBookings(String passengerId) {
    return _firestore
        .collection(AppConstants.bookingsCollection)
        .where('passengerId', isEqualTo: passengerId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
          .toList();
      bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bookings;
    });
  }

  // Get single booking stream
  Stream<BookingModel?> getBookingStream(String bookingId) {
    return _firestore
        .collection(AppConstants.bookingsCollection)
        .doc(bookingId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return BookingModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  // Update booking status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _firestore
        .collection(AppConstants.bookingsCollection)
        .doc(bookingId)
        .update({'status': status});
  }

  // Reject booking and restore seat
  Future<void> rejectBooking(String bookingId, String rideId) async {
    await _firestore.runTransaction((transaction) async {
      final rideRef = _firestore
          .collection(AppConstants.ridesCollection)
          .doc(rideId);
      final rideDoc = await transaction.get(rideRef);

      if (rideDoc.exists) {
        final currentSeats = rideDoc.data()!['availableSeats'] as int;
        transaction.update(rideRef, {'availableSeats': currentSeats + 1});

        // If was fully booked, set back to scheduled
        if (rideDoc.data()!['status'] == AppConstants.statusFullyBooked) {
          transaction.update(rideRef, {'status': AppConstants.statusScheduled});
        }
      }

      final bookingRef = _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId);
      transaction.update(bookingRef, {'status': AppConstants.bookingRejected});
    });
  }

  // ==================== DRIVER LOCATION ====================

  // Update driver location
  Future<void> updateDriverLocation(
    String rideId,
    String driverId,
    double lat,
    double lng,
  ) async {
    await _firestore
        .collection(AppConstants.driverLocationsCollection)
        .doc(rideId)
        .set({
      'driverId': driverId,
      'lat': lat,
      'lng': lng,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get driver location stream
  Stream<Map<String, dynamic>?> getDriverLocationStream(String rideId) {
    return _firestore
        .collection(AppConstants.driverLocationsCollection)
        .doc(rideId)
        .snapshots()
        .map((doc) => doc.data());
  }

  // Remove driver location
  Future<void> removeDriverLocation(String rideId) async {
    await _firestore
        .collection(AppConstants.driverLocationsCollection)
        .doc(rideId)
        .delete();
  }

  // ==================== NOTIFICATIONS ====================

  // Create notification
  Future<void> createNotification(NotificationModel notification) async {
    final docId = _uuid.v4();
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(docId)
        .set(notification.toMap());
  }

  // Get user notifications
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    });
  }

  // Mark notification as read
  Future<void> markNotificationRead(String notifId) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notifId)
        .update({'read': true});
  }

  // ==================== ARCHIVING (RELATIONAL CLEANUP) ====================

  /// Archive a completed ride and its related bookings.
  /// Moves ride → ride_history, bookings → booking_history,
  /// then deletes originals from active collections.
  Future<void> archiveCompletedRide(String rideId) async {
    final batch = _firestore.batch();

    // 1. Read the ride document
    final rideDoc = await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .get();

    if (!rideDoc.exists) return;

    // 2. Copy ride to ride_history (preserving the same doc ID)
    batch.set(
      _firestore.collection(AppConstants.rideHistoryCollection).doc(rideId),
      {
        ...rideDoc.data()!,
        'archivedAt': FieldValue.serverTimestamp(),
      },
    );

    // 3. Delete ride from active collection
    batch.delete(
      _firestore.collection(AppConstants.ridesCollection).doc(rideId),
    );

    // 4. Read all related bookings
    final bookingsSnapshot = await _firestore
        .collection(AppConstants.bookingsCollection)
        .where('rideId', isEqualTo: rideId)
        .get();

    // 5. Copy each booking to booking_history, then delete original
    for (final bookingDoc in bookingsSnapshot.docs) {
      batch.set(
        _firestore
            .collection(AppConstants.bookingHistoryCollection)
            .doc(bookingDoc.id),
        {
          ...bookingDoc.data(),
          'archivedAt': FieldValue.serverTimestamp(),
        },
      );
      batch.delete(bookingDoc.reference);
    }

    // 6. Also clean up driver_locations if any
    final driverLocDoc = await _firestore
        .collection(AppConstants.driverLocationsCollection)
        .doc(rideId)
        .get();
    if (driverLocDoc.exists) {
      batch.delete(driverLocDoc.reference);
    }

    // 7. Execute all operations atomically
    await batch.commit();
  }

  // ==================== HISTORY QUERIES ====================

  /// Get completed rides by driver from ride_history collection.
  Stream<List<RideModel>> getDriverRideHistory(String driverId) {
    return _firestore
        .collection(AppConstants.rideHistoryCollection)
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
      final rides = snapshot.docs
          .map((doc) => RideModel.fromMap(doc.data(), doc.id))
          .toList();
      rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rides;
    });
  }

  /// Get completed bookings by passenger from booking_history collection.
  Stream<List<BookingModel>> getPassengerBookingHistory(String passengerId) {
    return _firestore
        .collection(AppConstants.bookingHistoryCollection)
        .where('passengerId', isEqualTo: passengerId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
          .toList();
      bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bookings;
    });
  }
}

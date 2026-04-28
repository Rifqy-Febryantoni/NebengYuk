import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ==================== RIDES (ROOT HUB) ====================

  Future<String> createRide(RideModel ride) async {
    final docId = _uuid.v4();
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(docId)
        .set(ride.copyWith(rideId: docId).toMap());
    return docId;
  }

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

  Future<void> updateRideStatus(String rideId, String status) async {
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .update({'status': status});
  }

  Future<void> updateAvailableSeats(String rideId, int seats) async {
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .update({'availableSeats': seats});
  }

  Future<void> deleteRide(String rideId) async {
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .delete();
  }

  // ==================== BOOKINGS (SUBCOLLECTIONS) ====================

  Future<String> createBooking(BookingModel booking) async {
    final docId = _uuid.v4();

    await _firestore.runTransaction((transaction) async {
      final rideRef = _firestore
          .collection(AppConstants.ridesCollection)
          .doc(booking.rideId);
      final rideDoc = await transaction.get(rideRef);

      if (!rideDoc.exists) throw Exception('Ride not found');

      final currentSeats = rideDoc.data()!['availableSeats'] as int;
      if (currentSeats <= 0) throw Exception('No seats available');

      transaction.update(rideRef, {'availableSeats': currentSeats - 1});

      if (currentSeats - 1 == 0) {
        transaction.update(rideRef, {'status': AppConstants.statusFullyBooked});
      }

      // 🚀 NEW: Nesting the booking specifically under the ride document
      final bookingRef = rideRef.collection('bookings').doc(docId);
      transaction.set(bookingRef, booking.copyWith(bookingId: docId).toMap());
    });

    return docId;
  }

  // 🚀 NEW: Scoped query pointing directly to the ride's subcollection
  Stream<List<BookingModel>> getRideBookings(String rideId) {
    return _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .collection('bookings')
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
          .toList();
      bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bookings;
    });
  }

  // 🚀 NEW: Collection Group Query. Finds bookings for a passenger across ALL rides.
  Stream<List<BookingModel>> getPassengerBookings(String passengerId) {
    return _firestore
        .collectionGroup('bookings')
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

  // 🚀 NEW: Requires rideId to locate the specific subcollection
  Stream<BookingModel?> getBookingStream(String rideId, String bookingId) {
    return _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .collection('bookings')
        .doc(bookingId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return BookingModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  // 🚀 NEW: Requires rideId to locate and update the correct booking
  Future<void> updateBookingStatus(String rideId, String bookingId, String status) async {
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .collection('bookings')
        .doc(bookingId)
        .update({'status': status});
  }

  Future<void> rejectBooking(String bookingId, String rideId) async {
    await _firestore.runTransaction((transaction) async {
      final rideRef = _firestore
          .collection(AppConstants.ridesCollection)
          .doc(rideId);
      final rideDoc = await transaction.get(rideRef);

      if (rideDoc.exists) {
        final currentSeats = rideDoc.data()!['availableSeats'] as int;
        transaction.update(rideRef, {'availableSeats': currentSeats + 1});

        if (rideDoc.data()!['status'] == AppConstants.statusFullyBooked) {
          transaction.update(rideRef, {'status': AppConstants.statusScheduled});
        }
      }

      // 🚀 NEW: Pointing to the subcollection
      final bookingRef = rideRef.collection('bookings').doc(bookingId);
      transaction.update(bookingRef, {'status': AppConstants.bookingRejected});
    });
  }

  // ==================== DRIVER LOCATION (FLATTENED INTO RIDE) ====================

  // 🚀 NEW: Instead of a separate collection, we inject live coords directly into the active ride
  Future<void> updateDriverLocation(String rideId, String driverId, double lat, double lng) async {
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .update({
      'driverLiveLat': lat,
      'driverLiveLng': lng,
    });
  }

  // 🚀 NEW: Extracts the newly injected coordinates from the ride document
  Stream<Map<String, dynamic>?> getDriverLocationStream(String rideId) {
    return _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('driverLiveLat') && data.containsKey('driverLiveLng')) {
          return {
            'lat': data['driverLiveLat'],
            'lng': data['driverLiveLng'],
          };
        }
      }
      return null;
    });
  }

  // 🚀 NEW: Cleans up the live coordinates once the ride finishes
  Future<void> removeDriverLocation(String rideId) async {
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .update({
      'driverLiveLat': FieldValue.delete(),
      'driverLiveLng': FieldValue.delete(),
    });
  }

  // ==================== NOTIFICATIONS (NESTED UNDER USERS) ====================

  Future<void> createNotification(NotificationModel notification) async {
    final docId = _uuid.v4();
    // 🚀 NEW: Notifications are now securely nested under the specific user's document
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(notification.userId)
        .collection('notifications')
        .doc(docId)
        .set(notification.toMap());
  }

  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection('notifications')
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    });
  }

  // 🚀 NEW: Requires userId to locate the subcollection
  Future<void> markNotificationRead(String userId, String notifId) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection('notifications')
        .doc(notifId)
        .update({'read': true});
  }

  // ==================== ARCHIVING (MAINTAINS HIERARCHY) ====================

  Future<void> archiveCompletedRide(String rideId) async {
    final batch = _firestore.batch();

    final rideDoc = await _firestore.collection(AppConstants.ridesCollection).doc(rideId).get();
    if (!rideDoc.exists) return;

    // 1. Copy ride to history
    final historyRideRef = _firestore.collection(AppConstants.rideHistoryCollection).doc(rideId);
    batch.set(historyRideRef, {
      ...rideDoc.data()!,
      'archivedAt': FieldValue.serverTimestamp(),
    });

    // 2. Fetch all bookings from the subcollection
    final bookingsSnapshot = await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .collection('bookings')
        .get();

    // 3. Move bookings to the history subcollection and delete the active ones
    for (final bookingDoc in bookingsSnapshot.docs) {
      final historyBookingRef = historyRideRef.collection('bookings').doc(bookingDoc.id);
      
      batch.set(historyBookingRef, {
        ...bookingDoc.data(),
        'archivedAt': FieldValue.serverTimestamp(),
      });
      batch.delete(bookingDoc.reference);
    }

    // 4. Delete the active ride
    batch.delete(rideDoc.reference);

    await batch.commit();
  }

  // ==================== HISTORY QUERIES ====================

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

  Stream<List<BookingModel>> getPassengerBookingHistory(String passengerId) {
    // 🚀 NEW: Uses collectionGroup so it searches inside all archived rides
    return _firestore
        .collectionGroup('bookings')
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
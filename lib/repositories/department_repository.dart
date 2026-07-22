import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/failures.dart';
import '../models/appointment_model.dart';
import '../models/department_model.dart' hide AppointmentModel;

class DepartmentRepository {
  DepartmentRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Future<void> createDepartment({
    required String hospitalId,
    required String name,
    String openTime = '08:00',
    String closeTime = '17:00',
    int slotDurationMinutes = 30,
    int slotCapacity = 5,
  }) async {
    try {
      await _firestore.collection(FirestorePaths.departments).add(
        DepartmentModel(
          id: '',
          hospitalId: hospitalId,
          name: name,
          openTime: openTime,
          closeTime: closeTime,
          slotDurationMinutes: slotDurationMinutes,
          slotCapacity: slotCapacity,
        ).toMap(),
      );
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to create department', code: e.code);
    }
  }

  Stream<List<DepartmentModel>> watchDepartments(String hospitalId) {
    return _firestore
        .collection(FirestorePaths.departments)
        .where('hospitalId', isEqualTo: hospitalId)
        .snapshots()
        .map((snap) => snap.docs.map(DepartmentModel.fromFirestore).toList());
  }



  /// Available slots for a given department/date, with remaining capacity
  /// per slot. Counts existing 'booked'+'checked_in' appointments matching
  /// each slot label — small dataset (one department, one day), so client-
  /// side counting is fine, same reasoning as other per-day aggregations
  /// in this app.
  Stream<List<({String slot, int remaining})>> watchAvailableSlots({
    required DepartmentModel department,
    required String date,
  }) {
    return _firestore
        .collection(FirestorePaths.appointments)
        .where('hospitalId', isEqualTo: department.hospitalId)
        .where('departmentId', isEqualTo: department.id)
        .where('scheduledDate', isEqualTo: date)
        .snapshots()
        .map((snap) {
      final appts = snap.docs.map(AppointmentModel.fromFirestore).toList();
      final countsBySlot = <String, int>{};
      for (final a in appts) {
        if (a.scheduledTimeSlot == null) continue;
        if (a.status == 'booked' || a.status == 'checked_in') {
          countsBySlot[a.scheduledTimeSlot!] = (countsBySlot[a.scheduledTimeSlot!] ?? 0) + 1;
        }
      }
      return department.generateSlots().map((slot) {
        final taken = countsBySlot[slot] ?? 0;
        return (slot: slot, remaining: department.slotCapacity - taken);
      }).toList();
    });
  }

  /// Resolves a department name from an id given a list already fetched
  /// elsewhere (e.g. from watchDepartments) — avoids every screen writing
  /// its own `.firstWhere(...)` / `?? id` fallback boilerplate, and keeps
  /// the "what do we show if it's missing" decision in one place.
  String departmentNameFromList(List<DepartmentModel> departments, String departmentId) {
    final match = departments.where((d) => d.id == departmentId);
    return match.isEmpty ? departmentId : match.first.name;
  }

  /// Same, but keyed as a Map for O(1) repeated lookups — the pattern
  /// already used ad hoc in checkin_screen.dart, doctor_history_screen.dart,
  /// etc. (`{for (final d in departments) d.id: d.name}`), now centralized
  /// so future screens don't reinvent it slightly differently each time.
  Map<String, String> departmentNameMap(List<DepartmentModel> departments) {
    return {for (final d in departments) d.id: d.name};
  }
}
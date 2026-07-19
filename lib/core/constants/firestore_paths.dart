/// Centralized Firestore collection and document path builders.
///
/// No collection or document path should be hand-typed anywhere else in the
/// app — always go through this file, so a path change only ever needs to
/// happen in one place.
class FirestorePaths {
  FirestorePaths._();

  // ---------------------------------------------------------------------
  // Top-level collection names
  // ---------------------------------------------------------------------
  static const String hospitals = 'hospitals';
  static const String departments = 'departments';
  static const String users = 'users';
  static const String doctors = 'doctors';
  static const String appointments = 'appointments';
  static const String visits = 'visits';
  static const String counters = 'counters';
  static const String notifications = 'notifications';
  static const String queueEntriesRoot = 'queue_entries';
  static const String smsEmulator = 'sms_emulator';

  // ---------------------------------------------------------------------
  // Simple document path helpers
  // ---------------------------------------------------------------------
  static String hospital(String hospitalId) => '$hospitals/$hospitalId';

  static String department(String departmentId) =>
      '$departments/$departmentId';

  static String user(String userId) => '$users/$userId';

  static String doctor(String doctorId) => '$doctors/$doctorId';

  static String appointment(String appointmentId) =>
      '$appointments/$appointmentId';

  static String visit(String visitId) => '$visits/$visitId';

  static String notification(String notificationId) =>
      '$notifications/$notificationId';

  // ---------------------------------------------------------------------
  // Counters — composite doc ID: {hospitalId}_{departmentId}_{date}
  // date must be a consistent 'yyyy-MM-dd' string across the whole app.
  // ---------------------------------------------------------------------
  static String counterId({
    required String hospitalId,
    required String departmentId,
    required String date,
  }) => '${hospitalId}_${departmentId}_$date';

  static String counter({
    required String hospitalId,
    required String departmentId,
    required String date,
  }) => '$counters/${counterId(
    hospitalId: hospitalId,
    departmentId: departmentId,
    date: date,
  )}';

  // ---------------------------------------------------------------------
  // Queue entries — nested path:
  //   queue_entries/{hospitalId}/{date}/{departmentId}/entries/{entryId}
  //
  // This is intentionally NOT a flat collection with FK fields — the path
  // itself scopes every query to a single hospital + day + department,
  // which is exactly the shape the live queue query needs.
  // ---------------------------------------------------------------------
  static String queueEntriesCollection({
    required String hospitalId,
    required String date,
    required String departmentId,
  }) => '$queueEntriesRoot/$hospitalId/$date/$departmentId/entries';

  static String queueEntry({
    required String hospitalId,
    required String date,
    required String departmentId,
    required String entryId,
  }) => '${queueEntriesCollection(
    hospitalId: hospitalId,
    date: date,
    departmentId: departmentId,
  )}/$entryId';
}
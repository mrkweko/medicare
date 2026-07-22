import 'package:cloud_firestore/cloud_firestore.dart';

class DepartmentModel {
  final String id;
  final String hospitalId;
  final String name;
  final String openTime; // 'HH:mm', 24hr
  final String closeTime;
  final int slotDurationMinutes;
  final int slotCapacity;

  const DepartmentModel({
    required this.id,
    required this.hospitalId,
    required this.name,
    this.openTime = '08:00',
    this.closeTime = '17:00',
    this.slotDurationMinutes = 30,
    this.slotCapacity = 5,
  });

  factory DepartmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return DepartmentModel(
      id: doc.id,
      hospitalId: d['hospitalId'],
      name: d['name'],
      openTime: d['openTime'] ?? '08:00',
      closeTime: d['closeTime'] ?? '17:00',
      slotDurationMinutes: (d['slotDurationMinutes'] as num?)?.toInt() ?? 30,
      slotCapacity: (d['slotCapacity'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toMap() => {
    'hospitalId': hospitalId,
    'name': name,
    'openTime': openTime,
    'closeTime': closeTime,
    'slotDurationMinutes': slotDurationMinutes,
    'slotCapacity': slotCapacity,
    'createdAt': FieldValue.serverTimestamp(),
  };

  /// Generates the list of slot labels for a day, e.g. '08:00-08:30'.
  List<String> generateSlots() {
    final slots = <String>[];
    final open = _parseTime(openTime);
    final close = _parseTime(closeTime);
    var current = open;
    while (current + slotDurationMinutes <= close) {
      final start = _formatTime(current);
      final end = _formatTime(current + slotDurationMinutes);
      slots.add('$start-$end');
      current += slotDurationMinutes;
    }
    return slots;
  }

  static int _parseTime(String t) {
    final parts = t.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String _formatTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
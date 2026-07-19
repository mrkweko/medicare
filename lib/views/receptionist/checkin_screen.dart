import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/appointment_model.dart';
import '../../repositories/queue_repository.dart';
import '../../viewmodels/auth/auth_viewmodel.dart';
import '../../viewmodels/patient/booking_viewmodel.dart';

final queueRepositoryProvider = Provider((ref) => QueueRepository());

class CheckInScreen extends ConsumerWidget {
  const CheckInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final hospitalId = profile?.hospitalId;
    if (hospitalId == null) return const Scaffold(body: Center(child: Text('No hospitalId on profile')));

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Appointments")),
      body: StreamBuilder<List<AppointmentModel>>(
        stream: ref.read(appointmentRepositoryProvider).watchTodaysAppointmentsForHospital(hospitalId: hospitalId, date: today),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snap.error}')));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final appts = snap.data!.where((a) => a.status == 'booked').toList();
          if (appts.isEmpty) return const Center(child: Text('No pending appointments today'));
          return ListView.builder(
            itemCount: appts.length,
            itemBuilder: (context, i) {
              final a = appts[i];
              return ListTile(
                leading: CircleAvatar(child: Text('#${a.tokenNumber}')),
                title: Text('Dept: ${a.departmentId}'),
                subtitle: Text('Patient: ${a.patientId}'),
                trailing: FilledButton(
                  onPressed: () async {
                    try {
                      await ref.read(queueRepositoryProvider).checkIn(
                        appointmentId: a.id,
                        patientId: a.patientId,
                        doctorId: a.doctorId,
                        tokenNumber: a.tokenNumber,
                        hospitalId: a.hospitalId,
                        date: a.scheduledDate,
                        departmentId: a.departmentId,
                      );
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked in')));
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  },
                  child: const Text('Check In'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
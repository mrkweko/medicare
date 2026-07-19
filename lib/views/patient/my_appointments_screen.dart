import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/appointment_model.dart';
import '../../viewmodels/auth/auth_viewmodel.dart';
import '../../viewmodels/patient/booking_viewmodel.dart';

class MyAppointmentsScreen extends ConsumerWidget {
  const MyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('My Appointments')),
      body: StreamBuilder<List<AppointmentModel>>(
        stream: ref.read(appointmentRepositoryProvider).watchPatientAppointments(profile.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snap.error}')));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final appts = snap.data!;
          if (appts.isEmpty) return const Center(child: Text('No appointments yet'));
          return ListView.builder(
            itemCount: appts.length,
            itemBuilder: (context, i) {
              final a = appts[i];
              return ListTile(
                leading: CircleAvatar(child: Text('#${a.tokenNumber}')),
                title: Text('${a.scheduledDate} — ${a.status}'),
                subtitle: Text(a.doctorId == null ? 'Doctor: not yet assigned' : 'Doctor: ${a.doctorId}'),
              );
            },
          );
        },
      ),
    );
  }
}
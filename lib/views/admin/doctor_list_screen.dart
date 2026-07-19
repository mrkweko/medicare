import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/department_model.dart';
import '../../models/doctor_model.dart';
import '../../repositories/doctor_repository.dart';
import '../../viewmodels/auth/auth_viewmodel.dart';
import '../../viewmodels/patient/booking_viewmodel.dart'; // bookingDepartmentRepoProvider

final _doctorRepoProvider = Provider((ref) => DoctorRepository());

class DoctorListScreen extends ConsumerWidget {
  const DoctorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final hospitalId = profile?.hospitalId;
    if (hospitalId == null) return const Scaffold(body: Center(child: Text('No hospitalId on profile')));

    return Scaffold(
      appBar: AppBar(title: const Text('Doctors')),
      body: StreamBuilder<List<DepartmentModel>>(
        stream: ref.read(bookingDepartmentRepoProvider).watchDepartments(hospitalId),
        builder: (context, deptSnap) {
          final departments = deptSnap.data ?? [];
          final deptNameById = {for (final d in departments) d.id: d.name};

          return StreamBuilder<List<DoctorModel>>(
            stream: ref.read(_doctorRepoProvider).watchAllDoctorsForHospital(hospitalId),
            builder: (context, docSnap) {
              if (docSnap.hasError) return Center(child: Text('Error: ${docSnap.error}'));
              if (!docSnap.hasData) return const Center(child: CircularProgressIndicator());
              final doctors = docSnap.data!;
              if (doctors.isEmpty) return const Center(child: Text('No doctors yet'));

              return ListView.builder(
                itemCount: doctors.length,
                itemBuilder: (context, i) {
                  final doc = doctors[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.medical_services)),
                    title: Text(doc.displayName),
                    subtitle: Text(
                      '${deptNameById[doc.departmentId] ?? 'Unknown department'} · avg ${doc.avgConsultationMinutes} min/consult',
                    ),
                    trailing: departments.isEmpty
                        ? null
                        : DropdownButton<String>(
                      value: doc.departmentId,
                      items: departments
                          .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                          .toList(),
                      onChanged: (newDeptId) async {
                        if (newDeptId == null || newDeptId == doc.departmentId) return;
                        try {
                          await ref.read(_doctorRepoProvider).reassignDepartment(
                            doctorId: doc.uid,
                            newDepartmentId: newDeptId,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${doc.displayName} moved to ${deptNameById[newDeptId]}')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                          }
                        }
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
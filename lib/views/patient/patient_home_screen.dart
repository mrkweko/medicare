import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/auth/auth_viewmodel.dart';

class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authFormControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text('Signed in as ${profile?.email ?? '?'}\nrole: ${profile?.role.toFirestoreString() ?? '?'}'),
                const SizedBox(height: 12,),
                FilledButton.icon(
                    onPressed: () => context.push('patient/book'), 
                    label: const Text('Book an Appointment'
                    )
                ),
                const SizedBox(height: 12,),
                FilledButton.icon(
                    onPressed: () => context.push('patient/appointments'),
                    label: const Text(
                        'My Appointments'
                    )
                ),
                const SizedBox(height: 12,),
                FilledButton.icon(
                    onPressed: () => context.push('patient/notifications'),
                    label: const Text(
                        'Notifications'
                    )
                ),
              ],
            ),
          ),
        ),),
    );
  }
}
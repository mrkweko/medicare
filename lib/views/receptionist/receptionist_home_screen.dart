import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/auth/auth_viewmodel.dart';

class ReceptionistHomeScreen extends ConsumerWidget {
  const ReceptionistHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receptionist Home Screen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authFormControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text('Signed in as ${profile?.email ?? '?'}\nrole: ${profile?.role.toFirestoreString() ?? '?'}'),
              const SizedBox(height: 12,),
              FilledButton.icon(
                  onPressed: () => context.push('/receptionist/checkin'),
                  label: const Text(
                    'Check In'
                  ),
              ),
              const SizedBox(height: 12,),
              FilledButton.icon(
                onPressed: () => context.push('/receptionist/priority-checkin'),
                label: const Text(
                    'Emergency'
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.person_2_outlined),
                label: const Text('Skipped Patients'),
                onPressed: () => context.push('/receptionist/skipped'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.person_2_outlined),
                label: const Text('Walk in Patient'),
                onPressed: () => context.push('/receptionist/walkin-booking'),
              ),
            ],
          ),
        )
      ),
    );
  }
}
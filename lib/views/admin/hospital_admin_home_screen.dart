import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/auth/auth_viewmodel.dart';

class HospitalAdminHomeScreen extends ConsumerWidget {
  const HospitalAdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Admin Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authFormControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Signed in as ${profile?.email ?? '?'}'),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.badge),
              label: const Text('Add Staff Member'),
              onPressed: () => context.push('/admin/staff/create'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.local_fire_department_outlined),
              label: const Text('Departments'),
              onPressed: () => context.push('/admin/departments'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.policy_outlined),
              label: const Text('Skip Policy'),
              onPressed: () => context.push('/admin/skip-policy'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.policy_outlined),
              label: const Text('Doctor List Screen'),
              onPressed: () => context.push('/admin/doctors'),
            ),
          ],
        ),
      ),
    );
  }
}
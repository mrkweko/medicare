import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/auth/auth_viewmodel.dart';

class SuperAdminHomeScreen extends ConsumerWidget {
  const SuperAdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Home'),
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
              icon: const Icon(Icons.local_hospital),
              label: const Text('Manage Hospitals'),
              onPressed: () => context.push('/super-admin/hospitals/create'),
            ),
            const SizedBox(height: 12,),
            FilledButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
                onPressed: () => context.push('/super-admin/staff/create-hospital-admin'), 
                label: const Text('Create Hospital Admin'))
          ],
        ),
      ),
    );
  }
}
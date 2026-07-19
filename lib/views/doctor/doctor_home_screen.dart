import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/auth/auth_viewmodel.dart';

class DoctorHomeScreen extends ConsumerWidget {
  const DoctorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor home screen'),
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
                  onPressed: () => context.push('/doctor/queue'),
                  label: const Text(
                    'My Queue'
                  )
              ),
            ],
          ),
        )
      ),
    );
  }
}
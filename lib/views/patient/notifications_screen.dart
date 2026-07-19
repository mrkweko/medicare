import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/notification_model.dart';
import '../../repositories/notification_repository.dart';
import '../../viewmodels/auth/auth_viewmodel.dart';

final notificationRepositoryProvider = Provider((ref) => NotificationRepository());

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<NotificationModel>>(
        stream: ref.read(notificationRepositoryProvider).watchMyNotifications(profile.uid),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final notifications = snap.data!;
          if (notifications.isEmpty) return const Center(child: Text('No notifications yet'));

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, i) {
              final n = notifications[i];
              return ListTile(
                leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active, color: n.read ? null : Theme.of(context).colorScheme.primary),
                title: Text(n.message, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                subtitle: n.createdAt != null ? Text(n.createdAt.toString()) : null,
                onTap: () {
                  if (!n.read) ref.read(notificationRepositoryProvider).markAsRead(n.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}
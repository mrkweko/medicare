import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

import '../../models/appointment_model.dart';
import '../../models/department_model.dart';
import '../../models/queue_entry_model.dart';
import '../../repositories/walkin_booking_helper.dart';
import '../../viewmodels/auth/auth_viewmodel.dart';
import '../../viewmodels/patient/booking_viewmodel.dart';
import 'checkin_screen.dart'; // queueRepositoryProvider

class PriorityCheckInScreen extends ConsumerStatefulWidget {
  const PriorityCheckInScreen({super.key});
  @override
  ConsumerState<PriorityCheckInScreen> createState() => _PriorityCheckInScreenState();
}

class _PriorityCheckInScreenState extends ConsumerState<PriorityCheckInScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Priority Check-In'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'New Walk-In Emergency'),
            Tab(text: 'Escalate Existing Patient'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_NewWalkInEmergencyTab(), _EscalateExistingTab()],
      ),
    );
  }
}

class _NewWalkInEmergencyTab extends ConsumerStatefulWidget {
  const _NewWalkInEmergencyTab();
  @override
  ConsumerState<_NewWalkInEmergencyTab> createState() => _NewWalkInEmergencyTabState();
}

class _NewWalkInEmergencyTabState extends ConsumerState<_NewWalkInEmergencyTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _departmentId;
  String _priority = 'critical';
  bool _submitting = false;

  Future<void> _submit(String hospitalId) async {
    if (_nameController.text.trim().isEmpty || _departmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and department are required')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final helper = WalkInBookingHelper(
        appointmentRepository: ref.read(appointmentRepositoryProvider),
        queueRepository: ref.read(queueRepositoryProvider),
      );
      final tokenNumber = await helper.bookAndCheckIn(
        displayName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        hospitalId: hospitalId,
        departmentId: _departmentId!,
        priority: _priority,
      );

      if (mounted) {
        _nameController.clear();
        _phoneController.clear();
        setState(() => _departmentId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Priority check-in complete — token #$tokenNumber')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final hospitalId = profile?.hospitalId;
    if (hospitalId == null) return const Center(child: Text('No hospitalId on profile'));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Patient full name')),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number (optional)'),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<DepartmentModel>>(
            stream: ref.read(bookingDepartmentRepoProvider).watchDepartments(hospitalId),
            builder: (context, snap) {
              final depts = snap.data ?? [];
              return DropdownButtonFormField<String>(
                initialValue: _departmentId,
                decoration: const InputDecoration(labelText: 'Department'),
                items: depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                onChanged: (v) => setState(() => _departmentId = v),
              );
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'critical', label: Text('Critical')),
              ButtonSegment(value: 'urgent', label: Text('Urgent')),
            ],
            selected: {_priority},
            onSelectionChanged: (s) => setState(() => _priority = s.first),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.emergency),
            label: Text(_submitting ? 'Processing...' : 'Priority Check-In'),
            onPressed: _submitting ? null : () => _submit(hospitalId),
          ),
        ],
      ),
    );
  }
}

class _EscalateExistingTab extends ConsumerWidget {
  const _EscalateExistingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final hospitalId = profile?.hospitalId;
    if (hospitalId == null) return const Center(child: Text('No hospitalId on profile'));

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return StreamBuilder<List<DepartmentModel>>(
      stream: ref.read(bookingDepartmentRepoProvider).watchDepartments(hospitalId),
      builder: (context, deptSnap) {
        final depts = deptSnap.data ?? [];
        if (depts.isEmpty) return const Center(child: Text('No departments yet'));

        return DefaultTabController(
          length: depts.length,
          child: Column(
            children: [
              TabBar(isScrollable: true, tabs: depts.map((d) => Tab(text: d.name)).toList()),
              Expanded(
                child: TabBarView(
                  children: depts.map((dept) {
                    return StreamBuilder<List<QueueEntryModel>>(
                      stream: ref.read(queueRepositoryProvider).watchLiveQueue(
                        hospitalId: hospitalId,
                        date: today,
                        departmentId: dept.id,
                      ),
                      builder: (context, snap) {
                        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        final waiting = snap.data!.where((e) => e.status == 'waiting' && e.priority == 'normal').toList();
                        if (waiting.isEmpty) return const Center(child: Text('No normal-priority patients waiting'));

                        return ListView.builder(
                          itemCount: waiting.length,
                          itemBuilder: (context, i) {
                            final e = waiting[i];
                            return ListTile(
                              leading: CircleAvatar(child: Text('#${e.tokenNumber}')),
                              title: Text('Patient: ${e.patientId}'),
                              subtitle: const Text('Priority: normal'),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  TextButton(
                                    onPressed: () => ref.read(queueRepositoryProvider).escalatePriority(
                                      hospitalId: hospitalId,
                                      date: today,
                                      departmentId: dept.id,
                                      entryId: e.id,
                                      newPriority: 'urgent',
                                    ),
                                    child: const Text('→ Urgent'),
                                  ),
                                  TextButton(
                                    onPressed: () => ref.read(queueRepositoryProvider).escalatePriority(
                                      hospitalId: hospitalId,
                                      date: today,
                                      departmentId: dept.id,
                                      entryId: e.id,
                                      newPriority: 'critical',
                                    ),
                                    child: const Text('→ Critical'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
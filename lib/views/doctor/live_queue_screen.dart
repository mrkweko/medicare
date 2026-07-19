import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/department_model.dart';
import '../../models/queue_entry_model.dart';
import '../../repositories/doctor_repository.dart';
import '../../repositories/referral_repository.dart';
import '../../viewmodels/auth/auth_viewmodel.dart';
import '../../viewmodels/patient/booking_viewmodel.dart';
import '../receptionist/checkin_screen.dart'; // queueRepositoryProvider

final _doctorRepoProvider = Provider((ref) => DoctorRepository());
final _referralRepoProvider = Provider((ref) => ReferralRepository());

class LiveQueueScreen extends ConsumerStatefulWidget {
  const LiveQueueScreen({super.key});
  @override
  ConsumerState<LiveQueueScreen> createState() => _LiveQueueScreenState();
}

class _LiveQueueScreenState extends ConsumerState<LiveQueueScreen> {
  bool _callingNext = false;

  Future<void> _handleComplete(QueueEntryModel entry, String hospitalId, String today, String departmentId) async {
    await ref.read(queueRepositoryProvider).updateStatus(
      hospitalId: hospitalId,
      date: today,
      departmentId: departmentId,
      entryId: entry.id,
      status: 'completed',
    );

    if (!mounted) return;

    // Fired the instant Complete is tapped, while we still have the
    // appointmentId in scope — NOT from a later tap on the now-completed
    // entry, since watchLiveQueue() filters completed entries out of the
    // list entirely and any button attached to that state is unreachable.
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Consultation Complete'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'refer'), child: const Text('Refer to Another Department')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'followup'), child: const Text('Schedule Follow-up')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, null), child: const Text('Done, No Further Action')),
        ],
      ),
    );

    if (action == 'refer') {
      await _showReferralDialog(entry, hospitalId, departmentId);
    } else if (action == 'followup') {
      await _showFollowUpDialog(entry.appointmentId);
    }
  }

  Future<void> _showReferralDialog(QueueEntryModel entry, String hospitalId, String currentDepartmentId) async {
    final departments = await ref.read(bookingDepartmentRepoProvider).watchDepartments(hospitalId).first;
    final options = departments.where((d) => d.id != currentDepartmentId).toList();

    if (!mounted) return;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No other departments to refer to')));
      return;
    }

    final selected = await showDialog<DepartmentModel>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Refer to Department'),
        children: options
            .map((d) => SimpleDialogOption(onPressed: () => Navigator.pop(context, d), child: Text(d.name)))
            .toList(),
      ),
    );

    if (selected == null || !mounted) return;

    try {
      final result = await ref.read(_referralRepoProvider).createReferral(
        originAppointmentId: entry.appointmentId,
        targetDepartmentId: selected.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Referred to ${selected.name} — token #${result.tokenNumber}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Referral failed: $e')));
    }
  }

  Future<void> _showFollowUpDialog(String appointmentId) async {
    final daysController = TextEditingController(text: '14');
    final days = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Follow-up'),
        content: TextField(
          controller: daysController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Days from today'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(daysController.text)),
            child: const Text('Schedule'),
          ),
        ],
      ),
    );

    if (days == null || days < 1 || !mounted) return;

    try {
      final result = await ref.read(_referralRepoProvider).createFollowUp(
        originAppointmentId: appointmentId,
        daysFromNow: days,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Follow-up scheduled for ${result.scheduledDate} — token #${result.tokenNumber}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scheduling failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final hospitalId = profile?.hospitalId;
    if (profile == null || hospitalId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Queue")),
      body: StreamBuilder(
        stream: ref.read(_doctorRepoProvider).watchMyDoctorProfile(profile.uid),
        builder: (context, doctorSnap) {
          final doctor = doctorSnap.data;
          if (doctor == null) return const Center(child: CircularProgressIndicator());

          return StreamBuilder<List<QueueEntryModel>>(
            stream: ref.read(queueRepositoryProvider).watchLiveQueue(
              hospitalId: hospitalId,
              date: today,
              departmentId: doctor.departmentId,
            ),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final relevant = snap.data!.where((e) => e.doctorId.isEmpty || e.doctorId == profile.uid).toList();
              final hasActivePatient = relevant.any(
                    (e) => e.doctorId == profile.uid && (e.status == 'called' || e.status == 'in_consultation'),
              );

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.campaign),
                      label: Text(
                        hasActivePatient
                            ? 'Finish current patient first'
                            : (_callingNext ? 'Calling...' : "I'm Ready — Call Next Patient"),
                      ),
                      onPressed: (_callingNext || hasActivePatient)
                          ? null
                          : () async {
                        setState(() => _callingNext = true);
                        try {
                          final result = await ref.read(queueRepositoryProvider).callNextPatient(
                            hospitalId: hospitalId,
                            date: today,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('Now calling token #${result.tokenNumber}')));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        } finally {
                          if (mounted) setState(() => _callingNext = false);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: relevant.isEmpty
                        ? const Center(child: Text('No patients waiting'))
                        : ListView.builder(
                      itemCount: relevant.length,
                      itemBuilder: (context, i) {
                        final e = relevant[i];
                        final isMine = e.doctorId == profile.uid;

                        return ListTile(
                          leading: CircleAvatar(child: Text('#${e.tokenNumber}')),
                          title: Text('Status: ${e.status}'),
                          subtitle: Text('Priority: ${e.priority}${isMine ? ' · assigned to you' : ''}'),
                          trailing: isMine
                              ? Wrap(
                            spacing: 8,
                            children: [
                              if (e.status == 'called') ...[
                                TextButton(
                                  onPressed: () => ref.read(queueRepositoryProvider).updateStatus(
                                    hospitalId: hospitalId,
                                    date: today,
                                    departmentId: doctor.departmentId,
                                    entryId: e.id,
                                    status: 'in_consultation',
                                  ),
                                  child: const Text('Start'),
                                ),
                                TextButton(
                                  onPressed: () => ref.read(queueRepositoryProvider).markSkipped(
                                    hospitalId: hospitalId,
                                    date: today,
                                    departmentId: doctor.departmentId,
                                    entryId: e.id,
                                  ),
                                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                                  child: const Text('Skip'),
                                ),
                              ],
                              if (e.status == 'in_consultation') ...[
                                TextButton(
                                  onPressed: () => ref.read(queueRepositoryProvider).pauseConsultation(
                                    hospitalId: hospitalId,
                                    date: today,
                                    departmentId: doctor.departmentId,
                                    entryId: e.id,
                                  ),
                                  style: TextButton.styleFrom(foregroundColor: Colors.amber.shade800),
                                  child: const Text('Pause'),
                                ),
                                TextButton(
                                  onPressed: () => _handleComplete(e, hospitalId, today, doctor.departmentId),
                                  child: const Text('Complete'),
                                ),
                              ],
                            ],
                          )
                              : null,
                        );
                      },
                    ),
                  ),
                  StreamBuilder<List<QueueEntryModel>>(
                    stream: ref.read(queueRepositoryProvider).watchPausedEntriesForDoctor(
                      hospitalId: hospitalId,
                      date: today,
                      departmentId: doctor.departmentId,
                      doctorId: profile.uid,
                    ),
                    builder: (context, pausedSnap) {
                      final paused = pausedSnap.data ?? [];
                      if (paused.isEmpty) return const SizedBox.shrink();
                      return Container(
                        color: Colors.amber.shade50,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Text('Paused', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            ...paused.map((e) => ListTile(
                              dense: true,
                              leading: CircleAvatar(child: Text('#${e.tokenNumber}')),
                              title: const Text('Paused mid-consultation'),
                              trailing: FilledButton(
                                onPressed: () => ref.read(queueRepositoryProvider).resumeConsultation(
                                  hospitalId: hospitalId,
                                  date: today,
                                  departmentId: doctor.departmentId,
                                  entryId: e.id,
                                ),
                                child: const Text('Resume'),
                              ),
                            )),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../viewmodels/patient/booking_viewmodel.dart';

class DateTimeConfirmScreen extends ConsumerStatefulWidget {
  const DateTimeConfirmScreen({
    super.key,
    required this.hospitalId,
    required this.hospitalName,
    required this.departmentId,
    required this.departmentName,
  });

  final String hospitalId;
  final String hospitalName;
  final String departmentId;
  final String departmentName;

  @override
  ConsumerState<DateTimeConfirmScreen> createState() => _DateTimeConfirmScreenState();
}

class _DateTimeConfirmScreenState extends ConsumerState<DateTimeConfirmScreen> {
  DateTime _date = DateTime.now();
  String? _selectedSlot;
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingControllerProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);

    return Scaffold(
      appBar: AppBar(title: const Text('Date & Time')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR SELECTION', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text(widget.departmentName, style: Theme.of(context).textTheme.titleMedium),
                    Text(widget.hospitalName, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "This is a booking slot — your exact queue position is assigned when you check in. A doctor is assigned in real time when you're called, not in advance.",
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Select Date', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                title: Text(DateFormat('EEEE, MMM d, yyyy').format(_date)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setState(() {
                      _date = picked;
                      _selectedSlot = null;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
            Text('Select Time Slot', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            FutureBuilder<List<({String slot, int remaining})>>(
              future: ref.read(appointmentRepositoryProvider).getAvailableSlots(
                hospitalId: widget.hospitalId,
                departmentId: widget.departmentId,
                date: dateStr,
              ),
              builder: (context, snap) {
                if (snap.hasError) return Text('Error loading slots: ${snap.error}');
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final slots = snap.data!;
                if (slots.isEmpty) return const Text('No slots configured for this date');
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: slots.map((s) {
                    final full = s.remaining <= 0;
                    final selected = _selectedSlot == s.slot;
                    return ChoiceChip(
                      label: Text(full ? '${s.slot} · Full' : s.slot),
                      selected: selected,
                      onSelected: full ? null : (_) => setState(() => _selectedSlot = s.slot),
                      disabledColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      labelStyle: TextStyle(color: full ? AppColors.textSecondary.withValues(alpha: 0.5) : null),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Booking Summary', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  const Divider(height: 1),
                  _SummaryRow(icon: Icons.local_hospital_outlined, label: 'Hospital', value: widget.hospitalName),
                  _SummaryRow(icon: Icons.category_outlined, label: 'Department', value: widget.departmentName),
                  const _SummaryRow(icon: Icons.person_outline, label: 'Doctor', value: 'Assigned when called'),
                  _SummaryRow(icon: Icons.calendar_today_outlined, label: 'Date', value: DateFormat('EEEE, d MMM yyyy').format(_date)),
                  _SummaryRow(icon: Icons.access_time, label: 'Slot', value: _selectedSlot ?? '—', isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: (bookingState.isLoading || _confirming)
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Booking'),
              onPressed: (_selectedSlot == null || bookingState.isLoading || _confirming)
                  ? null
                  : () async {
                setState(() => _confirming = true);

                final result = await ref.read(bookingControllerProvider.notifier).book(
                  hospitalId: widget.hospitalId,
                  departmentId: widget.departmentId,
                  scheduledDate: dateStr,
                  scheduledTimeSlot: _selectedSlot,
                );

                if (result == null) {
                  if (mounted) {
                    setState(() => _confirming = false);
                    final error = ref.read(bookingControllerProvider).error;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error?.toString() ?? 'Booking failed')));
                  }
                  return;
                }

                // Fetch the real, server-populated appointment back
                // rather than hand-constructing one — this is what
                // guarantees patientName/patientPhoneNumber shown on
                // the QR screen match what's actually in the database.
                final appointment = await ref.read(appointmentRepositoryProvider).fetchAppointmentById(result.appointmentId);

                if (!mounted) return;
                setState(() => _confirming = false);

                if (appointment == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booked, but could not load confirmation details.')),
                  );
                  context.go('/patient/home');
                  return;
                }

                context.pushReplacement('/patient/appointment-qr', extra: appointment);
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'You can reschedule up to 2 hours before your slot',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label, required this.value, this.isLast = false});
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(color: AppColors.textSecondary))),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
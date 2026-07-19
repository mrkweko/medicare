import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/department_model.dart';
import '../../viewmodels/patient/booking_viewmodel.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});
  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  String? _hospitalId;
  String? _departmentId;
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final hospitalsAsync = ref.watch(bookingHospitalRepoProvider).watchHospitals();
    final bookingState = ref.watch(bookingControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder(
              stream: hospitalsAsync,
              builder: (context, snap) {
                final hospitals = snap.data ?? [];
                return DropdownButtonFormField<String>(
                  initialValue: _hospitalId,
                  decoration: const InputDecoration(labelText: 'Hospital'),
                  items: hospitals.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))).toList(),
                  onChanged: (v) => setState(() {
                    _hospitalId = v;
                    _departmentId = null;
                  }),
                );
              },
            ),
            const SizedBox(height: 12),
            if (_hospitalId != null)
              StreamBuilder<List<DepartmentModel>>(
                stream: ref.read(bookingDepartmentRepoProvider).watchDepartments(_hospitalId!),
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
            ListTile(
              title: Text('Date: ${DateFormat('yyyy-MM-dd').format(_date)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_hospitalId == null || _departmentId == null || bookingState.isLoading)
                  ? null
                  : () async {
                final result = await ref.read(bookingControllerProvider.notifier).book(
                  hospitalId: _hospitalId!,
                  departmentId: _departmentId!,
                  scheduledDate: DateFormat('yyyy-MM-dd').format(_date),
                );
                if (result != null && mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Appointment Confirmed'),
                      content: Text('Your token number is #${result.tokenNumber}. A doctor will be assigned when you\'re called.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                    ),
                  );
                } else if (mounted) {
                  final error = ref.read(bookingControllerProvider).error;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error?.toString() ?? 'Booking failed')));
                }
              },
              child: bookingState.isLoading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Confirm Booking'),
            ),
          ],
        ),
      ),
    );
  }
}
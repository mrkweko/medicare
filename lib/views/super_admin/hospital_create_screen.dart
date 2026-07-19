import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/super_admin/hospital_management_viewmodel.dart';

class HospitalCreateScreen extends ConsumerStatefulWidget {
  const HospitalCreateScreen({super.key});

  @override
  ConsumerState<HospitalCreateScreen> createState() => _HospitalCreateScreenState();
}

class _HospitalCreateScreenState extends ConsumerState<HospitalCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(hospitalCreateControllerProvider.notifier).create(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      contactInfo: _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
    );
    if (success && mounted) {
      _nameController.clear();
      _addressController.clear();
      _contactController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hospital created')));
    } else if (!success && mounted) {
      final error = ref.read(hospitalCreateControllerProvider).error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error?.toString() ?? 'Failed to create hospital')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(hospitalCreateControllerProvider);
    final hospitalsAsync = ref.watch(hospitalsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Hospital')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Hospital name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(labelText: 'Contact info (optional)'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: createState.isLoading ? null : _submit,
                    child: createState.isLoading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create Hospital'),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Text('Existing hospitals', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: hospitalsAsync.when(
                data: (hospitals) => hospitals.isEmpty
                    ? const Center(child: Text('No hospitals yet'))
                    : ListView.builder(
                  itemCount: hospitals.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(hospitals[i].name),
                    subtitle: Text(hospitals[i].address),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/super_admin/hospital_management_viewmodel.dart';
import '../../viewmodels/super_admin/staff_management_viewmodel.dart';

class HospitalAdminCreateScreen extends ConsumerStatefulWidget {
  const HospitalAdminCreateScreen({super.key});

  @override
  ConsumerState<HospitalAdminCreateScreen> createState() => _HospitalAdminCreateScreenState();
}

class _HospitalAdminCreateScreenState extends ConsumerState<HospitalAdminCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedHospitalId;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHospitalId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a hospital first')));
      return;
    }

    final success = await ref.read(staffCreateControllerProvider.notifier).create(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: 'hospital_admin',
      displayName: _nameController.text.trim(),
      hospitalId: _selectedHospitalId,
    );

    if (success && mounted) {
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hospital admin created')));
    } else if (!success && mounted) {
      final error = ref.read(staffCreateControllerProvider).error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error?.toString() ?? 'Failed to create account')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(staffCreateControllerProvider);
    final hospitalsAsync = ref.watch(hospitalsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Hospital Admin')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              hospitalsAsync.when(
                data: (hospitals) => DropdownButtonFormField<String>(
                  initialValue: _selectedHospitalId,
                  decoration: const InputDecoration(labelText: 'Hospital'),
                  items: hospitals
                      .map((h) => DropdownMenuItem(value: h.id, child: Text(h.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedHospitalId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed to load hospitals: $e'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Temporary password'),
                validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: createState.isLoading ? null : _submit,
                child: createState.isLoading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create Hospital Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
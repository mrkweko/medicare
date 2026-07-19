import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/department_repository.dart';
import '../../viewmodels/auth/auth_viewmodel.dart';

final departmentRepositoryProvider = Provider((ref) => DepartmentRepository());

class DepartmentCreateScreen extends ConsumerStatefulWidget {
  const DepartmentCreateScreen({super.key});
  @override
  ConsumerState<DepartmentCreateScreen> createState() => _DepartmentCreateScreenState();
}

class _DepartmentCreateScreenState extends ConsumerState<DepartmentCreateScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  Future<void> _submit(String hospitalId) async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(departmentRepositoryProvider).createDepartment(hospitalId: hospitalId, name: _controller.text.trim());
      _controller.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department added')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final hospitalId = profile?.hospitalId;

    if (hospitalId == null) return const Scaffold(body: Center(child: Text('No hospitalId on profile')));

    final departmentsAsync = ref.watch(departmentRepositoryProvider).watchDepartments(hospitalId);

    return Scaffold(
      appBar: AppBar(title: const Text('Departments')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(labelText: 'Department name'))),
              const SizedBox(width: 8),
              FilledButton(onPressed: _loading ? null : () => _submit(hospitalId), child: const Text('Add')),
            ]),
            const Divider(height: 32),
            Expanded(
              child: StreamBuilder(
                stream: departmentsAsync,
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final depts = snap.data!;
                  return ListView.builder(
                    itemCount: depts.length,
                    itemBuilder: (context, i) => ListTile(title: Text(depts[i].name)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
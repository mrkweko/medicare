import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/hospital_repository.dart';

final hospitalRepositoryProvider = Provider<HospitalRepository>((ref) => HospitalRepository());

final hospitalsListProvider = StreamProvider<List<HospitalModel>>((ref) {
  return ref.watch(hospitalRepositoryProvider).watchHospitals();
});

class HospitalCreateController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> create({
    required String name,
    required String address,
    String? contactInfo,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(hospitalRepositoryProvider)
          .createHospital(name: name, address: address, contactInfo: contactInfo);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final hospitalCreateControllerProvider =
AsyncNotifierProvider<HospitalCreateController, void>(HospitalCreateController.new);
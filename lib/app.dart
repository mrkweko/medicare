import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hospital_queue_app/views/admin/department_create_screen.dart';
import 'package:hospital_queue_app/views/admin/doctor_list_screen.dart';
import 'package:hospital_queue_app/views/admin/skip_rejoin_policy_screen.dart';
import 'package:hospital_queue_app/views/admin/staff_create_screen.dart';
import 'package:hospital_queue_app/views/doctor/live_queue_screen.dart';
import 'package:hospital_queue_app/views/patient/booking_screen.dart';
import 'package:hospital_queue_app/views/patient/my_appointments_screen.dart';
import 'package:hospital_queue_app/views/patient/notifications_screen.dart';
import 'package:hospital_queue_app/views/receptionist/checkin_screen.dart';
import 'package:hospital_queue_app/views/receptionist/priority_checkin_screen.dart';
import 'package:hospital_queue_app/views/receptionist/skipped_patients_screen.dart';
import 'package:hospital_queue_app/views/receptionist/walk_in_booking_screen.dart';
import 'package:hospital_queue_app/views/super_admin/hospital_admin_create_screen.dart';
import 'package:hospital_queue_app/views/super_admin/hospital_create_screen.dart';

import 'core/theme/app_theme.dart';
import 'models/user_model.dart';
import 'router/router_refresh_notifier.dart';
import 'viewmodels/auth/auth_viewmodel.dart';
import 'views/admin/hospital_admin_home_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/signup_screen.dart';
import 'views/doctor/doctor_home_screen.dart';
import 'views/patient/patient_home_screen.dart';
import 'views/receptionist/receptionist_home_screen.dart';
import 'views/splash_screen.dart';
import 'views/super_admin/super_admin_home_screen.dart';

String _basePathForRole(AppRole role) {
  switch (role) {
    case AppRole.patient:
      return '/patient';
    case AppRole.receptionist:
      return '/receptionist';
    case AppRole.doctor:
      return '/doctor';
    case AppRole.hospitalAdmin:
      return '/admin';
    case AppRole.superAdmin:
      return '/super-admin';
  }
}

String _homePathForRole(AppRole role) => '${_basePathForRole(role)}/home';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final path = state.matchedLocation;
      debugPrint('[router] redirect check for $path, currentUser=${ref.read(authStateChangesProvider).value?.uid}');
      final isAuthRoute = path == '/login' || path == '/signup';
      final isSplash = path == '/splash';

      final authAsync = ref.read(authStateChangesProvider);

      // Still resolving whether anyone is signed in at all.
      if (authAsync.isLoading) {
        return isSplash ? null : '/splash';
      }

      final firebaseUser = authAsync.value;
      if (firebaseUser == null) {
        return isAuthRoute ? null : '/login';
      }

      // Signed in — now resolve their role/hospitalId from Firestore.
      final profileAsync = ref.read(currentUserProfileProvider);
      if (profileAsync.isLoading) {
        return isSplash ? null : '/splash';
      }

      final profile = profileAsync.value;
      if (profile == null) {
        // Auth account exists but users/{uid} doc doesn't — an orphaned
        // account (see the earlier permission-denied bug) or the profile
        // was deleted. Can't route by role with nothing to route by.
        return '/login';
      }

      final basePath = _basePathForRole(profile.role);
      final homePath = '$basePath/home';

      if (isAuthRoute || isSplash) return homePath;

      // Signed in but sitting on a path outside their role's area — e.g.
      // typed a URL directly, or their role changed mid-session via a
      // manual Firestore edit and refreshListenable just fired.
      if (!path.startsWith(basePath)) return homePath;

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/patient/home', builder: (context, state) => const PatientHomeScreen()),
      GoRoute(path: '/receptionist/home', builder: (context, state) => const ReceptionistHomeScreen()),
      GoRoute(path: '/doctor/home', builder: (context, state) => const DoctorHomeScreen()),
      GoRoute(path: '/admin/home', builder: (context, state) => const HospitalAdminHomeScreen()),
      GoRoute(path: '/super-admin/home', builder: (context, state) => const SuperAdminHomeScreen()),
      GoRoute(path: '/super-admin/hospitals/create', builder: (context, state) => const HospitalCreateScreen()),
      GoRoute(path: '/super-admin/staff/create-hospital-admin', builder: (context, state) => const HospitalAdminCreateScreen()),
      GoRoute(path: '/admin/staff/create', builder: (context, state) => const StaffCreateScreen()),
      GoRoute(path: '/patient/book', builder: (context, state) => const BookingScreen()),
      GoRoute(path: '/patient/appointments', builder: (context, state) => const MyAppointmentsScreen()),
      GoRoute(path: '/receptionist/checkin', builder: (context, state) => const CheckInScreen()),
      GoRoute(path: '/doctor/queue', builder: (context, state) => const LiveQueueScreen()),
      GoRoute(path: '/admin/departments', builder: (context, state) => const DepartmentCreateScreen()),
      GoRoute(path: '/patient/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/receptionist/priority-checkin', builder: (context, state) => const PriorityCheckInScreen()),
      GoRoute(path: '/admin/skip-policy', builder: (context, state) => const SkipPolicyScreen()),
      GoRoute(path: '/receptionist/skipped', builder: (context, state) => const SkippedPatientsScreen()),
      GoRoute(path: '/receptionist/walkin-booking', builder: (context, state) => const WalkInBookingScreen()),
      GoRoute(path: '/admin/doctors', builder: (context, state) => const DoctorListScreen()),
    ],
  );
});

class HospitalQueueApp extends ConsumerWidget {
  const HospitalQueueApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Hospital Queue',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      routerConfig: router,
    );
  }
}
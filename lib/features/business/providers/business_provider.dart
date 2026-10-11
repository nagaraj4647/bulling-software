import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/business_service.dart';
import '../models/business_model.dart';

final businessServiceProvider = Provider<BusinessService>((ref) {
  return BusinessService();
});

// A provider that caches the current user's business
final currentBusinessProvider = FutureProvider<BusinessModel?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return null;
  }

  final businessService = ref.read(businessServiceProvider);
  return await businessService.getBusinessForOwner(user.uid);
});

class BusinessController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> createBusiness(BusinessModel business) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final businessService = ref.read(businessServiceProvider);
      await businessService.createBusiness(business);

      // Invalidate the cache to fetch the new business on the next read
      ref.invalidate(currentBusinessProvider);
    });
  }

  Future<void> updateBusiness(BusinessModel business) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final businessService = ref.read(businessServiceProvider);
      await businessService.updateBusiness(business);

      ref.invalidate(currentBusinessProvider);
    });
  }
}

final businessControllerProvider =
    AsyncNotifierProvider<BusinessController, void>(BusinessController.new);

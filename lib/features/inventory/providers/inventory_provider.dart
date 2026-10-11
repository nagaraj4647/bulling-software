import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/providers/business_provider.dart';
import '../data/inventory_service.dart';
import '../models/inventory_transaction_model.dart';
import '../../auth/providers/auth_provider.dart';

final inventoryServiceProvider = Provider<InventoryService?>((ref) {
  final business = ref.watch(currentBusinessProvider).value;
  if (business == null || business.businessId == null) return null;
  return InventoryService(business.businessId!);
});

final inventoryTransactionsProvider =
    StreamProvider.family<List<InventoryTransactionModel>, String>((
      ref,
      productId,
    ) {
      final service = ref.watch(inventoryServiceProvider);
      if (service == null) return const Stream.empty();
      return service.getTransactionHistory(productId);
    });

class InventoryController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> adjustStock({
    required String productId,
    required String type,
    required double quantity,
    required String reason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(inventoryServiceProvider);
      if (service == null) throw Exception('Inventory service not available');

      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('User not authenticated');

      await service.adjustStock(
        productId: productId,
        type: type,
        quantity: quantity,
        reason: reason,
        userId: user.uid,
      );
    });
  }
}

final inventoryControllerProvider =
    AsyncNotifierProvider<InventoryController, void>(InventoryController.new);

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/providers/business_provider.dart';
import '../data/product_service.dart';
import '../models/product_model.dart';

final productServiceProvider = Provider<ProductService?>((ref) {
  final business = ref.watch(currentBusinessProvider).value;
  if (business == null || business.businessId == null) return null;
  return ProductService(business.businessId!);
});

final productsProvider = StreamProvider<List<ProductModel>>((ref) {
  final service = ref.watch(productServiceProvider);
  if (service == null) return const Stream.empty();
  return service.getProducts();
});

class ProductController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> createProduct(
    ProductModel product, {
    double openingStock = 0,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(productServiceProvider);
      if (service == null) throw Exception('Product service not available');
      await service.createProduct(product, openingStock: openingStock);
    });
  }

  Future<void> updateProduct(ProductModel product) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(productServiceProvider);
      if (service == null) throw Exception('Product service not available');
      await service.updateProduct(product);
    });
  }

  Future<void> deactivateProduct(String productId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(productServiceProvider);
      if (service == null) throw Exception('Product service not available');
      await service.deactivateProduct(productId);
    });
  }

  Future<int?> seedSampleProducts() async {
    state = const AsyncLoading();
    int? addedCount;
    state = await AsyncValue.guard(() async {
      final service = ref.read(productServiceProvider);
      if (service == null) throw Exception('Product service not available');
      addedCount = await service.seedSampleProducts();
    });
    return addedCount;
  }
}

final productControllerProvider =
    AsyncNotifierProvider<ProductController, void>(ProductController.new);

enum ProductFilter { all, active, inactive, lowStock }

class ProductFilterNotifier extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => ProductFilter.all;
  void setFilter(ProductFilter filter) => state = filter;
}

final productFilterProvider =
    NotifierProvider<ProductFilterNotifier, ProductFilter>(
      ProductFilterNotifier.new,
    );

class ProductSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
}

final productSearchQueryProvider =
    NotifierProvider<ProductSearchQueryNotifier, String>(
      ProductSearchQueryNotifier.new,
    );

final filteredProductsProvider = Provider<List<ProductModel>>((ref) {
  final products = ref.watch(productsProvider).value ?? [];
  final filter = ref.watch(productFilterProvider);
  final query = ref.watch(productSearchQueryProvider).toLowerCase();

  return products.where((p) {
    // Text search
    final matchesQuery =
        query.isEmpty ||
        p.name.toLowerCase().contains(query) ||
        (p.sku?.toLowerCase().contains(query) ?? false) ||
        (p.barcode?.toLowerCase().contains(query) ?? false);

    if (!matchesQuery) return false;

    // Status / Low Stock filter
    switch (filter) {
      case ProductFilter.all:
        return true;
      case ProductFilter.active:
        return p.isActive;
      case ProductFilter.inactive:
        return !p.isActive;
      case ProductFilter.lowStock:
        return p.isActive && p.stockQuantity <= p.lowStockThreshold;
    }
  }).toList();
});

final lowStockProductsProvider = StreamProvider<List<ProductModel>>((ref) {
  final service = ref.watch(productServiceProvider);
  if (service == null) return const Stream.empty();

  // We stream the absolute lowest 20 active products,
  // and locally filter for the ones where stock <= threshold.
  // This keeps the widget performant without modifying architecture.
  return service.getLowestStockProductsStream(limit: 20).map((products) {
    return products
        .where((p) => p.stockQuantity <= p.lowStockThreshold)
        .take(5)
        .toList();
  });
});

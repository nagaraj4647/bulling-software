import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_formatter.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../../business/providers/business_provider.dart';
import '../../../core/theme/app_theme.dart';

import 'package:flutter_animate/flutter_animate.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId; // If null, we are adding. If provided, editing.

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _unitController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _openingStockController;
  late final TextEditingController _lowStockController;
  late final TextEditingController _gstController;

  bool _isActive = true;
  bool _isInit = false;
  ProductModel? _editingProduct;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _skuController = TextEditingController();
    _barcodeController = TextEditingController();
    _categoryController = TextEditingController();
    _unitController = TextEditingController();
    _purchasePriceController = TextEditingController(text: '0');
    _sellingPriceController = TextEditingController(text: '0');
    _openingStockController = TextEditingController(text: '0');
    _lowStockController = TextEditingController(text: '0');
    _gstController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _openingStockController.dispose();
    _lowStockController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  void _loadProduct(List<ProductModel> products) {
    if (_isInit || widget.productId == null) return;

    try {
      _editingProduct = products.firstWhere(
        (p) => p.productId == widget.productId,
      );
      _nameController.text = _editingProduct!.name;
      _skuController.text = _editingProduct!.sku ?? '';
      _barcodeController.text = _editingProduct!.barcode ?? '';
      _categoryController.text = _editingProduct!.category ?? '';
      _unitController.text = _editingProduct!.unit ?? '';
      _purchasePriceController.text = _editingProduct!.purchasePrice.toString();
      _sellingPriceController.text = _editingProduct!.sellingPrice.toString();
      _openingStockController.text = _editingProduct!.stockQuantity.toString(); // Opening stock field becomes non-editable or ignored on update
      _lowStockController.text = _editingProduct!.lowStockThreshold.toString();
      _gstController.text = _editingProduct!.gstRate.toString();
      _isActive = _editingProduct!.isActive;
      _isInit = true;
    } catch (_) {
      // Product not found
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final business = ref.read(currentBusinessProvider).value;
      if (business == null) return;

      final isEditing = _editingProduct != null;

      final product = ProductModel(
        productId: _editingProduct?.productId,
        businessId: business.businessId!,
        name: _nameController.text.trim(),
        sku: _skuController.text.trim().isEmpty
            ? null
            : _skuController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        unit: _unitController.text.trim().isEmpty
            ? null
            : _unitController.text.trim(),
        purchasePrice: double.parse(_purchasePriceController.text.trim()),
        sellingPrice: double.parse(_sellingPriceController.text.trim()),
        stockQuantity: isEditing
            ? _editingProduct!.stockQuantity
            : double.parse(_openingStockController.text.trim()),
        lowStockThreshold: double.parse(_lowStockController.text.trim()),
        gstRate: double.parse(_gstController.text.trim()),
        isActive: _isActive,
      );

      final controller = ref.read(productControllerProvider.notifier);

      if (isEditing) {
        await controller.updateProduct(product);
      } else {
        await controller.createProduct(
          product,
          openingStock: product.stockQuantity,
        );
      }

      if (mounted) {
        final state = ref.read(productControllerProvider);
        if (!state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Product updated' : 'Product added'),
            ),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${ErrorFormatter.format(state.error)}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deactivate() async {
    if (_editingProduct?.productId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Product?'),
        content: const Text(
          'This product will no longer be available for new transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Deactivate',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref
          .read(productControllerProvider.notifier)
          .deactivateProduct(_editingProduct!.productId!);
      if (mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsProvider);
    final controllerState = ref.watch(productControllerProvider);
    final theme = Theme.of(context);
    final isEditing = widget.productId != null;

    if (isEditing) {
      productsState.whenData(_loadProduct);
    }

    if (isEditing && !_isInit && productsState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          if (isEditing && _isActive)
            IconButton(
              icon: const Icon(Icons.block, color: Colors.red),
              tooltip: 'Deactivate',
              onPressed: _deactivate,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                shadowColor: Colors.black.withAlpha(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _skuController,
                              decoration: const InputDecoration(
                                labelText: 'SKU',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _barcodeController,
                              decoration: const InputDecoration(
                                labelText: 'Barcode',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _categoryController,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _unitController,
                              decoration: const InputDecoration(
                                labelText: 'Unit (e.g. kg, pcs)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _purchasePriceController,
                              decoration: const InputDecoration(
                                labelText: 'Purchase Price *',
                                border: OutlineInputBorder(),
                                prefixText: '₹',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val == null || val.isEmpty)
                                  return 'Required';
                                final num = double.tryParse(val);
                                if (num == null || num < 0)
                                  return 'Invalid >= 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _sellingPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Selling Price *',
                                border: OutlineInputBorder(),
                                prefixText: '₹',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val == null || val.isEmpty)
                                  return 'Required';
                                final num = double.tryParse(val);
                                if (num == null || num < 0)
                                  return 'Invalid >= 0';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _openingStockController,
                              decoration: const InputDecoration(
                                labelText: 'Opening Stock',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              enabled: !isEditing, // Cannot change opening stock once created directly here
                              validator: (val) {
                                if (val == null || val.isEmpty) return null;
                                final num = double.tryParse(val);
                                if (num == null || num < 0)
                                  return 'Invalid >= 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _lowStockController,
                              decoration: const InputDecoration(
                                labelText: 'Low Stock Alert',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val == null || val.isEmpty)
                                  return 'Required';
                                final num = double.tryParse(val);
                                if (num == null || num < 0)
                                  return 'Invalid >= 0';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _gstController,
                        decoration: const InputDecoration(
                          labelText: 'GST Rate (%)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          final num = double.tryParse(val);
                          if (num == null || num < 0) return 'Invalid >= 0';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ).animate().fade().slideY(begin: 0.1, delay: 100.ms),
              const SizedBox(height: 16),
              if (isEditing)
                SwitchListTile(
                  title: const Text('Active Status'),
                  subtitle: const Text('Inactive products cannot be sold'),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: controllerState.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: controllerState.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

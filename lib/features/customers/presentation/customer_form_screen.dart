import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_formatter.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import '../../business/providers/business_provider.dart';
import '../../../core/theme/app_theme.dart';

import 'package:flutter_animate/flutter_animate.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final String? customerId;

  const CustomerFormScreen({super.key, this.customerId});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _altPhoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _gstController;
  late final TextEditingController _openingBalanceController;
  late final TextEditingController _creditLimitController;
  late final TextEditingController _notesController;

  bool _isActive = true;
  bool _isInit = false;
  CustomerModel? _editingCustomer;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _altPhoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _pincodeController = TextEditingController();
    _gstController = TextEditingController();
    _openingBalanceController = TextEditingController(text: '0');
    _creditLimitController = TextEditingController(text: '0');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _gstController.dispose();
    _openingBalanceController.dispose();
    _creditLimitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadCustomer(List<CustomerModel> customers) {
    if (_isInit || widget.customerId == null) return;

    try {
      _editingCustomer = customers.firstWhere(
        (c) => c.customerId == widget.customerId,
      );
      _nameController.text = _editingCustomer!.name;
      _phoneController.text = _editingCustomer!.phone ?? '';
      _altPhoneController.text = _editingCustomer!.alternatePhone ?? '';
      _emailController.text = _editingCustomer!.email ?? '';
      _addressController.text = _editingCustomer!.address ?? '';
      _cityController.text = _editingCustomer!.city ?? '';
      _stateController.text = _editingCustomer!.state ?? '';
      _pincodeController.text = _editingCustomer!.pincode ?? '';
      _gstController.text = _editingCustomer!.gstNumber ?? '';
      _openingBalanceController.text = _editingCustomer!.openingBalance
          .toString();
      _creditLimitController.text = _editingCustomer!.creditLimit.toString();
      _notesController.text = _editingCustomer!.notes ?? '';
      _isActive = _editingCustomer!.isActive;
      _isInit = true;
    } catch (_) {
      // Not found
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final business = ref.read(currentBusinessProvider).value;
      if (business == null) return;

      final isEditing = _editingCustomer != null;

      final openingBalance = double.parse(
        _openingBalanceController.text.trim(),
      );
      final creditLimit = double.parse(_creditLimitController.text.trim());

      final CustomerModel customer;

      if (isEditing) {
        // Edit: preserve immutable fields from existing document
        customer = CustomerModel(
          customerId: _editingCustomer!.customerId,
          businessId: _editingCustomer!.businessId,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          alternatePhone: _altPhoneController.text.trim().isEmpty
              ? null
              : _altPhoneController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty
              ? null
              : _stateController.text.trim(),
          pincode: _pincodeController.text.trim().isEmpty
              ? null
              : _pincodeController.text.trim(),
          gstNumber: _gstController.text.trim().isEmpty
              ? null
              : _gstController.text.trim(),
          openingBalance: _editingCustomer!.openingBalance,
          outstandingBalance: _editingCustomer!.outstandingBalance,
          creditLimit: creditLimit,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          isActive: _isActive,
          createdAt: _editingCustomer!.createdAt,
        );
      } else {
        // Create: outstandingBalance = openingBalance (enforced by Firestore rules)
        customer = CustomerModel(
          businessId: business.businessId!,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          alternatePhone: _altPhoneController.text.trim().isEmpty
              ? null
              : _altPhoneController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty
              ? null
              : _stateController.text.trim(),
          pincode: _pincodeController.text.trim().isEmpty
              ? null
              : _pincodeController.text.trim(),
          gstNumber: _gstController.text.trim().isEmpty
              ? null
              : _gstController.text.trim(),
          openingBalance: openingBalance,
          outstandingBalance: openingBalance,
          creditLimit: creditLimit,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          isActive: true,
        );
      }

      final controller = ref.read(customerControllerProvider.notifier);

      if (isEditing) {
        await controller.updateCustomer(customer);
      } else {
        await controller.createCustomer(customer);
      }

      if (mounted) {
        final state = ref.read(customerControllerProvider);
        if (!state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Customer updated' : 'Customer added'),
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

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customersProvider);
    final controllerState = ref.watch(customerControllerProvider);
    final theme = Theme.of(context);
    final isEditing = widget.customerId != null;

    if (isEditing) {
      customersState.whenData(_loadCustomer);
    }

    if (isEditing && !_isInit && customersState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Customer' : 'Add Customer')),
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
                        'Customer Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name *',
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
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (val) {
                                if (val != null &&
                                    val.trim().isNotEmpty &&
                                    val.trim().length < 7) {
                                  return 'Invalid phone';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _altPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'Alternate Phone',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val != null &&
                              val.trim().isNotEmpty &&
                              !val.contains('@')) {
                            return 'Invalid email';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ).animate().fade().slideY(begin: 0.1, delay: 0.ms),
              const SizedBox(height: 16),
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
                        'Address Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'City',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _stateController,
                              decoration: const InputDecoration(
                                labelText: 'State',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _pincodeController,
                              decoration: const InputDecoration(
                                labelText: 'Pincode',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val != null &&
                                    val.trim().isNotEmpty &&
                                    int.tryParse(val.trim()) == null) {
                                  return 'Numbers only';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fade().slideY(begin: 0.1, delay: 50.ms),
              const SizedBox(height: 16),
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
                        'Financial & Additional',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _gstController,
                        decoration: const InputDecoration(
                          labelText: 'GST Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _openingBalanceController,
                              decoration: InputDecoration(
                                labelText: 'Opening Balance (₹)',
                                border: const OutlineInputBorder(),
                                helperText: isEditing
                                    ? 'Cannot be changed after creation'
                                    : null,
                              ),
                              keyboardType: TextInputType.number,
                              readOnly: isEditing,
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
                              controller: _creditLimitController,
                              decoration: const InputDecoration(
                                labelText: 'Credit Limit (₹)',
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
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ).animate().fade().slideY(begin: 0.1, delay: 100.ms),
              const SizedBox(height: 16),
              if (isEditing)
                SwitchListTile(
                  title: const Text('Active Status'),
                  subtitle: const Text('Inactive customers cannot be billed'),
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
                    : const Text('Save Customer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

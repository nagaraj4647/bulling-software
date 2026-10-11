import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/business_model.dart';
import '../providers/business_provider.dart';

class BusinessSetupPage extends ConsumerStatefulWidget {
  const BusinessSetupPage({super.key});

  @override
  ConsumerState<BusinessSetupPage> createState() => _BusinessSetupPageState();
}

class _BusinessSetupPageState extends ConsumerState<BusinessSetupPage> {
  final _formKey = GlobalKey<FormState>();

  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _gstController = TextEditingController();

  String? _selectedBusinessType;
  bool _isGstInclusive = false;

  final List<String> _businessTypes = [
    'Retail Shop',
    'Supermarket',
    'Grocery Store',
    'Clothing Store',
    'Tailoring',
    'Restaurant',
    'Electronics',
    'Pharmacy',
    'Hardware',
    'Salon',
    'Other',
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedBusinessType != null) {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final business = BusinessModel(
        ownerId: user.uid,
        businessName: _businessNameController.text.trim(),
        businessType: _selectedBusinessType!,
        ownerName: _ownerNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        businessState: _stateController.text.trim().isEmpty
            ? null
            : _stateController.text.trim(),
        gstNumber: _gstController.text.trim().isEmpty
            ? null
            : _gstController.text.trim(),
        isGstInclusive: _isGstInclusive,
      );

      await ref
          .read(businessControllerProvider.notifier)
          .createBusiness(business);

      if (mounted) {
        final state = ref.read(businessControllerProvider);
        if (!state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Business saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/dashboard');
        }
      }
    } else if (_selectedBusinessType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a business type'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(businessControllerProvider);
    final theme = Theme.of(context);

    ref.listen<AsyncValue<void>>(businessControllerProvider, (_, state) {
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save business: ${ErrorFormatter.format(state.error)}',
            ),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Your Business')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with logo
                    Center(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/icon/new_logo.png',
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Let\'s set up your business',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fill in the details below to get started',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Business Info Section
                    _SectionCard(
                      icon: Icons.storefront,
                      title: 'Business Information',
                      children: [
                        TextFormField(
                          controller: _businessNameController,
                          decoration: const InputDecoration(
                            labelText: 'Business Name',
                            prefixIcon: Icon(Icons.business),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().length < 2) {
                              return 'Business Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Business Type',
                            prefixIcon: Icon(Icons.category),
                          ),
                          initialValue: _selectedBusinessType,
                          items: _businessTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBusinessType = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a business type';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Contact Section
                    _SectionCard(
                      icon: Icons.contact_phone,
                      title: 'Contact Details',
                      children: [
                        TextFormField(
                          controller: _ownerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Owner Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Owner Name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().length < 7) {
                              return 'Please enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Location Section
                    _SectionCard(
                      icon: Icons.location_on_outlined,
                      title: 'Location',
                      children: [
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                          textInputAction: TextInputAction.next,
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.trim().length < 5) {
                              return 'Address must be at least 5 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _stateController,
                          decoration: InputDecoration(
                            labelText: 'Business State',
                            prefixIcon: const Icon(Icons.map_outlined),
                            helperText: 'Required for GST tax calculations',
                            helperStyle: TextStyle(
                              color: theme.colorScheme.outline,
                              fontSize: 12,
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tax Section
                    _SectionCard(
                      icon: Icons.receipt_long_outlined,
                      title: 'Tax Configuration',
                      children: [
                        TextFormField(
                          controller: _gstController,
                          decoration: InputDecoration(
                            labelText: 'GST Number (Optional)',
                            prefixIcon: const Icon(Icons.pin_outlined),
                            hintText: '29AAAAA0000A1Z5',
                            helperText: 'Leave blank if not GST registered',
                            helperStyle: TextStyle(
                              color: theme.colorScheme.outline,
                              fontSize: 12,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              if (value.trim().length < 15) {
                                return 'Please enter a valid GST number if applicable';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Prices are GST Inclusive'),
                          subtitle: const Text(
                            'If enabled, product selling prices already include GST.',
                          ),
                          value: _isGstInclusive,
                          onChanged: (value) {
                            setState(() {
                              _isGstInclusive = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Submit
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: controllerState.isLoading ? null : _submit,
                        child: controllerState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save & Continue'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A card section with an icon header used for grouping form fields.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

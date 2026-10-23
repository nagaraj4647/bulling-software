import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/utils/error_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../business/models/business_model.dart';
import '../../business/providers/business_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _businessNameController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _gstController;
  late final TextEditingController _upiIdController;

  String? _selectedBusinessType;
  String? _selectedState;
  bool _isGstInclusive = false;
  bool _isInitialized = false;

  static const List<String> _businessTypes = [
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

  static const List<String> _indianStates = [
    'Andaman and Nicobar Islands',
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chandigarh',
    'Chhattisgarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu and Kashmir',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Ladakh',
    'Lakshadweep',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Puducherry',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController();
    _ownerNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _gstController = TextEditingController();
    _upiIdController = TextEditingController();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  void _populateForm(BusinessModel business) {
    if (_isInitialized) return;
    _businessNameController.text = business.businessName;
    _ownerNameController.text = business.ownerName;
    _phoneController.text = business.phone;
    _emailController.text = business.email;
    _addressController.text = business.address;
    _gstController.text = business.gstNumber ?? '';
    _upiIdController.text = business.upiId ?? '';
    _selectedBusinessType = _businessTypes.contains(business.businessType)
        ? business.businessType
        : 'Other';
    _selectedState =
        business.businessState != null &&
            _indianStates.contains(business.businessState)
        ? business.businessState
        : business.businessState;
    _isGstInclusive = business.isGstInclusive;
    _isInitialized = true;
  }

  Future<void> _saveSettings(BusinessModel currentBusiness) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBusinessType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a business type'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final rawGst = _gstController.text.trim().toUpperCase();
    final rawUpiId = _upiIdController.text.trim();

    final updatedBusiness = currentBusiness.copyWith(
      businessName: _businessNameController.text.trim(),
      businessType: _selectedBusinessType!,
      ownerName: _ownerNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      businessState: _selectedState != null && _selectedState!.trim().isNotEmpty
          ? _selectedState!.trim()
          : null,
      gstNumber: rawGst.isNotEmpty ? rawGst : null,
      upiId: rawUpiId.isNotEmpty ? rawUpiId : null,
      isGstInclusive: _isGstInclusive,
    );

    await ref
        .read(businessControllerProvider.notifier)
        .updateBusiness(updatedBusiness);

    if (mounted) {
      final controllerState = ref.read(businessControllerProvider);
      if (!controllerState.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save settings: ${ErrorFormatter.format(controllerState.error)}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showLogoutConfirmationDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text(
            'Are you sure you want to log out of your account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(authNotifierProvider.notifier).logout();
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessAsync = ref.watch(currentBusinessProvider);
    final user = ref.watch(authStateProvider).value;
    final controllerState = ref.watch(businessControllerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: businessAsync.when(
        data: (business) {
          if (business == null) {
            return const Center(child: Text('No active business found.'));
          }

          _populateForm(business);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 16),
                      _buildBusinessProfileCard(context),
                      const SizedBox(height: 16),
                      _buildTaxPreferencesCard(context),
                      const SizedBox(height: 16),
                      _buildAppearanceCard(context, themeMode),
                      const SizedBox(height: 16),
                      _buildAccountCard(context, user, business),
                      const SizedBox(height: 24),
                      _buildSaveButton(
                        controllerState.isLoading,
                        () => _saveSettings(business),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Error loading business: $err',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(currentBusinessProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage your business profile, tax configurations, and account preferences',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    );
  }

  Widget _buildBusinessProfileCard(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storefront,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Business Profile',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(height: 24),
            TextFormField(
              controller: _businessNameController,
              decoration: const InputDecoration(
                labelText: 'Business Name *',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty)
                  return 'Business name is required';
                if (val.trim().length < 2)
                  return 'Business name must be at least 2 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedBusinessType,
              decoration: const InputDecoration(
                labelText: 'Business Type *',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: _businessTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (val) => setState(() => _selectedBusinessType = val),
              validator: (val) => val == null || val.isEmpty
                  ? 'Please select a business type'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ownerNameController,
              decoration: const InputDecoration(
                labelText: 'Owner Name *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty)
                  return 'Owner name is required';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone *',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                      helperText: '10 digits mobile number',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty)
                        return 'Phone number is required';
                      final digits = val.trim().replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 10)
                        return 'Enter a valid 10-digit phone number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Contact Email *',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                      helperText: 'Used on invoices and customer receipts',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty)
                        return 'Contact email is required';
                      final emailRegex = RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      );
                      if (!emailRegex.hasMatch(val.trim()))
                        return 'Enter a valid email address';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Business Address *',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty)
                  return 'Business address is required';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue:
                  _selectedState != null &&
                      _indianStates.contains(_selectedState)
                  ? _selectedState
                  : null,
              decoration: const InputDecoration(
                labelText: 'Business State / UT',
                prefixIcon: Icon(Icons.map),
                border: OutlineInputBorder(),
                helperText: 'Used as default place of supply for GST tax calculations (CGST/SGST vs IGST)',
              ),
              items: _indianStates.map((state) {
                return DropdownMenuItem(
                  value: state,
                  child: Text(state, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedState = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxPreferencesCard(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tax & GST Configuration',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(height: 24),
            TextFormField(
              controller: _gstController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'GSTIN (GST Number)',
                prefixIcon: Icon(Icons.pin),
                border: OutlineInputBorder(),
                hintText: '29AAAAA0000A1Z5',
                helperText: '15-digit alphanumeric format (Leave blank if not GST registered)',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return null;
                final gstRegex = RegExp(
                  r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
                );
                if (!gstRegex.hasMatch(val.trim().toUpperCase())) {
                  return 'Enter a valid 15-character GSTIN (e.g. 29AAAAA0000A1Z5)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _upiIdController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'UPI ID (for QR on bills)',
                prefixIcon: Icon(Icons.qr_code),
                border: OutlineInputBorder(),
                hintText: 'yourname@upi',
                helperText: 'A "Scan to Pay" UPI QR with the bill amount will appear on invoices and PDF bills.',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return null;
                final upiRegex = RegExp(r'^[\w.\-_]{2,}@[A-Za-z]{2,}\$');
                if (!upiRegex.hasMatch(val.trim())) {
                  return 'Enter a valid UPI ID (e.g. name@okhdfcbank)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default GST Pricing: Inclusive'),
              subtitle: const Text(
                'When enabled, item selling and purchase prices entered are assumed to already include GST tax.',
              ),
              value: _isGstInclusive,
              onChanged: (val) => setState(() => _isGstInclusive = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceCard(BuildContext context, ThemeMode themeMode) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Theme',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select theme preference for this device',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (Set<ThemeMode> newSelection) {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(newSelection.first);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    dynamic user,
    BusinessModel business,
  ) {
    final createdAtFormatted = business.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(business.createdAt!)
        : 'N/A';

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Account Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Account Login Email'),
              subtitle: Text(user?.email ?? 'Unknown'),
              trailing: Chip(
                label: const Text('Owner'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fingerprint),
              title: const Text('Business ID'),
              subtitle: Text(business.businessId ?? 'N/A'),
              trailing: IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Copy Business ID',
                onPressed: () {
                  if (business.businessId != null) {
                    Clipboard.setData(
                      ClipboardData(text: business.businessId!),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Business ID copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Business Created On'),
              subtitle: Text(createdAtFormatted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
              onPressed: _showLogoutConfirmationDialog,
              icon: const Icon(Icons.logout),
              label: const Text('Log Out of Account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool isLoading, VoidCallback onSave) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onSave,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(isLoading ? 'Saving Changes...' : 'Save Settings'),
      ),
    );
  }
}

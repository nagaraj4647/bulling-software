import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable status chip for Draft/Confirmed/Cancelled/Paid across modules.
class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;

  const StatusChip({super.key, required this.label, this.color});

  /// Factory for common billing/purchase/expense statuses.
  factory StatusChip.fromStatus(String status) {
    final lower = status.toLowerCase();
    Color c;
    switch (lower) {
      case 'confirmed':
        c = AppTheme.confirmed;
        break;
      case 'cancelled':
        c = AppTheme.cancelled;
        break;
      case 'paid':
        c = AppTheme.paid;
        break;
      case 'partial':
        c = AppTheme.partial;
        break;
      case 'unpaid':
        c = AppTheme.unpaid;
        break;
      case 'draft':
      default:
        c = AppTheme.draft;
        break;
    }
    return StatusChip(label: status, color: c);
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.draft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withAlpha(60), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: chipColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

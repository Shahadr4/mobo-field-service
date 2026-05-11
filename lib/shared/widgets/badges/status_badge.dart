import 'package:flutter/material.dart';

/// Reusable status badge widget for displaying states with colors
/// Used for transfers, orders, invoices, etc.
class StatusBadge extends StatelessWidget {
  final String status;
  final StatusBadgeStyle? style;

  const StatusBadge({
    super.key,
    required this.status,
    this.style,
  });

  /// Factory for transfer states
  factory StatusBadge.transfer(String state) {
    return StatusBadge(
      status: state,
      style: _getTransferStyle(state),
    );
  }

  /// Factory for order states
  factory StatusBadge.order(String state) {
    return StatusBadge(
      status: state,
      style: _getOrderStyle(state),
    );
  }

  /// Factory for invoice states
  factory StatusBadge.invoice(String state) {
    return StatusBadge(
      status: state,
      style: _getInvoiceStyle(state),
    );
  }

  static StatusBadgeStyle _getTransferStyle(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return StatusBadgeStyle(
          label: 'Draft',
          color: Colors.grey,
          icon: Icons.edit_outlined,
        );
      case 'waiting':
        return StatusBadgeStyle(
          label: 'Waiting',
          color: Colors.orange,
          icon: Icons.hourglass_empty,
        );
      case 'confirmed':
        return StatusBadgeStyle(
          label: 'Waiting',  // Odoo shows 'confirmed' state as 'Waiting'
          color: Colors.orange,
          icon: Icons.hourglass_empty,
        );
      case 'assigned':
        return StatusBadgeStyle(
          label: 'Ready',
          color: Colors.blue,
          icon: Icons.assignment_turned_in_outlined,
        );
      case 'done':
        return StatusBadgeStyle(
          label: 'Done',
          color: Colors.green,
          icon: Icons.check_circle,
        );
      case 'cancel':
      case 'cancelled':
        return StatusBadgeStyle(
          label: 'Cancelled',
          color: Colors.red,
          icon: Icons.cancel_outlined,
        );
      default:
        return StatusBadgeStyle(
          label: state,
          color: Colors.grey,
        );
    }
  }

  static StatusBadgeStyle _getOrderStyle(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return StatusBadgeStyle(label: 'Draft', color: Colors.grey);
      case 'sent':
        return StatusBadgeStyle(label: 'Sent', color: Colors.blue);
      case 'sale':
        return StatusBadgeStyle(label: 'Sale Order', color: Colors.green);
      case 'done':
        return StatusBadgeStyle(label: 'Done', color: Colors.green);
      case 'cancel':
        return StatusBadgeStyle(label: 'Cancelled', color: Colors.red);
      default:
        return StatusBadgeStyle(label: state, color: Colors.grey);
    }
  }

  static StatusBadgeStyle _getInvoiceStyle(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return StatusBadgeStyle(label: 'Draft', color: Colors.grey);
      case 'posted':
        return StatusBadgeStyle(label: 'Posted', color: Colors.blue);
      case 'paid':
        return StatusBadgeStyle(label: 'Paid', color: Colors.green);
      case 'cancel':
        return StatusBadgeStyle(label: 'Cancelled', color: Colors.red);
      default:
        return StatusBadgeStyle(label: state, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeStyle = style ?? StatusBadgeStyle(label: status, color: Colors.grey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeStyle.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeStyle.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeStyle.icon != null) ...[
            Icon(
              badgeStyle.icon,
              size: 14,
              color: badgeStyle.color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            badgeStyle.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badgeStyle.color,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadgeStyle {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadgeStyle({
    required this.label,
    required this.color,
    this.icon,
  });
}

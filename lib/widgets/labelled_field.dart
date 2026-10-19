import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';

/// A form row labelled above the line, the way a register is filled in.
class LabelledField extends StatelessWidget {
  final String label;
  final Widget child;

  const LabelledField({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.sectionLabel(AppColors.grey)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

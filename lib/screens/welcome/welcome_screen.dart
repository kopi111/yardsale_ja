import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import 'profile_setup_screen.dart';

/// The cover of the catalogue: the house name set large on ink, and the three
/// things that happen inside.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const List<List<String>> _steps = [
    ['01', 'BID', 'On lots across all fourteen parishes.'],
    ['02', 'TALK', 'Message the seller before the hammer falls.'],
    ['03', 'COLLECT', 'Settle up and arrange the handover.'],
  ];

  void _openProfileSetup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 3, color: AppColors.goldBright),
              const SizedBox(height: 14),
              Text(
                'EST. KINGSTON · JAMAICA',
                style: AppTheme.sectionLabel(AppColors.grey),
              ),
              const Spacer(flex: 3),
              _Wordmark(),
              const Spacer(flex: 2),
              for (final step in _steps) _Step(step: step),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _openProfileSetup(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldBright,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  child: const Text('ENTER THE SALEROOM'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('YARDSALE', style: AppTheme.money(58, AppColors.paper)),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('JA', style: AppTheme.money(58, AppColors.goldBright)),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(height: 3, color: AppColors.goldBright),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          AppStrings.tagline.toUpperCase(),
          style: AppTheme.sectionLabel(AppColors.goldBright),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final List<String> step;

  const _Step({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2B2721))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(step[0], style: AppTheme.money(16, AppColors.gold)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step[1], style: AppTheme.sectionLabel(AppColors.paper)),
                const SizedBox(height: 4),
                Text(
                  step[2],
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

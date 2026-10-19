import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/member_details.dart';
import '../../core/theme.dart';
import '../../providers/user_provider.dart';
import '../../widgets/labelled_field.dart';
import 'onboarding_screen.dart';

/// Registering to bid. An auction house takes your details before it hands
/// you a paddle, so the screen is framed that way rather than as a signup.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedParish = AppParishes.parishes[0];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await context.read<UserProvider>().createProfile(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            parish: _selectedParish,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not register you. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    // Push onboarding on top of the gate (route "/"), which now resolves to
    // HomeScreen. Don't remove "/", so onboarding can pop back to reveal the
    // single gate-owned HomeScreen rather than spawning a duplicate.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(title: const Text('REGISTER TO BID')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 36),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabelledField(
                      label: 'YOUR NAME',
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'The name on your paddle',
                        ),
                        validator: MemberDetails.validateName,
                      ),
                    ),
                    LabelledField(
                      label: 'EMAIL',
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                            const InputDecoration(hintText: 'you@example.com'),
                        validator: MemberDetails.validateEmail,
                      ),
                    ),
                    LabelledField(
                      label: 'PHONE',
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(hintText: '876-555-0000'),
                        validator: MemberDetails.validatePhone,
                      ),
                    ),
                    LabelledField(
                      label: 'PARISH',
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedParish,
                        items: AppParishes.parishes
                            .map((parish) => DropdownMenuItem(
                                  value: parish,
                                  child: Text(parish),
                                ))
                            .toList(),
                        onChanged: (parish) =>
                            setState(() => _selectedParish = parish!),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createProfile,
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.paper,
                              ),
                            )
                          : const Text('COLLECT MY PADDLE'),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your details stay on this device and are shown to '
                      'sellers you bid with.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.ink,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BIDDER REGISTRATION',
            style: AppTheme.sectionLabel(AppColors.goldBright),
          ),
          const SizedBox(height: 10),
          Text(
            "Tell us who's holding the paddle.",
            style: AppTheme.money(24, AppColors.paper),
          ),
        ],
      ),
    );
  }
}

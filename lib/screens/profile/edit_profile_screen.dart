import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/member_details.dart';
import '../../core/theme.dart';
import '../../providers/user_provider.dart';
import '../../widgets/labelled_field.dart';

/// Changing the details on your paddle. Registration took them once; people
/// move parish, change their number and mistype their own email, so there has
/// to be a way back to them.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  late String _selectedParish;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().currentUser;
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
    _phoneController.text = user?.phone ?? '';
    final parish = user?.parish;
    _selectedParish = AppParishes.parishes.contains(parish)
        ? parish!
        : AppParishes.parishes.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<UserProvider>().updateProfile(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            parish: _selectedParish,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save your details. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Your details have been updated'),
        backgroundColor: AppColors.ink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(title: const Text('EDIT YOUR DETAILS')),
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
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.paper,
                              ),
                            )
                          : const Text('SAVE MY DETAILS'),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Sellers you bid with see your name and parish. Your '
                      'email and phone stay on this device.',
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
            'YOUR REGISTRATION',
            style: AppTheme.sectionLabel(AppColors.goldBright),
          ),
          const SizedBox(height: 10),
          Text(
            'Keep your details current.',
            style: AppTheme.money(24, AppColors.paper),
          ),
        ],
      ),
    );
  }
}

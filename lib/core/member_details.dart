/// The rules a member's details are held to. Registration and editing must
/// agree on them, so they are written once here.
class MemberDetails {
  /// A Jamaican number, in the three shapes a member actually writes one.
  ///
  /// Counting digits alone let "0000000" through, and the phone number is the
  /// only way a seller and a buyer reach each other. The exchange codes below
  /// are Jamaica's: area code 876 or 658, and a local exchange that cannot
  /// begin with 0 or 1.
  static final RegExp _jamaicanPhonePattern =
      RegExp(r'^(1?(876|658))?[2-9][0-9]{6}$');
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_emailPattern.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone is required';
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (!_jamaicanPhonePattern.hasMatch(digitsOnly)) {
      return 'Enter a valid Jamaican phone number';
    }
    return null;
  }
}

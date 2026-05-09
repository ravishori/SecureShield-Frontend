// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'SecureShield AI';

  @override
  String get appTagline => 'Your complete cyber safety guardian';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get skip => 'Skip';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get done => 'Done';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading…';

  @override
  String get orDivider => 'or';

  @override
  String get welcomeTitle => 'SecureShield AI';

  @override
  String get welcomeSubtitle => 'Your complete cyber safety guardian';

  @override
  String get welcomeScanTitle => 'Scan My Mobile';

  @override
  String get welcomeScanSubtitle => 'Check for threats in 30 seconds';

  @override
  String get welcomeTipsTitle => 'Cyber Safety Tips';

  @override
  String get welcomeTipsSubtitle => 'Learn how to stay safe online';

  @override
  String get welcomeContactsTitle => 'Cyber Crime Contacts';

  @override
  String get welcomeContactsSubtitle => 'Emergency helplines & portals';

  @override
  String get welcomeSosTitle => 'SOS Emergency';

  @override
  String get welcomeSosSubtitle => 'Report a cybercrime immediately';

  @override
  String get welcomeShareTitle => 'Share on WhatsApp';

  @override
  String get welcomeShareSubtitle => 'Warn friends about cyber scams';

  @override
  String get signIn => 'Sign In';

  @override
  String get signInSubtitle => 'Enter your phone number or email to continue';

  @override
  String get mobileTab => 'Mobile';

  @override
  String get emailTab => 'Email';

  @override
  String get enterPhoneHint => 'Enter mobile number';

  @override
  String get enterEmailHint => 'Enter email address';

  @override
  String get selectCountry => 'Select Country';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get sending => 'Sending…';

  @override
  String get continueBtn => 'Continue';

  @override
  String get checking => 'Checking…';

  @override
  String get checkingAccount => 'Checking your account…';

  @override
  String get welcomeBack => 'Welcome back!';

  @override
  String get creatingNewAccount => 'Creating new account';

  @override
  String get loginWithBiometric => 'Login with Biometrics';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get verifyTitle => 'Verify Code';

  @override
  String get enterVerificationCode => 'Enter verification code';

  @override
  String codeSentViaSms(String phone) {
    return 'We sent a 6-digit SMS to\n$phone';
  }

  @override
  String codeSentViaEmail(String email) {
    return 'We sent a 6-digit code to\n$email';
  }

  @override
  String get verifyBtn => 'Verify Code';

  @override
  String get verifying => 'Verifying…';

  @override
  String get resendCode => 'Resend Code';

  @override
  String get registerTitle => 'Create Account';

  @override
  String get registerSubtitle =>
      'Enter your mobile number to get started.\nWe\'ll send you a verification code.';

  @override
  String get mobileNumber => 'Mobile Number';

  @override
  String get enterMobileNumber => 'Enter mobile number';

  @override
  String get sendVerificationCode => 'Send Verification Code';

  @override
  String get sendingOtp => 'Sending OTP…';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get signInLink => 'Sign In';

  @override
  String get registerInfoNote =>
      'After verifying your number, you\'ll set up your profile details to complete registration.';

  @override
  String get completeYourProfile => 'Complete Your Profile';

  @override
  String get profileSetupSubtitle =>
      'Fill in your details to activate your SecureShield account';

  @override
  String get personalInformation => 'Personal Information';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get altPhone => 'Alternate Phone (optional)';

  @override
  String get emailAddress => 'Email Address (optional)';

  @override
  String get completeAddress => 'Complete Address';

  @override
  String get flatHouseNo => 'Flat / House No.';

  @override
  String get buildingSociety => 'Building / Society';

  @override
  String get streetArea => 'Street / Area';

  @override
  String get selectState => 'State';

  @override
  String get selectCity => 'City';

  @override
  String get selectStatFirst => 'Select state first';

  @override
  String get country => 'Country';

  @override
  String get pinCode => 'Pin Code';

  @override
  String get saveAndContinue => 'Save & Continue';

  @override
  String get saving => 'Saving…';

  @override
  String get fillThisLater => 'Fill this in later';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get appTheme => 'App Theme';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get lightMode => 'Light mode';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get securitySettings => 'Security Settings';

  @override
  String get seniorCitizenMode => 'Senior Citizen Mode';

  @override
  String get seniorModeSubtitle => 'Larger text, simplified UI';

  @override
  String get otpVault => 'OTP Vault';

  @override
  String get otpVaultSubtitle => 'Secure your OTPs';

  @override
  String get evidenceLocker => 'Evidence Locker';

  @override
  String get evidenceLockerSubtitle => 'Manage your evidence files';

  @override
  String get familyDashboard => 'Family Dashboard';

  @override
  String get familyDashboardSubtitle => 'Manage family members';

  @override
  String get about => 'About';

  @override
  String get appVersion => 'App Version';

  @override
  String get cybercrimeHelpline => 'Cybercrime Helpline';

  @override
  String get cybercrimeHelplineNumber =>
      '1930 (India National Cybercrime Helpline)';

  @override
  String get logout => 'Logout';

  @override
  String get profileCompleteness => 'Profile Completeness';

  @override
  String profileCompletenessPercent(int percent) {
    return '$percent% Complete';
  }

  @override
  String get completeProfileBanner =>
      'Complete your profile to unlock all security features';

  @override
  String get completeProfileBtn => 'Complete Profile';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get invalidEmail => 'Enter a valid email address';

  @override
  String get invalidPhone => 'Enter a valid phone number (digits only)';

  @override
  String get invalidPinCode => 'Enter a valid 6-digit PIN code';

  @override
  String get invalidName => 'Name should only contain letters and spaces';

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get networkError => 'Network error. Check your connection.';

  @override
  String get sessionExpired => 'Session expired. Please sign in again.';

  @override
  String get otpInvalid => 'Invalid OTP. Please try again.';

  @override
  String get scanTitle => 'Device Security Scan';

  @override
  String get scanSubtitle =>
      'Checking your device for security threats\nbefore you continue';

  @override
  String get cyberSafetyTips => 'Cyber Safety Tips';

  @override
  String get cyberCrimeContacts => 'Cyber Crime Contacts';
}

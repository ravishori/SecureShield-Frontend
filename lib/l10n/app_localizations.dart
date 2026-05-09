import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
    Locale('bn'),
    Locale('ta'),
    Locale('te')
  ];

  /// App name
  ///
  /// In en, this message translates to:
  /// **'SecureShield AI'**
  String get appName;

  /// App tagline on welcome screen
  ///
  /// In en, this message translates to:
  /// **'Your complete cyber safety guardian'**
  String get appTagline;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'SecureShield AI'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your complete cyber safety guardian'**
  String get welcomeSubtitle;

  /// No description provided for @welcomeScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan My Mobile'**
  String get welcomeScanTitle;

  /// No description provided for @welcomeScanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check for threats in 30 seconds'**
  String get welcomeScanSubtitle;

  /// No description provided for @welcomeTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cyber Safety Tips'**
  String get welcomeTipsTitle;

  /// No description provided for @welcomeTipsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn how to stay safe online'**
  String get welcomeTipsSubtitle;

  /// No description provided for @welcomeContactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cyber Crime Contacts'**
  String get welcomeContactsTitle;

  /// No description provided for @welcomeContactsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency helplines & portals'**
  String get welcomeContactsSubtitle;

  /// No description provided for @welcomeSosTitle.
  ///
  /// In en, this message translates to:
  /// **'SOS Emergency'**
  String get welcomeSosTitle;

  /// No description provided for @welcomeSosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report a cybercrime immediately'**
  String get welcomeSosSubtitle;

  /// No description provided for @welcomeShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share on WhatsApp'**
  String get welcomeShareTitle;

  /// No description provided for @welcomeShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Warn friends about cyber scams'**
  String get welcomeShareSubtitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number or email to continue'**
  String get signInSubtitle;

  /// No description provided for @mobileTab.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get mobileTab;

  /// No description provided for @emailTab.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailTab;

  /// No description provided for @enterPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter mobile number'**
  String get enterPhoneHint;

  /// No description provided for @enterEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter email address'**
  String get enterEmailHint;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select Country'**
  String get selectCountry;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @continueBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueBtn;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @checkingAccount.
  ///
  /// In en, this message translates to:
  /// **'Checking your account…'**
  String get checkingAccount;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// No description provided for @creatingNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating new account'**
  String get creatingNewAccount;

  /// No description provided for @loginWithBiometric.
  ///
  /// In en, this message translates to:
  /// **'Login with Biometrics'**
  String get loginWithBiometric;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get verifyTitle;

  /// No description provided for @enterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get enterVerificationCode;

  /// No description provided for @codeSentViaSms.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit SMS to\n{phone}'**
  String codeSentViaSms(String phone);

  /// No description provided for @codeSentViaEmail.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to\n{email}'**
  String codeSentViaEmail(String email);

  /// No description provided for @verifyBtn.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get verifyBtn;

  /// No description provided for @verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get verifying;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number to get started.\nWe\'ll send you a verification code.'**
  String get registerSubtitle;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @enterMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter mobile number'**
  String get enterMobileNumber;

  /// No description provided for @sendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Code'**
  String get sendVerificationCode;

  /// No description provided for @sendingOtp.
  ///
  /// In en, this message translates to:
  /// **'Sending OTP…'**
  String get sendingOtp;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @signInLink.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInLink;

  /// No description provided for @registerInfoNote.
  ///
  /// In en, this message translates to:
  /// **'After verifying your number, you\'ll set up your profile details to complete registration.'**
  String get registerInfoNote;

  /// No description provided for @completeYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get completeYourProfile;

  /// No description provided for @profileSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fill in your details to activate your SecureShield account'**
  String get profileSetupSubtitle;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @altPhone.
  ///
  /// In en, this message translates to:
  /// **'Alternate Phone (optional)'**
  String get altPhone;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address (optional)'**
  String get emailAddress;

  /// No description provided for @completeAddress.
  ///
  /// In en, this message translates to:
  /// **'Complete Address'**
  String get completeAddress;

  /// No description provided for @flatHouseNo.
  ///
  /// In en, this message translates to:
  /// **'Flat / House No.'**
  String get flatHouseNo;

  /// No description provided for @buildingSociety.
  ///
  /// In en, this message translates to:
  /// **'Building / Society'**
  String get buildingSociety;

  /// No description provided for @streetArea.
  ///
  /// In en, this message translates to:
  /// **'Street / Area'**
  String get streetArea;

  /// No description provided for @selectState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get selectState;

  /// No description provided for @selectCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get selectCity;

  /// No description provided for @selectStatFirst.
  ///
  /// In en, this message translates to:
  /// **'Select state first'**
  String get selectStatFirst;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @pinCode.
  ///
  /// In en, this message translates to:
  /// **'Pin Code'**
  String get pinCode;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save & Continue'**
  String get saveAndContinue;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @fillThisLater.
  ///
  /// In en, this message translates to:
  /// **'Fill this in later'**
  String get fillThisLater;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appTheme.
  ///
  /// In en, this message translates to:
  /// **'App Theme'**
  String get appTheme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get lightMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @securitySettings.
  ///
  /// In en, this message translates to:
  /// **'Security Settings'**
  String get securitySettings;

  /// No description provided for @seniorCitizenMode.
  ///
  /// In en, this message translates to:
  /// **'Senior Citizen Mode'**
  String get seniorCitizenMode;

  /// No description provided for @seniorModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Larger text, simplified UI'**
  String get seniorModeSubtitle;

  /// No description provided for @otpVault.
  ///
  /// In en, this message translates to:
  /// **'OTP Vault'**
  String get otpVault;

  /// No description provided for @otpVaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secure your OTPs'**
  String get otpVaultSubtitle;

  /// No description provided for @evidenceLocker.
  ///
  /// In en, this message translates to:
  /// **'Evidence Locker'**
  String get evidenceLocker;

  /// No description provided for @evidenceLockerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your evidence files'**
  String get evidenceLockerSubtitle;

  /// No description provided for @familyDashboard.
  ///
  /// In en, this message translates to:
  /// **'Family Dashboard'**
  String get familyDashboard;

  /// No description provided for @familyDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage family members'**
  String get familyDashboardSubtitle;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @cybercrimeHelpline.
  ///
  /// In en, this message translates to:
  /// **'Cybercrime Helpline'**
  String get cybercrimeHelpline;

  /// No description provided for @cybercrimeHelplineNumber.
  ///
  /// In en, this message translates to:
  /// **'1930 (India National Cybercrime Helpline)'**
  String get cybercrimeHelplineNumber;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @profileCompleteness.
  ///
  /// In en, this message translates to:
  /// **'Profile Completeness'**
  String get profileCompleteness;

  /// No description provided for @profileCompletenessPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% Complete'**
  String profileCompletenessPercent(int percent);

  /// No description provided for @completeProfileBanner.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile to unlock all security features'**
  String get completeProfileBanner;

  /// No description provided for @completeProfileBtn.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile'**
  String get completeProfileBtn;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalidEmail;

  /// No description provided for @invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number (digits only)'**
  String get invalidPhone;

  /// No description provided for @invalidPinCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit PIN code'**
  String get invalidPinCode;

  /// No description provided for @invalidName.
  ///
  /// In en, this message translates to:
  /// **'Name should only contain letters and spaces'**
  String get invalidName;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection.'**
  String get networkError;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get sessionExpired;

  /// No description provided for @otpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP. Please try again.'**
  String get otpInvalid;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Security Scan'**
  String get scanTitle;

  /// No description provided for @scanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Checking your device for security threats\nbefore you continue'**
  String get scanSubtitle;

  /// No description provided for @cyberSafetyTips.
  ///
  /// In en, this message translates to:
  /// **'Cyber Safety Tips'**
  String get cyberSafetyTips;

  /// No description provided for @cyberCrimeContacts.
  ///
  /// In en, this message translates to:
  /// **'Cyber Crime Contacts'**
  String get cyberCrimeContacts;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'bn',
        'en',
        'hi',
        'mr',
        'ta',
        'te'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'mr':
      return AppLocalizationsMr();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

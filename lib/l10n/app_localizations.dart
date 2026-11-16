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

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navScanner.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get navScanner;

  /// No description provided for @navAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get navAlerts;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navAiCoach.
  ///
  /// In en, this message translates to:
  /// **'AI Coach'**
  String get navAiCoach;

  /// No description provided for @secThreat.
  ///
  /// In en, this message translates to:
  /// **'Threat Detection'**
  String get secThreat;

  /// No description provided for @secEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency & SOS'**
  String get secEmergency;

  /// No description provided for @secIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity & Privacy'**
  String get secIdentity;

  /// No description provided for @secFamily.
  ///
  /// In en, this message translates to:
  /// **'Family Safety'**
  String get secFamily;

  /// No description provided for @secDevice.
  ///
  /// In en, this message translates to:
  /// **'Device Security'**
  String get secDevice;

  /// No description provided for @secReports.
  ///
  /// In en, this message translates to:
  /// **'Reports & Insights'**
  String get secReports;

  /// No description provided for @secAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get secAccount;

  /// No description provided for @menuLinkScanner.
  ///
  /// In en, this message translates to:
  /// **'Link Scanner'**
  String get menuLinkScanner;

  /// No description provided for @menuMessageAnalyzer.
  ///
  /// In en, this message translates to:
  /// **'Message Analyzer'**
  String get menuMessageAnalyzer;

  /// No description provided for @menuWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Safety'**
  String get menuWifi;

  /// No description provided for @menuAppRisk.
  ///
  /// In en, this message translates to:
  /// **'App Risk Scanner'**
  String get menuAppRisk;

  /// No description provided for @menuPackageMonitor.
  ///
  /// In en, this message translates to:
  /// **'Package Monitor'**
  String get menuPackageMonitor;

  /// No description provided for @menuCommunityScams.
  ///
  /// In en, this message translates to:
  /// **'Community Scams'**
  String get menuCommunityScams;

  /// No description provided for @menuPoliceCall.
  ///
  /// In en, this message translates to:
  /// **'Police Video Call'**
  String get menuPoliceCall;

  /// No description provided for @menuFir.
  ///
  /// In en, this message translates to:
  /// **'FIR Draft'**
  String get menuFir;

  /// No description provided for @menuCallRecorder.
  ///
  /// In en, this message translates to:
  /// **'Call Recorder'**
  String get menuCallRecorder;

  /// No description provided for @menuEmergencyShare.
  ///
  /// In en, this message translates to:
  /// **'Emergency Share'**
  String get menuEmergencyShare;

  /// No description provided for @menuComplaintEmail.
  ///
  /// In en, this message translates to:
  /// **'Complaint Email'**
  String get menuComplaintEmail;

  /// No description provided for @menuAppInstall.
  ///
  /// In en, this message translates to:
  /// **'App Install Monitor'**
  String get menuAppInstall;

  /// No description provided for @menuClone.
  ///
  /// In en, this message translates to:
  /// **'Clone Detector'**
  String get menuClone;

  /// No description provided for @menuElderly.
  ///
  /// In en, this message translates to:
  /// **'Elderly Protection'**
  String get menuElderly;

  /// No description provided for @menuBanking.
  ///
  /// In en, this message translates to:
  /// **'Banking Protection'**
  String get menuBanking;

  /// No description provided for @menuBankOtp.
  ///
  /// In en, this message translates to:
  /// **'Bank OTP Monitor'**
  String get menuBankOtp;

  /// No description provided for @menuVpn.
  ///
  /// In en, this message translates to:
  /// **'VPN Monitor'**
  String get menuVpn;

  /// No description provided for @menuRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote Detector'**
  String get menuRemote;

  /// No description provided for @menuScreenRec.
  ///
  /// In en, this message translates to:
  /// **'Screen Rec Detect'**
  String get menuScreenRec;

  /// No description provided for @menuJobMsg.
  ///
  /// In en, this message translates to:
  /// **'Job / Msg Analyzer'**
  String get menuJobMsg;

  /// No description provided for @menuDeviceScan.
  ///
  /// In en, this message translates to:
  /// **'Device Scan'**
  String get menuDeviceScan;

  /// No description provided for @menuConsent.
  ///
  /// In en, this message translates to:
  /// **'Consent Manager'**
  String get menuConsent;

  /// No description provided for @menuSecurityReports.
  ///
  /// In en, this message translates to:
  /// **'Security Reports'**
  String get menuSecurityReports;

  /// No description provided for @menuCyberTips.
  ///
  /// In en, this message translates to:
  /// **'Cyber Tips'**
  String get menuCyberTips;

  /// No description provided for @menuProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get menuProfile;

  /// No description provided for @menuEmergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contacts'**
  String get menuEmergencyContacts;

  /// No description provided for @familyTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Safety Dashboard'**
  String get familyTitle;

  /// No description provided for @familyTabFamily.
  ///
  /// In en, this message translates to:
  /// **'Family ({count})'**
  String familyTabFamily(int count);

  /// No description provided for @familyTabKids.
  ///
  /// In en, this message translates to:
  /// **'Kids ({count})'**
  String familyTabKids(int count);

  /// No description provided for @familyTabInvites.
  ///
  /// In en, this message translates to:
  /// **'Invites ({count})'**
  String familyTabInvites(int count);

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to add you as family'**
  String inviteTitle(String name);

  /// No description provided for @inviteSharesAlerts.
  ///
  /// In en, this message translates to:
  /// **'If you accept, {name} will be able to see your security alerts.'**
  String inviteSharesAlerts(String name);

  /// No description provided for @inviteNoShare.
  ///
  /// In en, this message translates to:
  /// **'Accepting does not share your alerts.'**
  String get inviteNoShare;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @noInvites.
  ///
  /// In en, this message translates to:
  /// **'No pending invitations. When someone adds you as family, you decide here whether they may see your alerts.'**
  String get noInvites;

  /// No description provided for @consentLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get consentLinked;

  /// No description provided for @consentLinkedUnread.
  ///
  /// In en, this message translates to:
  /// **'Linked - {count} unread'**
  String consentLinkedUnread(int count);

  /// No description provided for @consentDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get consentDeclined;

  /// No description provided for @consentPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get consentPending;

  /// No description provided for @noAlerts.
  ///
  /// In en, this message translates to:
  /// **'No alerts'**
  String get noAlerts;

  /// No description provided for @youAreSafe.
  ///
  /// In en, this message translates to:
  /// **'You are safe!'**
  String get youAreSafe;

  /// No description provided for @panicTitle.
  ///
  /// In en, this message translates to:
  /// **'Panic Alert'**
  String get panicTitle;

  /// No description provided for @panicBody.
  ///
  /// In en, this message translates to:
  /// **'This will message your emergency contacts and log a critical alert (family members you have approved can see it). Are you sure?'**
  String get panicBody;

  /// No description provided for @sendAlert.
  ///
  /// In en, this message translates to:
  /// **'SEND ALERT'**
  String get sendAlert;

  /// No description provided for @panicSent.
  ///
  /// In en, this message translates to:
  /// **'Panic alert sent! Emergency contacts notified.'**
  String get panicSent;

  /// No description provided for @menuScamCalls.
  ///
  /// In en, this message translates to:
  /// **'Scam Calls'**
  String get menuScamCalls;

  /// No description provided for @menuOtpVault.
  ///
  /// In en, this message translates to:
  /// **'OTP Vault'**
  String get menuOtpVault;

  /// No description provided for @scamIntro.
  ///
  /// In en, this message translates to:
  /// **'Got a call that felt wrong? Report the number: SecureShield scores it, warns you, and lets you block it.'**
  String get scamIntro;

  /// No description provided for @scamCallerNumber.
  ///
  /// In en, this message translates to:
  /// **'Caller number'**
  String get scamCallerNumber;

  /// No description provided for @scamCallLength.
  ///
  /// In en, this message translates to:
  /// **'Call length (minutes)'**
  String get scamCallLength;

  /// No description provided for @scamWhatAsked.
  ///
  /// In en, this message translates to:
  /// **'What did they ask for? (optional)'**
  String get scamWhatAsked;

  /// No description provided for @scamReportBtn.
  ///
  /// In en, this message translates to:
  /// **'Report this call'**
  String get scamReportBtn;

  /// No description provided for @scamEnterNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter the caller\'s phone number'**
  String get scamEnterNumber;

  /// No description provided for @scamReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not report the call. Check your connection.'**
  String get scamReportFailed;

  /// No description provided for @scamRiskScore.
  ///
  /// In en, this message translates to:
  /// **'Risk score {score}/100'**
  String scamRiskScore(int score);

  /// No description provided for @scamBlockedSuffix.
  ///
  /// In en, this message translates to:
  /// **' - blocked'**
  String get scamBlockedSuffix;

  /// No description provided for @scamYourReports.
  ///
  /// In en, this message translates to:
  /// **'Your reports'**
  String get scamYourReports;

  /// No description provided for @scamNoReports.
  ///
  /// In en, this message translates to:
  /// **'No reported calls yet.'**
  String get scamNoReports;

  /// No description provided for @scamBlockBtn.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get scamBlockBtn;

  /// No description provided for @scamNumberBlocked.
  ///
  /// In en, this message translates to:
  /// **'{number} blocked'**
  String scamNumberBlocked(String number);

  /// No description provided for @scamBlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not block the number'**
  String get scamBlockFailed;

  /// No description provided for @vaultTitle.
  ///
  /// In en, this message translates to:
  /// **'OTP Vault'**
  String get vaultTitle;

  /// No description provided for @vaultLocked.
  ///
  /// In en, this message translates to:
  /// **'OTP Vault is locked'**
  String get vaultLocked;

  /// No description provided for @vaultLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock with your fingerprint, face or device PIN. If your phone has no screen lock, set one to use the vault.'**
  String get vaultLockedBody;

  /// No description provided for @vaultUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get vaultUnlock;

  /// No description provided for @vaultReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock your OTP vault'**
  String get vaultReason;

  /// No description provided for @vaultHideArchived.
  ///
  /// In en, this message translates to:
  /// **'Hide archived'**
  String get vaultHideArchived;

  /// No description provided for @vaultShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get vaultShowArchived;

  /// No description provided for @vaultNoArchived.
  ///
  /// In en, this message translates to:
  /// **'No archived OTPs'**
  String get vaultNoArchived;

  /// No description provided for @vaultEmpty.
  ///
  /// In en, this message translates to:
  /// **'No OTPs saved yet.\nBank OTPs detected by the Bank OTP Monitor appear here.'**
  String get vaultEmpty;

  /// No description provided for @vaultCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get vaultCopy;

  /// No description provided for @vaultArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get vaultArchive;

  /// No description provided for @vaultUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get vaultUnarchive;

  /// No description provided for @vaultDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get vaultDelete;

  /// No description provided for @vpnBlockingActive.
  ///
  /// In en, this message translates to:
  /// **'Blocking connections to known-malicious networks'**
  String get vpnBlockingActive;

  /// No description provided for @vpnNoBlocked.
  ///
  /// In en, this message translates to:
  /// **'No blocked connection attempts yet'**
  String get vpnNoBlocked;

  /// No description provided for @vpnTapToStart.
  ///
  /// In en, this message translates to:
  /// **'Tap shield to start monitoring'**
  String get vpnTapToStart;

  /// No description provided for @gEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get gEdit;

  /// No description provided for @gClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get gClose;

  /// No description provided for @gRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get gRemove;

  /// No description provided for @gShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get gShare;

  /// No description provided for @gPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get gPlay;

  /// No description provided for @gReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get gReset;

  /// No description provided for @gSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get gSave;

  /// No description provided for @gCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get gCopy;

  /// No description provided for @gDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get gDone;

  /// No description provided for @gOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get gOpenSettings;

  /// No description provided for @gVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get gVerified;

  /// No description provided for @gUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get gUpload;

  /// No description provided for @gClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get gClear;

  /// No description provided for @gApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get gApply;

  /// No description provided for @gReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get gReport;

  /// No description provided for @gTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get gTitle;

  /// No description provided for @gDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get gDelete;

  /// No description provided for @profMy.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profMy;

  /// No description provided for @profSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile Saved!'**
  String get profSaved;

  /// No description provided for @profChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Any profile changes trigger an automated security email to you.'**
  String get profChangeEmail;

  /// No description provided for @profEmailAddr.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get profEmailAddr;

  /// No description provided for @profSelectState.
  ///
  /// In en, this message translates to:
  /// **'Select State'**
  String get profSelectState;

  /// No description provided for @profPin.
  ///
  /// In en, this message translates to:
  /// **'PIN Code'**
  String get profPin;

  /// No description provided for @profContactRemoved.
  ///
  /// In en, this message translates to:
  /// **'Contact removed'**
  String get profContactRemoved;

  /// No description provided for @profFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name *'**
  String get profFullName;

  /// No description provided for @profRelationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship (e.g. Father, Friend)'**
  String get profRelationship;

  /// No description provided for @profPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get profPhone;

  /// No description provided for @profContactsInfo.
  ///
  /// In en, this message translates to:
  /// **'These contacts will be notified in emergencies and can receive incident reports via Email or WhatsApp.'**
  String get profContactsInfo;

  /// No description provided for @profAddContact.
  ///
  /// In en, this message translates to:
  /// **'Add Contact'**
  String get profAddContact;

  /// No description provided for @profNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No Emergency Contacts'**
  String get profNoContacts;

  /// No description provided for @profNoContactsBody.
  ///
  /// In en, this message translates to:
  /// **'Add trusted family members or friends who will be notified in case of an emergency or cyber incident.'**
  String get profNoContactsBody;

  /// No description provided for @profRemoveContact.
  ///
  /// In en, this message translates to:
  /// **'Remove Contact'**
  String get profRemoveContact;

  /// No description provided for @welLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get welLogin;

  /// No description provided for @welRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get welRegister;

  /// No description provided for @welShareEvidence.
  ///
  /// In en, this message translates to:
  /// **'Share Evidence'**
  String get welShareEvidence;

  /// No description provided for @welCyberContacts.
  ///
  /// In en, this message translates to:
  /// **'Cyber Contacts'**
  String get welCyberContacts;

  /// No description provided for @welSendEmailReport.
  ///
  /// In en, this message translates to:
  /// **'Send Email Report'**
  String get welSendEmailReport;

  /// No description provided for @welWhatsappMissing.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp is not installed'**
  String get welWhatsappMissing;

  /// No description provided for @welNoEmailApp.
  ///
  /// In en, this message translates to:
  /// **'No email app found on this device'**
  String get welNoEmailApp;

  /// No description provided for @welProtected.
  ///
  /// In en, this message translates to:
  /// **'PROTECTED'**
  String get welProtected;

  /// No description provided for @welAiPowered.
  ///
  /// In en, this message translates to:
  /// **'AI-POWERED'**
  String get welAiPowered;

  /// No description provided for @welEnterprise.
  ///
  /// In en, this message translates to:
  /// **'Enterprise Cyber Protection'**
  String get welEnterprise;

  /// No description provided for @welEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get welEncrypted;

  /// No description provided for @welOfflineFirst.
  ///
  /// In en, this message translates to:
  /// **'Offline-first'**
  String get welOfflineFirst;

  /// No description provided for @wifiLocOff.
  ///
  /// In en, this message translates to:
  /// **'Location Services Off'**
  String get wifiLocOff;

  /// No description provided for @wifiRiskFactors.
  ///
  /// In en, this message translates to:
  /// **'Risk Factors:'**
  String get wifiRiskFactors;

  /// No description provided for @wifiNoRiskFactors.
  ///
  /// In en, this message translates to:
  /// **'No specific risk factors identified.'**
  String get wifiNoRiskFactors;

  /// No description provided for @wifiSafety.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Safety'**
  String get wifiSafety;

  /// No description provided for @wifiRescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get wifiRescan;

  /// No description provided for @wifiLocPermReq.
  ///
  /// In en, this message translates to:
  /// **'Location Permission Required'**
  String get wifiLocPermReq;

  /// No description provided for @wifiLocDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location Services Disabled'**
  String get wifiLocDisabled;

  /// No description provided for @wifiNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected to any Wi-Fi network'**
  String get wifiNotConnected;

  /// No description provided for @wifiConnected.
  ///
  /// In en, this message translates to:
  /// **'CONNECTED'**
  String get wifiConnected;

  /// No description provided for @wifiCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get wifiCheck;

  /// No description provided for @wifiNoNearby.
  ///
  /// In en, this message translates to:
  /// **'No nearby networks found'**
  String get wifiNoNearby;

  /// No description provided for @wifiScanNearby.
  ///
  /// In en, this message translates to:
  /// **'Scan Nearby'**
  String get wifiScanNearby;

  /// No description provided for @wifiTips.
  ///
  /// In en, this message translates to:
  /// **'Public Wi-Fi Safety Tips'**
  String get wifiTips;

  /// No description provided for @srSaved.
  ///
  /// In en, this message translates to:
  /// **'Recording saved successfully.'**
  String get srSaved;

  /// No description provided for @srDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied. Please allow screen capture.'**
  String get srDenied;

  /// No description provided for @srDeleteQ.
  ///
  /// In en, this message translates to:
  /// **'Delete Recording?'**
  String get srDeleteQ;

  /// No description provided for @srTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen Recorder'**
  String get srTitle;

  /// No description provided for @srRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh recordings'**
  String get srRefresh;

  /// No description provided for @srPurpose.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get srPurpose;

  /// No description provided for @srTapStart.
  ///
  /// In en, this message translates to:
  /// **'Tap to start recording your screen'**
  String get srTapStart;

  /// No description provided for @srPast.
  ///
  /// In en, this message translates to:
  /// **'Past Recordings'**
  String get srPast;

  /// No description provided for @srNone.
  ///
  /// In en, this message translates to:
  /// **'No recordings yet'**
  String get srNone;

  /// No description provided for @srTapRecordAbove.
  ///
  /// In en, this message translates to:
  /// **'Tap RECORD above to capture your screen'**
  String get srTapRecordAbove;

  /// No description provided for @srTapPlay.
  ///
  /// In en, this message translates to:
  /// **'Tap to Play'**
  String get srTapPlay;

  /// No description provided for @setDeviceSafety.
  ///
  /// In en, this message translates to:
  /// **'DEVICE SAFETY SUMMARY'**
  String get setDeviceSafety;

  /// No description provided for @setDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get setDark;

  /// No description provided for @setLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get setLight;

  /// No description provided for @setRemoteDetector.
  ///
  /// In en, this message translates to:
  /// **'Remote Control Detector'**
  String get setRemoteDetector;

  /// No description provided for @setPermManager.
  ///
  /// In en, this message translates to:
  /// **'Permission Manager'**
  String get setPermManager;

  /// No description provided for @setVpnMonitor.
  ///
  /// In en, this message translates to:
  /// **'VPN Traffic Monitor'**
  String get setVpnMonitor;

  /// No description provided for @setDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get setDeveloper;

  /// No description provided for @setServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get setServerUrl;

  /// No description provided for @setServerReset.
  ///
  /// In en, this message translates to:
  /// **'Server URL reset to auto-detected value'**
  String get setServerReset;

  /// No description provided for @cmSms.
  ///
  /// In en, this message translates to:
  /// **'SMS Access'**
  String get cmSms;

  /// No description provided for @cmCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cmCamera;

  /// No description provided for @cmMic.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get cmMic;

  /// No description provided for @cmLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get cmLocation;

  /// No description provided for @cmPhoneState.
  ///
  /// In en, this message translates to:
  /// **'Phone State'**
  String get cmPhoneState;

  /// No description provided for @cmStorageMedia.
  ///
  /// In en, this message translates to:
  /// **'Storage (Media)'**
  String get cmStorageMedia;

  /// No description provided for @cmNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get cmNotifications;

  /// No description provided for @cmUsageStats.
  ///
  /// In en, this message translates to:
  /// **'Usage Stats'**
  String get cmUsageStats;

  /// No description provided for @cmUsageStatsAccess.
  ///
  /// In en, this message translates to:
  /// **'Usage Stats Access'**
  String get cmUsageStatsAccess;

  /// No description provided for @cmAppPermissions.
  ///
  /// In en, this message translates to:
  /// **'App Permissions'**
  String get cmAppPermissions;

  /// No description provided for @cmCritical.
  ///
  /// In en, this message translates to:
  /// **'CRITICAL'**
  String get cmCritical;

  /// No description provided for @cmGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get cmGrant;

  /// No description provided for @esTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Share'**
  String get esTitle;

  /// No description provided for @esIntro.
  ///
  /// In en, this message translates to:
  /// **'Share recording immediately with trusted contacts or upload securely.'**
  String get esIntro;

  /// No description provided for @esWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Share via WhatsApp / SMS'**
  String get esWhatsapp;

  /// No description provided for @esEmail.
  ///
  /// In en, this message translates to:
  /// **'Share via Email'**
  String get esEmail;

  /// No description provided for @esReport1930.
  ///
  /// In en, this message translates to:
  /// **'Report to 1930 (Cybercrime)'**
  String get esReport1930;

  /// No description provided for @esPoliceCells.
  ///
  /// In en, this message translates to:
  /// **'Local Police Cyber Cells'**
  String get esPoliceCells;

  /// No description provided for @esFamily.
  ///
  /// In en, this message translates to:
  /// **'Share with Family Contacts'**
  String get esFamily;

  /// No description provided for @esSecureUpload.
  ///
  /// In en, this message translates to:
  /// **'Secure Upload + Expiring Link'**
  String get esSecureUpload;

  /// No description provided for @es24h.
  ///
  /// In en, this message translates to:
  /// **'Generate a 24-hour download link'**
  String get es24h;

  /// No description provided for @esUploaded.
  ///
  /// In en, this message translates to:
  /// **'Upload successful! Link expires in 24h'**
  String get esUploaded;

  /// No description provided for @esCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get esCopyLink;

  /// No description provided for @esShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share Link'**
  String get esShareLink;

  /// No description provided for @esUploadGet.
  ///
  /// In en, this message translates to:
  /// **'Upload & Get Link'**
  String get esUploadGet;

  /// No description provided for @csReport.
  ///
  /// In en, this message translates to:
  /// **'Report a Scam'**
  String get csReport;

  /// No description provided for @csType.
  ///
  /// In en, this message translates to:
  /// **'Scam Type'**
  String get csType;

  /// No description provided for @csTitleReq.
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get csTitleReq;

  /// No description provided for @csDescReq.
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get csDescReq;

  /// No description provided for @csUrl.
  ///
  /// In en, this message translates to:
  /// **'Scam URL (optional)'**
  String get csUrl;

  /// No description provided for @csCity.
  ///
  /// In en, this message translates to:
  /// **'Your City (optional)'**
  String get csCity;

  /// No description provided for @csTitle.
  ///
  /// In en, this message translates to:
  /// **'Community Scam Alerts'**
  String get csTitle;

  /// No description provided for @csFilterCity.
  ///
  /// In en, this message translates to:
  /// **'Filter by city'**
  String get csFilterCity;

  /// No description provided for @csReportBtn.
  ///
  /// In en, this message translates to:
  /// **'Report Scam'**
  String get csReportBtn;

  /// No description provided for @csBeFirst.
  ///
  /// In en, this message translates to:
  /// **'Be the first to warn your community'**
  String get csBeFirst;

  /// No description provided for @csFilterByCity.
  ///
  /// In en, this message translates to:
  /// **'Filter by City'**
  String get csFilterByCity;

  /// No description provided for @csCityHint.
  ///
  /// In en, this message translates to:
  /// **'City (e.g. Mumbai)'**
  String get csCityHint;

  /// No description provided for @fbBothReq.
  ///
  /// In en, this message translates to:
  /// **'Please provide both the sender and the message body.'**
  String get fbBothReq;

  /// No description provided for @fbTitle.
  ///
  /// In en, this message translates to:
  /// **'Fake Bank SMS Detector'**
  String get fbTitle;

  /// No description provided for @fbVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify before you trust'**
  String get fbVerify;

  /// No description provided for @fbSender.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get fbSender;

  /// No description provided for @fbBody.
  ///
  /// In en, this message translates to:
  /// **'Message body'**
  String get fbBody;

  /// No description provided for @fbPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get fbPaste;

  /// No description provided for @fbCheck.
  ///
  /// In en, this message translates to:
  /// **'Check authenticity'**
  String get fbCheck;

  /// No description provided for @fbWhy.
  ///
  /// In en, this message translates to:
  /// **'Why this verdict'**
  String get fbWhy;

  /// No description provided for @fbNext.
  ///
  /// In en, this message translates to:
  /// **'Recommended next steps'**
  String get fbNext;

  /// No description provided for @lsEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a URL to scan'**
  String get lsEnterUrl;

  /// No description provided for @lsTitle.
  ///
  /// In en, this message translates to:
  /// **'Link Scanner'**
  String get lsTitle;

  /// No description provided for @lsEnterToScan.
  ///
  /// In en, this message translates to:
  /// **'Enter URL to scan'**
  String get lsEnterToScan;

  /// No description provided for @lsRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent Scans'**
  String get lsRecent;

  /// No description provided for @lsCopied.
  ///
  /// In en, this message translates to:
  /// **'URL copied'**
  String get lsCopied;

  /// No description provided for @lsRisk.
  ///
  /// In en, this message translates to:
  /// **'Risk Score'**
  String get lsRisk;

  /// No description provided for @evAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Evidence'**
  String get evAdd;

  /// No description provided for @evDescOpt.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get evDescOpt;

  /// No description provided for @evUploaded.
  ///
  /// In en, this message translates to:
  /// **'Evidence uploaded'**
  String get evUploaded;

  /// No description provided for @evOpen.
  ///
  /// In en, this message translates to:
  /// **'Open or share'**
  String get evOpen;

  /// No description provided for @evDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download this evidence. Check your connection and try again.'**
  String get evDownloadFailed;

  /// No description provided for @evFileGone.
  ///
  /// In en, this message translates to:
  /// **'This file is no longer available on the server.'**
  String get evFileGone;

  /// No description provided for @evEmpty.
  ///
  /// In en, this message translates to:
  /// **'Evidence Locker is empty'**
  String get evEmpty;

  /// No description provided for @evEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Store screenshots, audio, and documents here'**
  String get evEmptyBody;

  /// No description provided for @evDeleteQ.
  ///
  /// In en, this message translates to:
  /// **'Delete Evidence?'**
  String get evDeleteQ;

  /// No description provided for @evCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get evCannotUndo;

  /// No description provided for @menuScreenRecorder.
  ///
  /// In en, this message translates to:
  /// **'Screen Recorder'**
  String get menuScreenRecorder;

  /// No description provided for @srdTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen Recording Detector'**
  String get srdTitle;

  /// No description provided for @srdUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not supported on this Android version'**
  String get srdUnsupported;

  /// No description provided for @srdUnsupportedBody.
  ///
  /// In en, this message translates to:
  /// **'Android only lets an app learn that its screen is being recorded from Android 15 onwards. On your phone this check is not possible, so SecureShield cannot tell you whether another app is recording the screen.'**
  String get srdUnsupportedBody;

  /// No description provided for @srdIdle.
  ///
  /// In en, this message translates to:
  /// **'Not being recorded'**
  String get srdIdle;

  /// No description provided for @srdIdleBody.
  ///
  /// In en, this message translates to:
  /// **'SecureShield screens are not visible in any screen recording right now.'**
  String get srdIdleBody;

  /// No description provided for @srdActive.
  ///
  /// In en, this message translates to:
  /// **'SCREEN IS BEING RECORDED'**
  String get srdActive;

  /// No description provided for @srdActiveBody.
  ///
  /// In en, this message translates to:
  /// **'Something is recording what SecureShield shows. If you did not start it, stop it and do not open OTPs or bank screens.'**
  String get srdActiveBody;

  /// No description provided for @srdScope.
  ///
  /// In en, this message translates to:
  /// **'This only covers SecureShield\'s own screens (an Android limit). It cannot see recordings of other apps.'**
  String get srdScope;

  /// No description provided for @srdLog.
  ///
  /// In en, this message translates to:
  /// **'This session'**
  String get srdLog;

  /// No description provided for @srdNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No recording detected so far.'**
  String get srdNoEvents;

  /// No description provided for @srdStarted.
  ///
  /// In en, this message translates to:
  /// **'Recording started'**
  String get srdStarted;

  /// No description provided for @srdStopped.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped'**
  String get srdStopped;
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

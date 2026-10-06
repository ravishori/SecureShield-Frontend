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

  @override
  String get navHome => 'Home';

  @override
  String get navScanner => 'Scanner';

  @override
  String get navAlerts => 'Alerts';

  @override
  String get navReports => 'Reports';

  @override
  String get navAiCoach => 'AI Coach';

  @override
  String get secThreat => 'Threat Detection';

  @override
  String get secEmergency => 'Emergency & SOS';

  @override
  String get secIdentity => 'Identity & Privacy';

  @override
  String get secFamily => 'Family Safety';

  @override
  String get secDevice => 'Device Security';

  @override
  String get secReports => 'Reports & Insights';

  @override
  String get secAccount => 'Account';

  @override
  String get menuLinkScanner => 'Link Scanner';

  @override
  String get menuMessageAnalyzer => 'Message Analyzer';

  @override
  String get menuWifi => 'Wi-Fi Safety';

  @override
  String get menuAppRisk => 'App Risk Scanner';

  @override
  String get menuPackageMonitor => 'Package Monitor';

  @override
  String get menuCommunityScams => 'Community Scams';

  @override
  String get menuPoliceCall => 'Police Video Call';

  @override
  String get menuFir => 'FIR Draft';

  @override
  String get menuCallRecorder => 'Call Recorder';

  @override
  String get menuEmergencyShare => 'Emergency Share';

  @override
  String get menuComplaintEmail => 'Complaint Email';

  @override
  String get menuAppInstall => 'App Install Monitor';

  @override
  String get menuClone => 'Clone Detector';

  @override
  String get menuElderly => 'Elderly Protection';

  @override
  String get menuBanking => 'Banking Protection';

  @override
  String get menuBankOtp => 'Bank OTP Monitor';

  @override
  String get menuVpn => 'VPN Monitor';

  @override
  String get menuRemote => 'Remote Detector';

  @override
  String get menuScreenRec => 'Screen Rec Detect';

  @override
  String get menuJobMsg => 'Job / Msg Analyzer';

  @override
  String get menuDeviceScan => 'Device Scan';

  @override
  String get menuConsent => 'Consent Manager';

  @override
  String get menuSecurityReports => 'Security Reports';

  @override
  String get menuCyberTips => 'Cyber Tips';

  @override
  String get menuProfile => 'My Profile';

  @override
  String get menuEmergencyContacts => 'Emergency Contacts';

  @override
  String get familyTitle => 'Family Safety Dashboard';

  @override
  String familyTabFamily(int count) {
    return 'Family ($count)';
  }

  @override
  String familyTabKids(int count) {
    return 'Kids ($count)';
  }

  @override
  String familyTabInvites(int count) {
    return 'Invites ($count)';
  }

  @override
  String inviteTitle(String name) {
    return '$name wants to add you as family';
  }

  @override
  String inviteSharesAlerts(String name) {
    return 'If you accept, $name will be able to see your security alerts.';
  }

  @override
  String get inviteNoShare => 'Accepting does not share your alerts.';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get noInvites =>
      'No pending invitations. When someone adds you as family, you decide here whether they may see your alerts.';

  @override
  String get consentLinked => 'Linked';

  @override
  String consentLinkedUnread(int count) {
    return 'Linked - $count unread';
  }

  @override
  String get consentDeclined => 'Declined';

  @override
  String get consentPending => 'Waiting for approval';

  @override
  String get noAlerts => 'No alerts';

  @override
  String get youAreSafe => 'You are safe!';

  @override
  String get panicTitle => 'Panic Alert';

  @override
  String get panicBody =>
      'This will message your emergency contacts and log a critical alert (family members you have approved can see it). Are you sure?';

  @override
  String get sendAlert => 'SEND ALERT';

  @override
  String get panicSent => 'Panic alert sent! Emergency contacts notified.';

  @override
  String get menuScamCalls => 'Scam Calls';

  @override
  String get menuOtpVault => 'OTP Vault';

  @override
  String get scamIntro =>
      'Got a call that felt wrong? Report the number: SecureShield scores it, warns you, and lets you block it.';

  @override
  String get scamCallerNumber => 'Caller number';

  @override
  String get scamCallLength => 'Call length (minutes)';

  @override
  String get scamWhatAsked => 'What did they ask for? (optional)';

  @override
  String get scamReportBtn => 'Report this call';

  @override
  String get scamEnterNumber => 'Enter the caller\'s phone number';

  @override
  String get scamReportFailed =>
      'Could not report the call. Check your connection.';

  @override
  String scamRiskScore(int score) {
    return 'Risk score $score/100';
  }

  @override
  String get scamBlockedSuffix => ' - blocked';

  @override
  String get scamYourReports => 'Your reports';

  @override
  String get scamNoReports => 'No reported calls yet.';

  @override
  String get scamBlockBtn => 'Block';

  @override
  String scamNumberBlocked(String number) {
    return '$number blocked';
  }

  @override
  String get scamBlockFailed => 'Could not block the number';

  @override
  String get vaultTitle => 'OTP Vault';

  @override
  String get vaultLocked => 'OTP Vault is locked';

  @override
  String get vaultLockedBody =>
      'Unlock with your fingerprint, face or device PIN. If your phone has no screen lock, set one to use the vault.';

  @override
  String get vaultUnlock => 'Unlock';

  @override
  String get vaultReason => 'Unlock your OTP vault';

  @override
  String get vaultHideArchived => 'Hide archived';

  @override
  String get vaultShowArchived => 'Show archived';

  @override
  String get vaultNoArchived => 'No archived OTPs';

  @override
  String get vaultEmpty =>
      'No OTPs saved yet.\nBank OTPs detected by the Bank OTP Monitor appear here.';

  @override
  String get vaultCopy => 'Copy';

  @override
  String get vaultArchive => 'Archive';

  @override
  String get vaultUnarchive => 'Unarchive';

  @override
  String get vaultDelete => 'Delete';

  @override
  String get vpnBlockingActive =>
      'Blocking connections to known-malicious networks';

  @override
  String get vpnNoBlocked => 'No blocked connection attempts yet';

  @override
  String get vpnTapToStart => 'Tap shield to start monitoring';

  @override
  String get gEdit => 'Edit';

  @override
  String get gClose => 'Close';

  @override
  String get gRemove => 'Remove';

  @override
  String get gShare => 'Share';

  @override
  String get gPlay => 'Play';

  @override
  String get gReset => 'Reset';

  @override
  String get gSave => 'Save';

  @override
  String get gCopy => 'Copy';

  @override
  String get gDone => 'Done';

  @override
  String get gOpenSettings => 'Open Settings';

  @override
  String get gVerified => 'Verified';

  @override
  String get gUpload => 'Upload';

  @override
  String get gClear => 'Clear';

  @override
  String get gApply => 'Apply';

  @override
  String get gReport => 'Report';

  @override
  String get gTitle => 'Title';

  @override
  String get gDelete => 'Delete';

  @override
  String get profMy => 'My Profile';

  @override
  String get profSaved => 'Profile Saved!';

  @override
  String get profChangeEmail =>
      'Any profile changes trigger an automated security email to you.';

  @override
  String get profEmailAddr => 'Email Address';

  @override
  String get profSelectState => 'Select State';

  @override
  String get profPin => 'PIN Code';

  @override
  String get profContactRemoved => 'Contact removed';

  @override
  String get profFullName => 'Full Name *';

  @override
  String get profRelationship => 'Relationship (e.g. Father, Friend)';

  @override
  String get profPhone => 'Phone Number';

  @override
  String get profContactsInfo =>
      'These contacts will be notified in emergencies and can receive incident reports via Email or WhatsApp.';

  @override
  String get profAddContact => 'Add Contact';

  @override
  String get profNoContacts => 'No Emergency Contacts';

  @override
  String get profNoContactsBody =>
      'Add trusted family members or friends who will be notified in case of an emergency or cyber incident.';

  @override
  String get profRemoveContact => 'Remove Contact';

  @override
  String get welLogin => 'Login';

  @override
  String get welRegister => 'Register';

  @override
  String get welShareEvidence => 'Share Evidence';

  @override
  String get welCyberContacts => 'Cyber Contacts';

  @override
  String get welSendEmailReport => 'Send Email Report';

  @override
  String get welWhatsappMissing => 'WhatsApp is not installed';

  @override
  String get welNoEmailApp => 'No email app found on this device';

  @override
  String get welProtected => 'PROTECTED';

  @override
  String get welAiPowered => 'AI-POWERED';

  @override
  String get welEnterprise => 'Enterprise Cyber Protection';

  @override
  String get welEncrypted => 'Encrypted';

  @override
  String get welOfflineFirst => 'Offline-first';

  @override
  String get wifiLocOff => 'Location Services Off';

  @override
  String get wifiRiskFactors => 'Risk Factors:';

  @override
  String get wifiNoRiskFactors => 'No specific risk factors identified.';

  @override
  String get wifiSafety => 'Wi-Fi Safety';

  @override
  String get wifiRescan => 'Rescan';

  @override
  String get wifiLocPermReq => 'Location Permission Required';

  @override
  String get wifiLocDisabled => 'Location Services Disabled';

  @override
  String get wifiNotConnected => 'Not connected to any Wi-Fi network';

  @override
  String get wifiConnected => 'CONNECTED';

  @override
  String get wifiCheck => 'Check';

  @override
  String get wifiNoNearby => 'No nearby networks found';

  @override
  String get wifiScanNearby => 'Scan Nearby';

  @override
  String get wifiTips => 'Public Wi-Fi Safety Tips';

  @override
  String get srSaved => 'Recording saved successfully.';

  @override
  String get srDenied => 'Permission denied. Please allow screen capture.';

  @override
  String get srDeleteQ => 'Delete Recording?';

  @override
  String get srTitle => 'Screen Recorder';

  @override
  String get srRefresh => 'Refresh recordings';

  @override
  String get srPurpose => 'Purpose';

  @override
  String get srTapStart => 'Tap to start recording your screen';

  @override
  String get srPast => 'Past Recordings';

  @override
  String get srNone => 'No recordings yet';

  @override
  String get srTapRecordAbove => 'Tap RECORD above to capture your screen';

  @override
  String get srTapPlay => 'Tap to Play';

  @override
  String get setDeviceSafety => 'DEVICE SAFETY SUMMARY';

  @override
  String get setDark => 'Dark';

  @override
  String get setLight => 'Light';

  @override
  String get setRemoteDetector => 'Remote Control Detector';

  @override
  String get setPermManager => 'Permission Manager';

  @override
  String get setVpnMonitor => 'VPN Traffic Monitor';

  @override
  String get setDeveloper => 'Developer';

  @override
  String get setServerUrl => 'Server URL';

  @override
  String get setServerReset => 'Server URL reset to auto-detected value';

  @override
  String get cmSms => 'SMS Access';

  @override
  String get cmCamera => 'Camera';

  @override
  String get cmMic => 'Microphone';

  @override
  String get cmLocation => 'Location';

  @override
  String get cmPhoneState => 'Phone State';

  @override
  String get cmStorageMedia => 'Storage (Media)';

  @override
  String get cmNotifications => 'Notifications';

  @override
  String get cmUsageStats => 'Usage Stats';

  @override
  String get cmUsageStatsAccess => 'Usage Stats Access';

  @override
  String get cmAppPermissions => 'App Permissions';

  @override
  String get cmCritical => 'CRITICAL';

  @override
  String get cmGrant => 'Grant';

  @override
  String get esTitle => 'Emergency Share';

  @override
  String get esIntro =>
      'Share recording immediately with trusted contacts or upload securely.';

  @override
  String get esWhatsapp => 'Share via WhatsApp / SMS';

  @override
  String get esEmail => 'Share via Email';

  @override
  String get esReport1930 => 'Report to 1930 (Cybercrime)';

  @override
  String get esPoliceCells => 'Local Police Cyber Cells';

  @override
  String get esFamily => 'Share with Family Contacts';

  @override
  String get esSecureUpload => 'Secure Upload + Expiring Link';

  @override
  String get es24h => 'Generate a 24-hour download link';

  @override
  String get esUploaded => 'Upload successful! Link expires in 24h';

  @override
  String get esCopyLink => 'Copy Link';

  @override
  String get esShareLink => 'Share Link';

  @override
  String get esUploadGet => 'Upload & Get Link';

  @override
  String get csReport => 'Report a Scam';

  @override
  String get csType => 'Scam Type';

  @override
  String get csTitleReq => 'Title *';

  @override
  String get csDescReq => 'Description *';

  @override
  String get csUrl => 'Scam URL (optional)';

  @override
  String get csCity => 'Your City (optional)';

  @override
  String get csTitle => 'Community Scam Alerts';

  @override
  String get csFilterCity => 'Filter by city';

  @override
  String get csReportBtn => 'Report Scam';

  @override
  String get csBeFirst => 'Be the first to warn your community';

  @override
  String get csFilterByCity => 'Filter by City';

  @override
  String get csCityHint => 'City (e.g. Mumbai)';

  @override
  String get fbBothReq =>
      'Please provide both the sender and the message body.';

  @override
  String get fbTitle => 'Fake Bank SMS Detector';

  @override
  String get fbVerify => 'Verify before you trust';

  @override
  String get fbSender => 'Sender';

  @override
  String get fbBody => 'Message body';

  @override
  String get fbPaste => 'Paste';

  @override
  String get fbCheck => 'Check authenticity';

  @override
  String get fbWhy => 'Why this verdict';

  @override
  String get fbNext => 'Recommended next steps';

  @override
  String get lsEnterUrl => 'Please enter a URL to scan';

  @override
  String get lsTitle => 'Link Scanner';

  @override
  String get lsEnterToScan => 'Enter URL to scan';

  @override
  String get lsRecent => 'Recent Scans';

  @override
  String get lsCopied => 'URL copied';

  @override
  String get lsRisk => 'Risk Score';

  @override
  String get evAdd => 'Add Evidence';

  @override
  String get evDescOpt => 'Description (optional)';

  @override
  String get evUploaded => 'Evidence uploaded';

  @override
  String get evEmpty => 'Evidence Locker is empty';

  @override
  String get evEmptyBody => 'Store screenshots, audio, and documents here';

  @override
  String get evDeleteQ => 'Delete Evidence?';

  @override
  String get evCannotUndo => 'This action cannot be undone.';
}

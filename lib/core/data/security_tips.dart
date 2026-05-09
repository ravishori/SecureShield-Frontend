/// 100 rotating security awareness tips shown on the banner.
const List<(String, String)> kSecurityTips = [
  // OTP & Password safety
  ('🔒', 'Never share your OTP — not even with bank officials or support staff'),
  ('🔑', 'Use a different password for every account you own'),
  ('💪', 'A strong password has 12+ characters, numbers, and special symbols'),
  ('🔐', 'Enable two-factor authentication on all important accounts'),
  ('🚫', 'Never use your name, birthday, or "123456" as your password'),
  ('📱', 'Do not save passwords in your browser on shared or public devices'),
  ('🗝️', 'Change your passwords every 90 days for financial accounts'),
  ('🤫', 'Your OTP is your digital key — guard it like your ATM PIN'),
  ('⛔', 'Banks will NEVER ask for your OTP, PIN, or CVV over a phone call'),
  ('🔏', 'Use a password manager instead of writing passwords on paper'),

  // Phishing & Scam Links
  ('⚠️', 'Verify any link before clicking — fake sites steal your data'),
  ('🎣', 'Phishing emails mimic banks and companies — check the sender address carefully'),
  ('🌐', 'Always check for "https://" and a padlock icon before entering your details'),
  ('🔍', 'Hover over links to see the real URL before you click'),
  ('📧', 'Do not open email attachments from unknown senders'),
  ('💬', 'Suspicious SMS with links? Delete immediately — do NOT click'),
  ('🛑', 'Too-good-to-be-true offers online are almost always scams'),
  ('🏦', 'Banks never send links asking you to update KYC via SMS'),
  ('🔗', 'Short URLs can hide dangerous websites — use a URL expander first'),
  ('🎁', '"You have won a prize!" messages are almost always phishing attempts'),

  // Financial Fraud
  ('💳', 'Cover the ATM keypad when entering your PIN — cameras can record it'),
  ('🏧', 'Inspect ATM card slots for skimming devices before inserting your card'),
  ('📞', 'If someone calls claiming to be from your bank — hang up and call the official number'),
  ('💸', 'Never transfer money to "verify" your account — banks don\'t work this way'),
  ('🤝', 'Online buyers who overpay and ask for a refund are running a scam'),
  ('📲', 'Do not scan QR codes sent by strangers to "receive" money'),
  ('💰', 'UPI fraud alert: "Request Money" means YOU pay — not receive'),
  ('🛒', 'Shop only on verified websites with secure payment gateways'),
  ('📑', 'Read your bank statements monthly to spot unauthorized transactions'),
  ('🚨', 'Report any unauthorized transaction within 3 days for best protection'),

  // Device Security
  ('📱', 'Lock your phone with a PIN, fingerprint, or face recognition'),
  ('🔄', 'Keep your phone\'s OS and apps updated to patch security holes'),
  ('🦠', 'Install apps only from official stores — Google Play or Apple App Store'),
  ('🔋', 'Avoid charging your phone via public USB ports — use a power bank instead'),
  ('🛡️', 'Enable remote wipe on your phone in case it gets lost or stolen'),
  ('📡', 'Turn off Bluetooth and NFC when not in use'),
  ('🕵️', 'Review app permissions — most apps don\'t need access to your contacts or camera'),
  ('🔧', 'A rooted or jailbroken phone is more vulnerable to malware — avoid it'),
  ('💾', 'Back up your phone data weekly to protect against ransomware'),
  ('🔒', 'Use app lock for banking and payment apps for an extra layer of security'),

  // Wi-Fi & Network
  ('📶', 'Avoid using public Wi-Fi for banking or shopping — use mobile data instead'),
  ('🛜', 'Use a VPN when connecting to public or hotel Wi-Fi networks'),
  ('🔐', 'Change your home Wi-Fi password from the factory default immediately'),
  ('📡', 'Hide your Wi-Fi SSID (network name) to reduce visibility to attackers'),
  ('🌐', 'Check which devices are connected to your Wi-Fi — remove unknown ones'),
  ('🔒', 'Use WPA3 encryption on your home router if supported'),
  ('⚡', 'Free public Wi-Fi hotspots may be fake "evil twin" networks — be careful'),
  ('🛡️', 'Disable auto-connect to known Wi-Fi networks on your device'),

  // Social Media & Privacy
  ('👁️', 'Set your social media profiles to private — strangers don\'t need your info'),
  ('📸', 'Never post photos of your Aadhaar, PAN card, or boarding pass online'),
  ('🗓️', 'Don\'t share your travel plans publicly — it tells burglars you\'re away'),
  ('🤳', 'Oversharing personal details on social media makes you a target for scammers'),
  ('🔍', 'Google yourself regularly to see what personal data is publicly available'),
  ('📱', 'Log out of social media on shared or borrowed devices'),
  ('🚫', 'Avoid taking quizzes that ask for personal details — they harvest data'),
  ('📧', 'Use a separate email for social media and shopping — not your bank email'),

  // Job Fraud & Online Scams
  ('💼', 'Legitimate employers will never ask for money to process your job application'),
  ('🎯', 'Work-from-home jobs that promise high pay for little effort are almost always scams'),
  ('📋', 'Verify any job offer through official company websites before sharing documents'),
  ('💻', 'Freelance platforms with "advance payment" requirements are red flags'),
  ('🏆', 'Contest winners are not asked to pay "processing fees" — that\'s a scam'),
  ('🔎', 'Research the company name + "scam" or "fraud" online before proceeding'),
  ('📑', 'Never send copies of your Aadhaar or PAN to unverified recruiters'),

  // SIM & Mobile Security
  ('📞', 'Beware of SIM swap fraud — call your operator if your SIM stops working'),
  ('🔔', 'Enable SMS alerts for all your bank and card transactions'),
  ('📵', 'Do not share your mobile number publicly on unknown websites'),
  ('🔒', 'Set a SIM lock PIN to protect your SIM if your phone is stolen'),
  ('📲', 'Register your mobile number with TRAI\'s DND service to reduce spam calls'),

  // Cyber Bullying & Digital Wellbeing
  ('🤝', 'Report and block — don\'t engage with cyberbullies or online harassers'),
  ('📸', 'Never send private photos to anyone online — they can be misused'),
  ('🛑', 'Online blackmail? Screenshot the evidence and report to cybercrime.gov.in'),
  ('👨‍👩‍👧', 'Talk to your children about online safety and set parental controls'),
  ('🧠', 'Think before you post — everything online can be permanent'),

  // Emergency Response
  ('📞', 'Dial 1930 immediately if you fall victim to any cyber fraud'),
  ('🌐', 'Report cyber crime online at cybercrime.gov.in — available 24x7'),
  ('🏦', 'Block your cards immediately via net banking if you suspect fraud'),
  ('📱', 'Save the National Cyber Helpline 1930 in your contacts right now'),
  ('⏱️', 'Time matters — report financial fraud within 30 minutes for best recovery chances'),
  ('📋', 'Document everything — screenshots, transaction IDs, phone numbers'),
  ('👮', 'File a local police complaint AND an online complaint for full legal coverage'),

  // Email Security
  ('📧', 'Enable spam filters on your email to block phishing attempts automatically'),
  ('🔐', 'Use a strong, unique password for your email — it\'s the key to all other accounts'),
  ('🔍', 'Check the sender\'s actual email address — not just the display name'),
  ('🚫', 'Do not "unsubscribe" from spam emails — it confirms your address is active'),
  ('📎', 'Compressed (.zip) email attachments from strangers often contain malware'),

  // Identity Protection
  ('🪪', 'Store physical copies of Aadhaar and PAN in a secure place'),
  ('🔒', 'Use masked Aadhaar (last 4 digits) for non-official verification purposes'),
  ('🧾', 'Check your CIBIL credit report every 6 months for suspicious activity'),
  ('🔏', 'Never leave Aadhaar copies with unverified or unauthorized individuals'),

  // Daily Security Habits
  ('🛡️', 'Scan your phone monthly for malware using a trusted security app'),
  ('🔄', 'Sign out of accounts you\'re not actively using on all devices'),
  ('📅', 'Set a monthly reminder to review your app permissions and subscriptions'),
  ('🧹', 'Clear your browser history and cache regularly on shared devices'),
  ('🔦', 'SecureShield AI monitors your digital safety 24x7 — trust the shield'),
  ('🌟', 'Stay alert, stay safe — cyber awareness is your strongest defense'),
  ('💡', 'Share cyber safety tips with elderly family members — they are prime targets'),
  ('🔐', 'Your digital identity is as valuable as your physical identity — protect it'),
];

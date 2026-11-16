import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/security/banking_threat_provider.dart';
import '../../banking_protection/widgets/banking_threat_strip.dart';
import '../ai_coach_api.dart';

/// AI Coach chat — Material 3 theme-aware, with markdown rendering and
/// language-aware assistant responses (Claude replies in the user's
/// chosen UI language).
class AiCoachScreen extends ConsumerStatefulWidget {
  const AiCoachScreen({super.key});

  @override
  ConsumerState<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends ConsumerState<AiCoachScreen> {
  final _api = AiCoachApi();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Message> _messages = [];
  String? _sessionId;
  bool _sending = false;

  /// Localised welcome messages keyed by ISO 639-1 code.
  static const _welcomeByLang = <String, String>{
    'en': 'Hello! I am **SecureShield AI Coach**. I can help you stay safe '
        'online, identify scams, and protect your digital life. What would '
        'you like to know?',
    'hi': 'नमस्ते! मैं **SecureShield AI Coach** हूं। मैं आपको ऑनलाइन सुरक्षित '
        'रहने, धोखाधड़ी पहचानने और अपनी डिजिटल ज़िंदगी सुरक्षित करने में '
        'मदद कर सकता हूं। आप क्या जानना चाहेंगे?',
    'mr': 'नमस्कार! मी **SecureShield AI Coach** आहे. मी तुम्हाला ऑनलाइन '
        'सुरक्षित राहण्यास, फसवणूक ओळखण्यास आणि तुमचे डिजिटल जीवन '
        'सुरक्षित ठेवण्यास मदत करू शकतो. तुम्हाला काय जाणून घ्यायचे आहे?',
    'bn': 'নমস্কার! আমি **SecureShield AI Coach**। আমি আপনাকে অনলাইনে '
        'নিরাপদ থাকতে, প্রতারণা চিনতে এবং আপনার ডিজিটাল জীবন সুরক্ষিত '
        'রাখতে সাহায্য করতে পারি। আপনি কী জানতে চান?',
    'ta': 'வணக்கம்! நான் **SecureShield AI Coach**. ஆன்லைனில் '
        'பாதுகாப்பாக இருக்கவும், மோசடிகளை அடையாளம் காணவும், உங்கள் '
        'டிஜிட்டல் வாழ்க்கையை பாதுகாக்கவும் நான் உதவ முடியும். நீங்கள் '
        'என்ன தெரிந்துகொள்ள விரும்புகிறீர்கள்?',
    'te': 'నమస్తే! నేను **SecureShield AI Coach**. మీరు ఆన్‌లైన్‌లో సురక్షితంగా '
        'ఉండడంలో, మోసాలను గుర్తించడంలో మరియు మీ డిజిటల్ జీవితాన్ని '
        'రక్షించడంలో నేను సహాయపడగలను. మీరు ఏమి తెలుసుకోవాలనుకుంటున్నారు?',
  };

  /// Localised quick-suggestion chips.
  static const _suggestionsByLang = <String, List<String>>{
    'en': [
      'How to spot OTP fraud?',
      'Is this app safe?',
      'What is phishing?',
      'How to report cybercrime?',
      'How to secure my phone?',
    ],
    'hi': [
      'OTP धोखाधड़ी कैसे पहचानें?',
      'क्या यह ऐप सुरक्षित है?',
      'फिशिंग क्या है?',
      'साइबर अपराध की शिकायत कैसे करें?',
      'मेरा फोन कैसे सुरक्षित करें?',
    ],
    'mr': [
      'OTP फसवणूक कशी ओळखावी?',
      'हे अॅप सुरक्षित आहे का?',
      'फिशिंग म्हणजे काय?',
      'सायबर गुन्ह्याची तक्रार कशी करावी?',
      'माझा फोन सुरक्षित कसा ठेवावा?',
    ],
    'bn': [
      'OTP প্রতারণা কীভাবে চিনবেন?',
      'এই অ্যাপটি কি নিরাপদ?',
      'ফিশিং কী?',
      'সাইবার অপরাধের অভিযোগ কীভাবে করবেন?',
      'আপনার ফোন কীভাবে সুরক্ষিত রাখবেন?',
    ],
    'ta': [
      'OTP மோசடியை எப்படி கண்டறிவது?',
      'இந்த ஆப் பாதுகாப்பானதா?',
      'ஃபிஷிங் என்றால் என்ன?',
      'சைபர் குற்றத்தை எப்படி புகாரளிப்பது?',
      'என் தொலைபேசியை எப்படி பாதுகாக்கலாம்?',
    ],
    'te': [
      'OTP మోసాన్ని ఎలా గుర్తించాలి?',
      'ఈ యాప్ సురక్షితమేనా?',
      'ఫిషింగ్ అంటే ఏమిటి?',
      'సైబర్ నేరం గురించి ఎలా ఫిర్యాదు చేయాలి?',
      'నా ఫోన్‌ను ఎలా సురక్షితంగా ఉంచాలి?',
    ],
  };

  /// Localised "Ask about cyber safety…" hint.
  static const _hintByLang = <String, String>{
    'en': 'Ask about cyber safety…',
    'hi': 'साइबर सुरक्षा के बारे में पूछें…',
    'mr': 'सायबर सुरक्षेबद्दल विचारा…',
    'bn': 'সাইবার সুরক্ষা সম্পর্কে জিজ্ঞাসা করুন…',
    'ta': 'சைபர் பாதுகாப்பு பற்றி கேளுங்கள்…',
    'te': 'సైబర్ భద్రత గురించి అడగండి…',
  };

  /// Localised "Thinking…" indicator caption.
  static const _thinkingByLang = <String, String>{
    'en': 'Thinking…',
    'hi': 'सोच रहा हूं…',
    'mr': 'विचार करत आहे…',
    'bn': 'ভাবছি…',
    'ta': 'யோசிக்கிறேன்…',
    'te': 'ఆలోచిస్తున్నాను…',
  };

  String get _currentLang => ref.read(languageProvider);

  /// Keywords that indicate the user is asking about money / banking /
  /// authentication. When ANY user message in the current session contains
  /// one of these, we surface the banking-threat strip above the chat so
  /// any active threats are visible right when the user is making a
  /// decision about their bank or OTP.
  ///
  /// Multilingual — covers English + the 5 currently-translated languages
  /// so the strip fires even when the user types in Hindi/Tamil/etc.
  static const List<String> _bankingTopicKeywords = [
    // English
    'otp', 'bank', 'banking', 'upi', 'paytm', 'phonepe', 'gpay',
    'google pay', 'credit card', 'debit card', 'atm', 'transfer',
    'transaction', 'fraud', 'scam', 'phish', 'password', 'pin',
    'account', 'wallet', 'razorpay', 'cred', 'imps', 'neft',
    'rtgs', 'kyc', 'aadhaar', 'pan card', 'rupay',
    // Hindi (Devanagari)
    'ओटीपी', 'बैंक', 'पासवर्ड', 'धोखा', 'धोखाधड़ी', 'फ्रॉड', 'खाता',
    'पैसा', 'पैसे', 'भुगतान', 'क्रेडिट', 'डेबिट', 'यूपीआई', 'पेटीएम',
    // Marathi
    'बँक', 'फसवणूक', 'पैसे', 'खाते',
    // Bengali
    'ওটিপি', 'ব্যাংক', 'পাসওয়ার্ড', 'প্রতারণা', 'টাকা', 'অ্যাকাউন্ট',
    // Tamil
    'வங்கி', 'கடவுச்சொல்', 'மோசடி', 'கணக்கு', 'பணம்',
    // Telugu
    'బ్యాంక్', 'పాస్‌వర్డ్', 'మోసం', 'ఖాతా', 'డబ్బు',
  ];

  /// Returns true if any user message so far mentions a banking-related
  /// keyword. Cheap O(n·m) scan — there are usually <20 messages.
  bool _conversationMentionsBanking() {
    for (final m in _messages) {
      if (m.role != 'user') continue;
      final lower = m.content.toLowerCase();
      for (final keyword in _bankingTopicKeywords) {
        if (lower.contains(keyword)) return true;
      }
    }
    return false;
  }

  String get _welcome =>
      _welcomeByLang[_currentLang] ?? _welcomeByLang['en']!;

  List<String> get _suggestions =>
      _suggestionsByLang[_currentLang] ?? _suggestionsByLang['en']!;

  String get _hint => _hintByLang[_currentLang] ?? _hintByLang['en']!;

  String get _thinking =>
      _thinkingByLang[_currentLang] ?? _thinkingByLang['en']!;

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
    // Defer welcome until the first build so we can read the language provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _messages.isEmpty) {
        setState(() {
          _messages.add(_Message(role: 'assistant', content: _welcome));
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    final userText = text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(_Message(role: 'user', content: userText));
      _sending = true;
    });
    _scrollToBottom();

    try {
      // Send the user's chosen language so Claude replies in it.
      final response = await _api.chat(
        message: userText,
        sessionId: _sessionId,
        language: _currentLang,
      );
      if (mounted) {
        setState(() {
          _sessionId = response['session_id'] as String?;
          _messages.add(_Message(
            role: 'assistant',
            content: response['reply'] as String? ?? '',
          ));
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_Message(
            role: 'assistant',
            content: _errorMessage(e),
          ));
          _sending = false;
        });
        _scrollToBottom();
      }
    }
  }

  /// Localised, exception-aware error message. Distinguishes timeouts
  /// (long AI response) from connection failures and auth errors so the
  /// user gets actionable feedback instead of a generic "I cannot respond".
  String _errorMessage(Object e) {
    final kind = _classifyError(e);
    final lang = _currentLang;
    return _errorByKindAndLang[kind]?[lang]
        ?? _errorByKindAndLang[kind]?['en']
        ?? _errorByKindAndLang['generic']!['en']!;
  }

  /// Return a string error-kind key that maps into [_errorByKindAndLang].
  ///
  /// Possible kinds: aiSlow / connect / auth / rateLimited / server / generic.
  /// Keys match the top-level keys of the localized error map below.
  static String _classifyError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
          return 'connect';
        case DioExceptionType.receiveTimeout:
          // Receive timeout means Claude is generating but slow — common
          // for long Hindi / Bengali / Tamil responses with Devanagari /
          // other scripts that emit ~2-3× more tokens per word.
          return 'aiSlow';
        case DioExceptionType.connectionError:
          return 'connect';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode ?? 0;
          // The server answers 503 + X-AI-Status: disabled while external AI processing is switched off.
          if (e.response?.headers.value('x-ai-status') == 'disabled') return 'aiDisabled';
          if (code == 401) return 'auth';
          if (code == 429) return 'rateLimited';
          if (code >= 500) return 'server';
          return 'generic';
        default:
          return 'generic';
      }
    }
    return 'generic';
  }

  static const Map<String, Map<String, String>> _errorByKindAndLang = {
    'aiDisabled': {
      'en': 'The AI coach is switched off for now, so it cannot answer. Nothing you typed was sent to an AI service. '
          'Our built-in checks (message analyser, link scanner) still work.',
    },
    'aiSlow': {
      'en': '_The AI is taking longer than expected to respond._ It happens '
          'sometimes with long answers — please tap **Send** again or try '
          'a shorter question.',
      'hi': '_AI को जवाब देने में अधिक समय लग रहा है।_ कभी-कभी लंबे जवाबों '
          'में ऐसा होता है — कृपया फिर से **भेजें** दबाएं या छोटा सवाल '
          'पूछें।',
      'mr': '_AI ला उत्तर द्यायला अपेक्षेपेक्षा जास्त वेळ लागत आहे._ '
          'मोठ्या उत्तरांसाठी असे कधी कधी होते — कृपया पुन्हा **पाठवा** दाबा '
          'किंवा छोटा प्रश्न विचारा.',
      'bn': '_AI উত্তর দিতে আশানুরূপের চেয়ে বেশি সময় নিচ্ছে।_ লম্বা '
          'উত্তরের সময় কখনও কখনও এটি ঘটে — অনুগ্রহ করে আবার **পাঠান** '
          'টিপুন বা ছোট প্রশ্ন করুন।',
      'ta': '_AI பதிலளிக்க எதிர்பார்த்ததை விட அதிக நேரம் எடுக்கிறது._ '
          'நீண்ட பதில்களுக்கு இது சில நேரம் நிகழ்கிறது — தயவுசெய்து '
          'மீண்டும் **அனுப்பு** ஐ அழுத்தவும் அல்லது சிறிய கேள்வி கேட்கவும்.',
      'te': '_AI సమాధానం ఇవ్వడానికి అంచనా కంటే ఎక్కువ సమయం తీసుకుంటోంది._ '
          'పొడవైన సమాధానాలతో ఇది కొన్నిసార్లు జరుగుతుంది — దయచేసి '
          'మళ్లీ **పంపండి** నొక్కండి లేదా చిన్న ప్రశ్న అడగండి.',
    },
    'connect': {
      'en': '_Cannot reach the SecureShield server right now._ Please check '
          'your Wi-Fi or mobile data and try again.',
      'hi': '_SecureShield सर्वर से कनेक्ट नहीं हो पा रहा है।_ कृपया अपना '
          'Wi-Fi या मोबाइल डेटा जांचें और फिर कोशिश करें।',
      'mr': '_SecureShield सर्व्हरशी कनेक्ट होऊ शकत नाही._ कृपया तुमचे Wi-Fi '
          'किंवा मोबाइल डेटा तपासा आणि पुन्हा प्रयत्न करा.',
      'bn': '_SecureShield সার্ভারে এখন পৌঁছানো যাচ্ছে না।_ আপনার Wi-Fi '
          'বা মোবাইল ডেটা চেক করে আবার চেষ্টা করুন।',
      'ta': '_SecureShield சேவையகத்தை இப்போது அடைய முடியவில்லை._ '
          'உங்கள் Wi-Fi அல்லது மொபைல் டேட்டாவை சரிபார்த்து மீண்டும் '
          'முயற்சிக்கவும்.',
      'te': '_ఇప్పుడు SecureShield సర్వర్‌కు చేరుకోలేకపోతున్నాను._ మీ Wi-Fi '
          'లేదా మొబైల్ డేటాను తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.',
    },
    'auth': {
      'en': '_Your session has expired._ Please log out and log in again.',
      'hi': '_आपका सत्र समाप्त हो गया है।_ कृपया लॉग आउट करके फिर से लॉग इन करें।',
      'mr': '_तुमचे सत्र समाप्त झाले आहे._ कृपया लॉग आऊट करा आणि पुन्हा लॉग इन करा.',
      'bn': '_আপনার সেশন শেষ হয়ে গেছে।_ অনুগ্রহ করে লগ আউট করে আবার লগ ইন করুন।',
      'ta': '_உங்கள் அமர்வு காலாவதியானது._ வெளியேறி மீண்டும் உள்நுழையவும்.',
      'te': '_మీ సెషన్ గడువు ముగిసింది._ లాగ్ అవుట్ చేసి మళ్లీ లాగిన్ చేయండి.',
    },
    'rateLimited': {
      'en': '_Too many questions in a short time._ Please wait a minute before '
          'asking again.',
      'hi': '_थोड़े समय में बहुत सारे प्रश्न पूछे गए हैं।_ कृपया एक मिनट प्रतीक्षा करें।',
      'mr': '_कमी वेळेत खूप प्रश्न विचारले गेले._ कृपया एक मिनिट थांबा.',
      'bn': '_অল্প সময়ে অনেক প্রশ্ন করা হয়েছে।_ এক মিনিট অপেক্ষা করুন।',
      'ta': '_குறுகிய நேரத்தில் அதிக கேள்விகள்._ ஒரு நிமிடம் காத்திருக்கவும்.',
      'te': '_తక్కువ సమయంలో చాలా ప్రశ్నలు._ ఒక నిమిషం వేచి ఉండండి.',
    },
    'server': {
      'en': '_The SecureShield server is having trouble._ Our team has been '
          'notified — please try again in a few minutes.',
      'hi': '_SecureShield सर्वर में समस्या है।_ हमारी टीम को सूचित कर दिया गया है '
          '— कुछ मिनटों में फिर से कोशिश करें।',
      'mr': '_SecureShield सर्व्हरमध्ये अडचण आहे._ आमच्या टीमला कळवले आहे — '
          'काही मिनिटांत पुन्हा प्रयत्न करा.',
      'bn': '_SecureShield সার্ভারে সমস্যা হচ্ছে।_ আমাদের টিমকে জানানো '
          'হয়েছে — কয়েক মিনিট পরে আবার চেষ্টা করুন।',
      'ta': '_SecureShield சேவையகத்தில் சிக்கல் உள்ளது._ எங்கள் குழுவிற்கு '
          'அறிவிக்கப்பட்டது — சில நிமிடங்களில் மீண்டும் முயற்சிக்கவும்.',
      'te': '_SecureShield సర్వర్‌లో సమస్య ఉంది._ మా బృందానికి తెలియజేయబడింది '
          '— కొన్ని నిమిషాల్లో మళ్లీ ప్రయత్నించండి.',
    },
    'generic': {
      'en': '_Sorry, I am unable to respond right now._ Please check your '
          'connection and try again.',
      'hi': '_क्षमा करें, मैं अभी जवाब नहीं दे सकता।_ कृपया अपना इंटरनेट '
          'कनेक्शन जांचें और फिर से कोशिश करें।',
      'mr': '_क्षमस्व, मी आत्ता प्रतिसाद देऊ शकत नाही._ कृपया तुमचे इंटरनेट '
          'कनेक्शन तपासा आणि पुन्हा प्रयत्न करा.',
      'bn': '_দুঃখিত, আমি এখন উত্তর দিতে পারছি না।_ অনুগ্রহ করে আপনার '
          'কানেকশন চেক করে আবার চেষ্টা করুন।',
      'ta': '_மன்னிக்கவும், நான் இப்போது பதிலளிக்க முடியவில்லை._ உங்கள் '
          'இணைப்பை சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
      'te': '_క్షమించండి, నేను ఇప్పుడు సమాధానం ఇవ్వలేను._ దయచేసి మీ '
          'కనెక్షన్ తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.',
    },
  };

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the language provider so the screen rebuilds when the user
    // changes language — suggestions / hint / thinking caption update live.
    ref.watch(languageProvider);
    final cs = Theme.of(context).colorScheme;
    final suggestions = _suggestions;

    return Column(
      children: [
        // ── Suggestions ─────────────────────────────────────────────────
        if (_messages.length <= 1)
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: suggestions.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(suggestions[i]),
                  labelStyle: TextStyle(
                    color: cs.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: cs.primary.withValues(alpha: 0.08),
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
                  onPressed: () => _send(suggestions[i]),
                ),
              ),
            ),
          ),

        // ── Contextual banking-threat strip ─────────────────────────────
        // Only renders when:
        //   1. The user has mentioned banking/OTP/scam in the conversation, AND
        //   2. The shared correlator reports active threats.
        //
        // The strip slips in non-intrusively at the top of the chat area
        // so the user sees the warning while they're typing about something
        // sensitive — without breaking the conversation flow.
        if (_conversationMentionsBanking())
          Consumer(builder: (_, ref, __) {
            final report = ref.watch(bankingThreatReportProvider);
            if (report == null || !report.hasThreats) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: BankingThreatStrip(
                report: report,
                margin: EdgeInsets.zero,
              ),
            );
          }),

        // ── Messages ────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _sending) {
                return _TypingBubble(caption: _thinking);
              }
              return _ChatBubble(message: _messages[index]);
            },
          ),
        ),

        // ── Input area ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              top: BorderSide(color: cs.outlineVariant, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: cs.onSurface, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: _hint,
                      hintStyle: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(
                          color: cs.outlineVariant,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(color: cs.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: _send,
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _sending
                      ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                      : cs.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _sending
                        ? null
                        : () => _send(_messageController.text),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(
                        _sending ? Icons.hourglass_top_rounded : Icons.send_rounded,
                        color: cs.onPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Message {
  final String role;
  final String content;
  _Message({required this.role, required this.content});
}

// ────────────────────────────────────────────────────────────────────────────
// Chat bubble — assistant uses markdown rendering, user uses plain text
// ────────────────────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final _Message message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.role == 'user';

    final bg = isUser ? cs.primary : cs.surfaceContainerHigh;
    final fg = isUser ? cs.onPrimary : cs.onSurface;
    final border = isUser ? null : Border.all(color: cs.outlineVariant);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isUser ? 14 : 14,
          vertical: isUser ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: border,
          boxShadow: isUser
              ? null
              : [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: isUser
            ? SelectableText(
                message.content,
                style: TextStyle(color: fg, fontSize: 15, height: 1.45),
              )
            : _AssistantMarkdown(content: message.content, color: fg),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Markdown renderer for assistant messages
// Renders **bold**, *italic*, # Headings, lists, code, links properly
// ────────────────────────────────────────────────────────────────────────────
class _AssistantMarkdown extends StatelessWidget {
  final String content;
  final Color color;

  const _AssistantMarkdown({required this.content, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final style = MarkdownStyleSheet(
      // Body text
      p: TextStyle(color: color, fontSize: 15, height: 1.5),
      // Headings
      h1: TextStyle(
        color: color,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.3,
      ),
      h2: TextStyle(
        color: color,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.3,
      ),
      h3: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      h4: TextStyle(
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      // Bold + italic
      strong: TextStyle(color: color, fontWeight: FontWeight.w800),
      em: TextStyle(color: color, fontStyle: FontStyle.italic),
      // Lists
      listBullet: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 15),
      listIndent: 20,
      // Code
      code: TextStyle(
        color: cs.primary,
        backgroundColor: cs.primary.withValues(alpha: 0.08),
        fontFamily: 'monospace',
        fontSize: 13.5,
      ),
      codeblockDecoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      // Block quote
      blockquoteDecoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      blockquote: TextStyle(
        color: color.withValues(alpha: 0.85),
        fontStyle: FontStyle.italic,
      ),
      // Horizontal rule
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      // Links
      a: TextStyle(
        color: cs.primary,
        decoration: TextDecoration.underline,
        decorationColor: cs.primary,
      ),
      // Tables
      tableBorder: TableBorder.all(color: cs.outlineVariant, width: 1),
      tableHead: TextStyle(color: color, fontWeight: FontWeight.w700),
      tableBody: TextStyle(color: color, fontSize: 14),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      // Vertical spacing between blocks
      h1Padding: const EdgeInsets.only(top: 8, bottom: 4),
      h2Padding: const EdgeInsets.only(top: 8, bottom: 4),
      h3Padding: const EdgeInsets.only(top: 6, bottom: 4),
      pPadding: const EdgeInsets.only(bottom: 4),
      blockSpacing: 8,
    );

    return MarkdownBody(
      data: content,
      styleSheet: style,
      selectable: true,
      onTapLink: (text, href, title) async {
        if (href == null) return;
        await Clipboard.setData(ClipboardData(text: href));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Link copied: $href'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Animated typing indicator (three dots) — caption is localized via param
// ────────────────────────────────────────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  final String caption;
  const _TypingBubble({this.caption = 'Thinking…'});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final phase = (_ctrl.value + i * 0.2) % 1.0;
                    final opacity = 0.3 + 0.7 * (1 - (phase * 2 - 1).abs()).clamp(0, 1);
                    return Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: opacity),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(width: 8),
            Text(
              widget.caption,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

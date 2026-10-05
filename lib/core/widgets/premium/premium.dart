/// Premium widget library — barrel export.
///
///   import 'package:secureshield_app/core/widgets/premium/premium.dart';
///
/// The design-system tokens (SpacingTokens / RadiusTokens / MotionTokens /
/// SecurityStatusColors / etc.) are re-exported here, so a single import
/// gives you every premium widget AND the tokens they depend on.
library;

// Design-system tokens — re-exported so consumers only need one import.
export '../../design_system/tokens.dart';

// Foundation widgets
export 'glass_card.dart';
export 'shimmer_loader.dart';

// Hero + status widgets
export 'security_score_gauge.dart';
export 'animated_shield.dart';
export 'rotating_status_text.dart';
export 'ai_status_panel.dart';

// Metrics + feeds
export 'count_up_number.dart';
export 'metric_card.dart';
export 'live_activity_feed.dart';
export 'threat_ticker.dart';

// Actions
export 'premium_action_card.dart';
export 'quick_action_chips.dart';
export 'floating_ai_assistant.dart';

// Alerts
export 'premium_warning_card.dart';

// Ambience
export 'animated_grid_background.dart';

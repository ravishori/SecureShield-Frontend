import 'package:flutter/material.dart';

import '../privacy_content.dart';

/// The privacy notice, readable before an account exists. Each section is a heading for screen-reader navigation.
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(kNoticeTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Semantics(
              liveRegion: false,
              child: Text(kNoticeStatus, key: const Key('noticeStatus'), style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: 12),
            for (final s in kPrivacyNotice) ...[
              Semantics(
                header: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 6),
                  child: Text(s.heading, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
              for (final p in s.paragraphs)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(p)),
              for (final b in s.bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ExcludeSemantics(child: Text('•  ')),
                      Expanded(child: Text(b)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

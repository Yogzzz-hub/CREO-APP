import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_card.dart';

/// The 5 setup steps shown to a client, same as the web portal.
const setupSteps = [
  'Verify email',
  'Sign agreement',
  'Choose plan',
  'Brand questionnaire',
  'Launch workspace',
];

/// Maps the backend onboarding stage (0..8) to the current setup step (1..5).
int setupCurrentStep(int stage) => stage <= 0
    ? 1
    : stage == 1
    ? 2
    : stage == 2
    ? 3
    : stage <= 7
    ? 4
    : 5;

/// What the client should do next, as (action, description).
(String, String) setupResume(int stage) => switch (stage) {
  <= 0 => (
    'Verify your email',
    'Confirm your email address to start setting up your workspace.',
  ),
  1 => (
    'Sign the service agreement',
    'Review and accept the Master Service Agreement to unlock plan selection.',
  ),
  2 => (
    'Choose your plan',
    'Pick a production plan to activate your creative pod and content pipeline.',
  ),
  3 => (
    'Complete brand questionnaire',
    'Payment received. Tell us about your brand so we can build your Brand DNA.',
  ),
  _ => (
    'Finalize & launch workspace',
    'Your answers are saved. Generate your Brand DNA to assign your pod and calendar.',
  ),
};

/// Dashboard card shown while onboarding is incomplete.
class SetupProgressCard extends StatelessWidget {
  const SetupProgressCard({
    super.key,
    required this.stage,
    required this.onResume,
    required this.onBookCall,
  });

  final int stage;
  final VoidCallback onResume;
  final VoidCallback onBookCall;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? CreoColors.ivory : CreoColors.lightEspresso;
    final mist = isDark ? CreoColors.mist : CreoColors.lightMist;
    final current = setupCurrentStep(stage);
    final done = current - 1;
    final (action, description) = setupResume(stage);
    final paid = stage >= 3;

    return CreoCard(
      padding: const EdgeInsets.all(18),
      borderColor: CreoColors.terracotta.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: CreoColors.terracotta.withValues(alpha: 0.1),
              border: Border.all(
                color: CreoColors.terracotta.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '● SETUP INCOMPLETE · $done OF ${setupSteps.length} STEPS DONE',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: CreoColors.terracotta,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your production pipeline starts once setup is done',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: mist),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < setupSteps.length; i++)
                Expanded(
                  child: _StepDot(
                    number: i + 1,
                    label: setupSteps[i],
                    done: i + 1 <= done,
                    current: i + 1 == current,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('setup-resume'),
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? CreoColors.ivory : CreoColors.lightEspresso,
                foregroundColor: isDark ? CreoColors.onAmber : CreoColors.ivory,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onResume,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                'Resume: $action',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (!paid) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('setup-book-call'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CreoColors.amber,
                  side: BorderSide(
                    color: CreoColors.amber.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onBookCall,
                icon: const Icon(Icons.phone_in_talk_outlined, size: 18),
                label: const Text(
                  'Call & bargain a custom plan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.number,
    required this.label,
    required this.done,
    required this.current,
  });

  final int number;
  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mist = isDark ? CreoColors.mist : CreoColors.lightMist;
    final ink = isDark ? CreoColors.ivory : CreoColors.lightEspresso;
    final fill = done
        ? CreoColors.amber
        : current
        ? CreoColors.terracotta
        : Colors.transparent;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: done || current
                ? null
                : Border.all(
                    color: isDark ? CreoColors.line : CreoColors.lightLine,
                  ),
            boxShadow: current
                ? [
                    BoxShadow(
                      color: CreoColors.terracotta.withValues(alpha: 0.25),
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: CreoColors.onAmber)
              : Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: current ? CreoColors.onAmber : mist,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            height: 1.2,
            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            color: current ? ink : done ? CreoColors.amber : mist,
          ),
        ),
      ],
    );
  }
}

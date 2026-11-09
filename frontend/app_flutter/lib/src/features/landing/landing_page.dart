import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/app_appearance.dart';
import 'landing_motion.dart';
import 'landing_portal_demo.dart';
import 'landing_deliverables.dart';

const _kWhatsAppUrl = 'https://wa.me/919941999415';

class _LandingFaqTransition extends StatelessWidget {
  const _LandingFaqTransition({
    required this.expanded,
    required this.reduced,
    required this.child,
  });
  final bool expanded;
  final bool reduced;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduced) {
      return expanded ? child : SizedBox(width: double.infinity);
    }
    return AnimatedCrossFade(
      firstChild: SizedBox(width: double.infinity),
      secondChild: child,
      crossFadeState: expanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: Duration(milliseconds: 450),
      firstCurve: landingExpo,
      secondCurve: landingExpo,
      sizeCurve: landingExpo,
    );
  }
}

// ── Models ───────────────────────────────────────────────────────────────────
class _PodRole {
  final String role;
  final String title;
  final String about;
  final IconData icon;
  final String tag;
  const _PodRole({
    required this.role,
    required this.title,
    required this.about,
    required this.icon,
    required this.tag,
  });
}

const _kPodRoles = [
  _PodRole(
    role: 'Creative lead',
    title: 'Brand DNA & Strategy Director',
    about:
        'Owns your Brand DNA and content calendar. Your single point of contact who translates business goals into viral briefs.',
    icon: Icons.lightbulb_rounded,
    tag: 'Single POC',
  ),
  _PodRole(
    role: 'Video editor',
    title: 'Senior Motion & 4K Reel Specialist',
    about:
        'Cuts your reels, retention hooks and story sets. Color grades and sound designs so every frame looks cinema-grade.',
    icon: Icons.movie_filter_rounded,
    tag: 'Retention Hooks',
  ),
  _PodRole(
    role: 'Designer',
    title: 'Visual Identity & Carousel Architect',
    about:
        'Builds high-converting swipe carousels and static drops on your brand typography and design system.',
    icon: Icons.palette_rounded,
    tag: 'High Conversion',
  ),
  _PodRole(
    role: 'You',
    title: 'The Visionary & Decision Maker',
    about:
        'Review every batch in your portal. Approve in one click, or decline with feedback and the pod revises automatically.',
    icon: Icons.verified_user_rounded,
    tag: 'One-Click Signoff',
  ),
];

class _PlanTier {
  final String name;
  final String turnaround;
  final String subtitle;
  final List<String> highlights;
  final bool isPopular;
  const _PlanTier({
    required this.name,
    required this.turnaround,
    required this.subtitle,
    required this.highlights,
    this.isPopular = false,
  });
}

const _kPlans = [
  _PlanTier(
    name: 'Starter',
    turnaround: '3 business days SLA',
    subtitle: 'For emerging D2C brands establishing weekly momentum.',
    highlights: [
      'Dedicated lead, editor & designer',
      'Brand DNA onboarding on day 1',
      'Weekly batches of reels & carousels',
      'One-click approval portal',
      'Month-to-month, cancel anytime',
    ],
  ),
  _PlanTier(
    name: 'Growth',
    turnaround: '2 business days SLA',
    subtitle: 'Accelerated creative output for aggressive acquisition.',
    highlights: [
      'Everything in Starter',
      '48-hour priority batch delivery',
      'Meta & TikTok ad hook variants',
      'Dynamic story sales sequences',
      'Dedicated monthly strategy review',
    ],
    isPopular: true,
  ),
  _PlanTier(
    name: 'Scale',
    turnaround: '24-hour turnaround',
    subtitle: 'Maximum creative throughput for category leaders.',
    highlights: [
      'Same-day priority revisions',
      'Dedicated backup editor & motion lead',
      'Unlimited variation testing',
      'Custom bespoke 3D & motion graphics',
      'Executive Slack channel access',
    ],
  ),
];

class _FaqItem {
  final String question;
  final String answer;
  final String? badge;
  const _FaqItem({required this.question, required this.answer, this.badge});
}

const _kFaqs = [
  _FaqItem(
    question: 'How does CREO streamline content creation for D2C brands?',
    answer:
        'CREO connects content briefs directly to creative leads and client sign-offs. Your briefs trigger automated SLA revision tickets and real-time deliverables tracking—eliminating delays and fragmented communication.',
    badge: 'Onboarding in <48 hours',
  ),
  _FaqItem(
    question:
        'What content deliverables are included in our monthly pod retainer?',
    answer:
        'Depending on your plan tier (Starter, Growth, or Scale), your pod delivers a fixed monthly volume of high-converting 9:16 reels, static/carousel brand posts, and interactive story sets.',
  ),
  _FaqItem(
    question: 'What are the guaranteed turnaround times for content batches?',
    answer:
        'Every deliverable batch is produced under strict SLA timelines: 3 business days for Starter, 2 business days for Growth, and 24-hour priority turnaround for Scale. If a batch is ever late, the next cycle is credited.',
  ),
  _FaqItem(
    question: 'How do revisions work inside the client portal?',
    answer:
        'You review draft assets in your portal. If revisions are needed, click Decline, enter your feedback note, and your pod will revise and resubmit within your plan quota.',
  ),
  _FaqItem(
    question: 'Can we upgrade, pause, or cancel our retainer anytime?',
    answer:
        'Yes. All Creo retainers operate on a month-to-month basis with no long-term lock-in. You can upgrade, pause renewal, or cancel anytime directly in your account.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Landing Page Widget
// ─────────────────────────────────────────────────────────────────────────────

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _headerKey = GlobalKey();
  final _scroll = ScrollController();
  final _principlesKey = GlobalKey();
  final _plansKey = GlobalKey();
  int _selectedRoleIndex = 0;
  int _selectedCategoryIndex = 0;
  int? _expandedFaqIndex = 0;
  bool _navigating = false;
  final _sampleEmailCtrl = TextEditingController();
  final _sampleHandleCtrl = TextEditingController();
  String? _sampleNotice;

  @override
  void dispose() {
    _scroll.dispose();
    _sampleEmailCtrl.dispose();
    _sampleHandleCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigateToAuth({String defaultView = 'signin'}) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.of(
        context,
      ).pushNamed(defaultView == 'signup' ? '/signup' : '/login');
    } finally {
      _navigating = false;
    }
  }

  void _scrollTo(GlobalKey key) {
    final destination = key.currentContext;
    if (destination == null || !_scroll.hasClients) return;
    final target = destination.findRenderObject();
    if (target == null) return;
    final viewport = RenderAbstractViewport.maybeOf(target);
    if (viewport == null) return;
    final header = _headerKey.currentContext?.findRenderObject();
    final headerHeight = header is RenderBox && header.hasSize
        ? header.size.height
        : 0.0;
    final offset = (viewport.getOffsetToReveal(target, 0).offset - headerHeight)
        .clamp(
          _scroll.position.minScrollExtent,
          _scroll.position.maxScrollExtent,
        );
    _scroll.animateTo(
      offset,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Duration(milliseconds: 1400),
      curve: landingExpo,
    );
  }

  void _showDestinationGap(String destination) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'The $destination page is not available in the mobile app yet.',
        ),
      ),
    );
  }

  Widget _heading(String title, {double size = 32}) => LandingScrollHeading(
    scroll: _scroll,
    text: title,
    style: TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      fontWeight: FontWeight.w500,
      letterSpacing: -1,
      height: 1.05,
      color: context.creo.appInk,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: context.creo.appBase,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = constraints.maxHeight;
            return Stack(
              children: [
                CustomScrollView(
                  key: PageStorageKey('landing-scroll'),
                  controller: _scroll,
                  slivers: [
                    SliverMainAxisGroup(
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: LandingHeroDelegate(
                            height: viewport,
                            reduced: reduced,
                            onContinue: () => _scrollTo(_principlesKey),
                          ),
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 64),
                          KeyedSubtree(
                            key: _principlesKey,
                            child: _buildPrinciplesSection(),
                          ),
                          SizedBox(height: 80),
                          _buildPodSection(),
                          SizedBox(height: 80),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: _heading('Delivered every week'),
                          ),
                          LandingScene(
                            scroll: _scroll,
                            kind: LandingProp.mailbox,
                          ),
                          LandingReveal(
                            scroll: _scroll,
                            child: _buildDeliverablesShowcase(),
                          ),
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _showDestinationGap('/work'),
                                  child: Text('See the work'),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      _showDestinationGap('/portal'),
                                  child: Text('Explore the portal'),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 80),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: _heading('Review and approve in one click.'),
                          ),
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No cluttered email threads or lost Slack files. Everything arrives organized for rapid sign-off.',
                              style: TextStyle(
                                color: context.creo.appMist,
                                height: 1.5,
                              ),
                            ),
                          ),
                          LandingReveal(
                            scroll: _scroll,
                            mask: true,
                            child: LandingPortalDemo(),
                          ),
                          SizedBox(height: 80),
                          KeyedSubtree(
                            key: _plansKey,
                            child: _buildPlansSection(),
                          ),
                          SizedBox(height: 80),
                          _buildFaqSection(),
                          SizedBox(height: 80),
                          _buildSampleCtaSection(),
                          LandingScene(
                            scroll: _scroll,
                            kind: LandingProp.device,
                          ),
                          SizedBox(height: 40),
                          _buildFooter(),
                          SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: KeyedSubtree(
                    key: ValueKey('landing-navigation'),
                    child: _buildHeaderNav(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderNav() {
    final wordmark = TextButton(
      onPressed: () => _scroll.animateTo(
        0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 1400),
        curve: landingExpo,
      ),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: EdgeInsets.zero,
      ),
      child: Text.rich(
        TextSpan(
          text: 'creo',
          children: [
            TextSpan(
              text: '.',
              style: TextStyle(color: context.creo.accent),
            ),
          ],
        ),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
          color: context.creo.appInk,
        ),
      ),
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => _scrollTo(_plansKey),
          child: const Text('Pricing'),
        ),
        TextButton(
          onPressed: () => _navigateToAuth(defaultView: 'signin'),
          child: const Text('Sign in'),
        ),
        ElevatedButton(
          onPressed: () => _navigateToAuth(defaultView: 'signup'),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.creo.accent,
            foregroundColor: context.creo.onAccent,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          child: const Text('Get Started'),
        ),
      ],
    );
    return Container(
      key: _headerKey,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.creo.appSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.creo.appLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >
              620 * MediaQuery.textScalerOf(context).scale(1)) {
            return Row(
              children: [
                wordmark,
                const Spacer(),
                actions,
                const SizedBox(width: 12),
                const CreoThemeToggle(),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: wordmark,
                    ),
                  ),
                  const CreoThemeToggle(),
                ],
              ),
              const SizedBox(height: 4),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildPrinciplesSection() {
    const principles = [
      (
        'Your Brand DNA, first',
        'Day one, you upload your assets, fonts and guidelines. Your lead, editor and designer work from that Brand DNA, so every reel, carousel and story ships on-brand.',
      ),
      (
        'One pod, one portal',
        'No cluttered email threads, no lost Slack files. Drafts arrive in your portal, organised by batch. Approve in one click, or decline with a note and the pod revises within your plan’s quota.',
      ),
      (
        'The clock is public',
        'Every batch is timestamped by our SLA service: 3 business days on Starter, 2 on Growth, 24 hours on Scale. Late batch? Next cycle credited.',
      ),
      (
        'Month-to-month, always',
        'No long-term lock-in. Upgrade, pause renewal or cancel anytime. Your first batch lands within 7 days of signing up.',
      ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Built for brands, run by people.', size: 40),
          LandingScene(scroll: _scroll, kind: LandingProp.blocks, height: 300),
          ...principles.map(
            (p) => LandingReveal(
              scroll: _scroll,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.$1,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.8,
                        color: context.creo.appInk,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      p.$2,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        height: 1.6,
                        color: context.creo.appMist,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodSection() {
    final activeRole = _kPodRoles[_selectedRoleIndex];
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      color: Color(0xFF172338),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Your pod', size: 56),
          SizedBox(height: 32),
          ...List.generate(_kPodRoles.length, (idx) {
            final selected = _selectedRoleIndex == idx;
            return Semantics(
              selected: selected,
              child: Focus(
                onFocusChange: (focused) {
                  if (focused && mounted) {
                    setState(() => _selectedRoleIndex = idx);
                  }
                },
                child: MouseRegion(
                  onEnter: (_) => setState(() => _selectedRoleIndex = idx),
                  child: TextButton(
                    key: ValueKey('pod-role-$idx'),
                    onPressed: () => setState(() => _selectedRoleIndex = idx),
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: Size(double.infinity, 64),
                      foregroundColor: selected
                          ? context.creo.appInk
                          : context.creo.appMist,
                      shape: RoundedRectangleBorder(),
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: reduced
                          ? Duration.zero
                          : Duration(milliseconds: 300),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? context.creo.accent
                            : context.creo.appMist,
                      ),
                      child: Text(_kPodRoles[idx].role),
                    ),
                  ),
                ),
              ),
            );
          }),
          SizedBox(height: 48),
          Center(
            child: SizedBox(
              width: 210,
              height: 210,
              child: Transform.rotate(
                angle: .785398,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(44),
                  child: Transform.rotate(
                    angle: -.785398,
                    child: Transform.scale(
                      scale: 1.45,
                      child: AnimatedSwitcher(
                        duration: reduced
                            ? Duration.zero
                            : Duration(milliseconds: 600),
                        switchInCurve: landingExpo,
                        switchOutCurve: landingExpo,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween(
                              begin: 1.15,
                              end: 1.0,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: SizedBox.expand(
                          key: ValueKey(_selectedRoleIndex),
                          child: LandingMarketingImage(
                            url: landingRoleImages[_selectedRoleIndex],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 48),
          Text(
            'ABOUT THE ROLE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: context.creo.appMist,
            ),
          ),
          SizedBox(height: 16),
          LandingRoleDescription(
            role: activeRole.role,
            description: activeRole.about,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverablesShowcase() => LandingDeliverables(
    selectedIndex: _selectedCategoryIndex,
    onSelected: (index) => setState(() => _selectedCategoryIndex = index),
  );

  Widget _buildPlansSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TIERS & TURNAROUND',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: context.creo.accent,
            ),
          ),
          SizedBox(height: 6),
          _heading('Plans that grow with you', size: 40),
          LandingScene(scroll: _scroll, kind: LandingProp.megaphone),
          SizedBox(height: 24),

          LandingPressFeedback(
            child: OutlinedButton.icon(
              onPressed: () => _showDestinationGap('/pricing'),
              icon: Icon(Icons.arrow_outward),
              label: Text('Compare plans'),
            ),
          ),
          SizedBox(height: 24),
          // Plan Cards list
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _kPlans.length,
            separatorBuilder: (_, __) => SizedBox(height: 16),
            itemBuilder: (context, idx) {
              final plan = _kPlans[idx];
              return Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.creo.appSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: plan.isPopular
                        ? context.creo.accent
                        : context.creo.appLine,
                    width: plan.isPopular ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text(
                          plan.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: context.creo.appInk,
                          ),
                        ),
                        if (plan.isPopular)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.creo.accent,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'MOST POPULAR',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: context.creo.onAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      plan.turnaround,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.creo.accent,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      plan.subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: context.creo.appMist,
                      ),
                    ),
                    SizedBox(height: 16),
                    Divider(color: Colors.white.withValues(alpha: 0.08)),
                    SizedBox(height: 12),
                    ...plan.highlights.map(
                      (h) => Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: context.creo.accent,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                h,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  color: context.creo.appInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFaqSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FAQ',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: context.creo.accent,
            ),
          ),
          SizedBox(height: 6),
          _heading('Common questions.', size: 40),
          SizedBox(height: 20),

          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _kFaqs.length,
            separatorBuilder: (_, __) => SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final faq = _kFaqs[idx];
              final isExpanded = _expandedFaqIndex == idx;

              return Container(
                decoration: BoxDecoration(
                  color: context.creo.appSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.creo.appLine),
                ),
                child: Column(
                  children: [
                    InkWell(
                      key: ValueKey('faq-toggle-$idx'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(
                        () => _expandedFaqIndex = isExpanded ? null : idx,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                faq.question,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: context.creo.appInk,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            AnimatedRotation(
                              turns: isExpanded
                                  ? 0.125
                                  : 0.0, // 45 degree rotation
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : Duration(milliseconds: 350),
                              curve: landingExpo,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isExpanded
                                      ? context.creo.accent
                                      : Colors.white.withValues(alpha: 0.1),
                                ),
                                child: Icon(
                                  Icons.add,
                                  size: 16,
                                  color: isExpanded
                                      ? context.creo.onAccent
                                      : context.creo.appInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable Answer
                    _LandingFaqTransition(
                      expanded: isExpanded,
                      reduced: MediaQuery.disableAnimationsOf(context),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                            SizedBox(height: 10),
                            Text(
                              faq.answer,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                height: 1.6,
                                color: context.creo.appMist,
                              ),
                            ),
                            if (faq.badge != null) ...[
                              SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.creo.accent.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  faq.badge!,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.creo.accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSampleCtaSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.creo.accent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FREE SAMPLE BATCH',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: context.creo.onAccent,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try us before you pay us.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: context.creo.onAccent,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Enter your Instagram handle and work email. We will assemble a custom sample reel and carousel for your brand, completely free.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                height: 1.5,
                color: context.creo.onAccent.withValues(alpha: 0.8),
              ),
            ),
            SizedBox(height: 24),

            if (_sampleNotice != null) ...[
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    _sampleNotice!,
                    style: TextStyle(
                      color: context.creo.onAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            ...[
              TextField(
                controller: _sampleHandleCtrl,
                style: TextStyle(
                  color: context.creo.onAccent,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '@yourbrand (Instagram)',
                  hintStyle: TextStyle(
                    color: context.creo.onAccent.withValues(alpha: 0.5),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: context.creo.onAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: context.creo.onAccent,
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14),
              TextField(
                controller: _sampleEmailCtrl,
                style: TextStyle(
                  color: context.creo.onAccent,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Work email address',
                  hintStyle: TextStyle(
                    color: context.creo.onAccent.withValues(alpha: 0.5),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: context.creo.onAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: context.creo.onAccent,
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 56,
                  minWidth: double.infinity,
                ),
                child: ElevatedButton(
                  onPressed: () {
                    setState(
                      () => _sampleNotice =
                          'Sample requests are not connected in the mobile app yet. Your request has not been sent.',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.creo.onAccent,
                    foregroundColor: context.creo.accent,
                    shape: StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  child: Text(
                    'Claim Free Sample Batch',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
              Text(
                '© 2026 Creo Agency Inc.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: context.creo.appMist,
                ),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(_kWhatsAppUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  'Help & Support',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: context.creo.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'landing_motion.dart';

// Exact photo sources from PortalDemo.tsx and stage3d/registry.tsx. These are
// public marketing images, not authenticated media or generated placeholders.
const landingRoleImages = [
  'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&w=900&q=75',
  'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=900&q=75',
  'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?auto=format&fit=crop&w=900&q=75',
  'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?auto=format&fit=crop&w=900&q=75',
];

class LandingMarketingImage extends StatelessWidget {
  const LandingMarketingImage({super.key, required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: BoxFit.cover,
    excludeFromSemantics: true,
    cacheWidth:
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(320, 1000),
    errorBuilder: (_, _, _) => ColoredBox(
      color: context.creo.appSurface,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Image unavailable',
            style: TextStyle(color: context.creo.appMist, fontSize: 14),
          ),
        ),
      ),
    ),
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : ColoredBox(color: context.creo.appSurface),
  );
}

enum _ReviewStatus { awaiting, approved, revision }

/// Same explicitly local mock as React PortalDemo: never sends an API request.
class LandingPortalDemo extends StatefulWidget {
  const LandingPortalDemo({super.key});
  @override
  State<LandingPortalDemo> createState() => _LandingPortalDemoState();
}

class _LandingPortalDemoState extends State<LandingPortalDemo> {
  final _statuses = [
    _ReviewStatus.awaiting,
    _ReviewStatus.awaiting,
    _ReviewStatus.approved,
  ];
  static const _names = [
    'Brand Launch Teaser',
    'Product Feature Breakdown',
    'Serum launch countdown',
  ];
  static const _types = ['Reel 9:16', 'Carousel 4 slides', 'Story 3 frames'];
  static const _photos = [
    'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?auto=format&fit=crop&w=600&q=80',
  ];

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final approved = _statuses
        .where((status) => status == _ReviewStatus.approved)
        .length;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.creo.appSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.creo.appLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRY IT — THIS PANEL WORKS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: context.creo.accent,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Batch 04 · Active Review',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: context.creo.appInk,
              ),
            ),
            SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: AnimatedSwitcher(
                duration: reduced ? Duration.zero : Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, -.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  '$approved of 3 approved • On track: 2 days early',
                  key: ValueKey(approved),
                  style: TextStyle(fontSize: 16, color: context.creo.appMist),
                ),
              ),
            ),
            SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween(end: approved / 3),
              duration: reduced ? Duration.zero : Duration(milliseconds: 600),
              curve: landingExpo,
              builder: (context, value, child) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                color: context.creo.accent,
                backgroundColor: context.creo.appLine,
                semanticsLabel: 'Demo batch approval progress',
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Interactive demonstration — changes stay in this panel.',
              style: TextStyle(fontSize: 14, color: context.creo.appMist),
            ),
            SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 850 ? 3 : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 20,
                  children: List.generate(
                    3,
                    (i) =>
                        SizedBox(width: width, child: _buildCard(i, reduced)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(int i, bool reduced) {
    final status = _statuses[i];
    return AnimatedContainer(
      key: ValueKey('demo-card-$i'),
      duration: reduced ? Duration.zero : Duration(milliseconds: 500),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.creo.appBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == _ReviewStatus.awaiting
              ? context.creo.appLine
              : status == _ReviewStatus.approved
              ? context.creo.accent
              : context.creo.appWarm,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 180, child: LandingMarketingImage(url: _photos[i])),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _types[i],
                  style: TextStyle(fontSize: 14, color: context.creo.appMist),
                ),
                SizedBox(height: 6),
                Text(
                  _names[i],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.creo.appInk,
                  ),
                ),
                SizedBox(height: 16),
                _LandingStatusSize(
                  reduced: reduced,
                  child: AnimatedSwitcher(
                    duration: reduced
                        ? Duration.zero
                        : Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: AnimatedBuilder(
                        animation: animation,
                        child: child,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, 8 * (1 - animation.value)),
                          child: child,
                        ),
                      ),
                    ),
                    child: status == _ReviewStatus.awaiting
                        ? Wrap(
                            key: ValueKey('awaiting-$i'),
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                key: ValueKey('approve-$i'),
                                onPressed: () => setState(
                                  () => _statuses[i] = _ReviewStatus.approved,
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size(94, 48),
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                ),
                                child: Text('Approve'),
                              ),
                              OutlinedButton(
                                key: ValueKey('change-$i'),
                                onPressed: () => setState(
                                  () => _statuses[i] = _ReviewStatus.revision,
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: Size(94, 48),
                                ),
                                child: Text('Change'),
                              ),
                            ],
                          )
                        : Wrap(
                            key: ValueKey('${status.name}-$i'),
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  status == _ReviewStatus.approved
                                      ? 'Approved (queued)'
                                      : 'Revision requested',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: status == _ReviewStatus.approved
                                        ? context.creo.accent
                                        : context.creo.appWarm,
                                  ),
                                ),
                              ),
                              TextButton(
                                key: ValueKey('undo-$i'),
                                onPressed: () => setState(
                                  () => _statuses[i] = _ReviewStatus.awaiting,
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: Size(48, 48),
                                ),
                                child: Text('Undo'),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Removing size interpolation entirely for reduced motion also avoids a
/// zero-duration AnimatedSize restarting its controller during layout.
class _LandingStatusSize extends StatelessWidget {
  const _LandingStatusSize({required this.reduced, required this.child});
  final bool reduced;
  final Widget child;

  @override
  Widget build(BuildContext context) => reduced
      ? child
      : AnimatedSize(
          duration: Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: child,
        );
}

/// AnimatePresence mode="wait" equivalent with latest-selection wins. Repeated
/// input during exit changes the pending role; no delayed callback owns selection.
class LandingRoleDescription extends StatefulWidget {
  const LandingRoleDescription({
    super.key,
    required this.role,
    required this.description,
  });
  final String role;
  final String description;
  @override
  State<LandingRoleDescription> createState() => _LandingRoleDescriptionState();
}

class _LandingRoleDescriptionState extends State<LandingRoleDescription>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 350),
    value: 1,
  );
  late String _description = widget.description;
  bool _exiting = false;
  bool _switching = false;
  int _generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _generation++;
      _controller.stop();
      _controller.value = 1;
      _description = widget.description;
      _switching = false;
      _exiting = false;
    }
  }

  @override
  void didUpdateWidget(LandingRoleDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) _switch();
  }

  Future<void> _switch() async {
    if (MediaQuery.disableAnimationsOf(context)) {
      _generation++;
      _controller.stop();
      _controller.value = 1;
      _description = widget.description;
      return;
    }
    if (_switching) return;
    final generation = ++_generation;
    _switching = true;
    _exiting = true;
    try {
      await _controller.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _description = widget.description;
      _exiting = false;
    });
    try {
      await _controller.forward().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || generation != _generation) return;
    _switching = false;
    if (_description != widget.description) _switch();
  }

  @override
  void dispose() {
    _generation++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Opacity(
      opacity: _controller.value,
      child: Transform.translate(
        offset: Offset(0, (_exiting ? -12 : 12) * (1 - _controller.value)),
        child: Text(
          _description,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            height: 1.6,
            color: context.creo.appMist,
          ),
        ),
      ),
    ),
  );
}

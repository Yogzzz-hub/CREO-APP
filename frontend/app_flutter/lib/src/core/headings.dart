import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// ponytail: keyword table shared by every role's headings and tabs. First match
// wins, so specific words sit above general ones. Pass `icon:` to Heading where
// a label needs a different icon.
const _icons = <(List<String>, IconData)>[
  (['notification'], Icons.notifications_none_outlined),
  (
    [
      'needs your decision',
      'needs a next step',
      'waiting',
      'my requests',
      'your requests',
    ],
    Icons.pending_actions_outlined,
  ),
  (
    [
      'today',
      'this month',
      'coming up',
      'upcoming',
      'availability',
      'calendar',
      'schedule',
      'stand-up',
      'standup',
    ],
    Icons.calendar_today_outlined,
  ),
  (
    ['revenue', 'money', 'payment', 'billing', 'retainer', 'totals', 'charges'],
    Icons.payments_outlined,
  ),
  (['invoice', 'receipt'], Icons.receipt_long_outlined),
  (
    ['plan', 'proposal', 'negotiation', 'add-ons', 'service and price'],
    Icons.sell_outlined,
  ),
  (['sales', 'funnel', 'pipeline', 'leads', 'crm'], Icons.trending_up_outlined),
  (['follow-up', 'next move', 'action center'], Icons.flag_outlined),
  (['referral'], Icons.share_outlined),
  (['report', 'quality', 'outcome'], Icons.insights_outlined),
  (['handoff', 'move to'], Icons.swap_horiz_outlined),
  (['ai workspace'], Icons.auto_awesome_outlined),
  (
    ['chat', 'message', 'inbox', 'conversation', 'replies', 'hub'],
    Icons.forum_outlined,
  ),
  (
    ['support', 'ticket', 'common questions', 'help'],
    Icons.support_agent_outlined,
  ),
  (['your workspace'], Icons.space_dashboard_outlined),
  (['task', 'requirements'], Icons.checklist_outlined),
  (['leave', 'time off', 'blackout', 'unavailab'], Icons.event_busy_outlined),
  (['workload', 'too much work', 'free to take'], Icons.speed_outlined),
  (
    ['pod', 'team', 'group', 'members', 'everyone', 'people'],
    Icons.groups_outlined,
  ),
  (['freelancer'], Icons.badge_outlined),
  (['client', 'accounts', 'agency'], Icons.storefront_outlined),
  (['brand'], Icons.palette_outlined),
  (
    ['review', 'changes asked', 'self-check', 'sign-off'],
    Icons.rate_review_outlined,
  ),
  (['approved'], Icons.task_alt_outlined),
  (['publish'], Icons.send_outlined),
  (
    ['deliverable', 'content', 'library', 'asset', 'submit', 'upload'],
    Icons.perm_media_outlined,
  ),
  (['meet'], Icons.videocam_outlined),
  (['note', 'activity', 'details', 'terms'], Icons.description_outlined),
  (['security', 'password'], Icons.lock_outline),
  (['integration', 'provider', 'instagram'], Icons.extension_outlined),
  (
    ['setting', 'preference', 'reading and language', 'role catalog'],
    Icons.tune_outlined,
  ),
  (['profile', 'account', 'contact', 'personal'], Icons.person_outline),
  (['quick action'], Icons.bolt_outlined),
];

/// Outlined icon for a heading or tab label, or null when nothing fits.
IconData? sectionIcon(String label) {
  final l = label.toLowerCase();
  for (final (words, icon) in _icons) {
    if (words.any(l.contains)) return icon;
  }
  return null;
}

/// A heading with its icon in front. The icon takes the text colour, sized to
/// the text, so it reads as part of the heading and not as decoration.
class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, this.style, this.icon, this.textAlign});

  final String text;
  final TextStyle? style;
  final IconData? icon;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final s = DefaultTextStyle.of(context).style.merge(style);
    final glyph = icon ?? sectionIcon(text);
    final label = Text(text, style: s, textAlign: textAlign);
    if (glyph == null) return label;
    final size = ((s.fontSize ?? 14) * 0.95).clamp(14.0, 26.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(glyph, size: size, color: s.color),
        SizedBox(width: size * 0.45),
        Flexible(child: label),
      ],
    );
  }
}

/// Tab label with its icon, for TabBar tabs and segmented pills. Scales down
/// rather than wrapping when a narrow phone squeezes the tab.
Widget tabLabel(String text, {TextStyle? style}) => FittedBox(
  fit: BoxFit.scaleDown,
  child: Heading(text, style: style),
);

/// Scroll body where `children[fill]` stretches down so the content reaches
/// the bottom edge when it is shorter than the screen, leaving no blank band.
/// Children after [fill] (say a button) stay their own height below it.
/// Longer content scrolls as usual. The filling child must not scroll itself.
/// [fill] defaults to the last child; a negative value turns filling off.
class FillScroll extends StatelessWidget {
  const FillScroll({
    super.key,
    required this.children,
    this.fill,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.controller,
    this.keyboardDismiss = false,
  });

  final List<Widget> children;
  final int? fill;
  final EdgeInsets padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  /// Drag to hide the keyboard, for pages with text fields.
  final bool keyboardDismiss;

  @override
  Widget build(BuildContext context) {
    final at = fill ?? children.length - 1;
    final dismiss = keyboardDismiss
        ? ScrollViewKeyboardDismissBehavior.onDrag
        : ScrollViewKeyboardDismissBehavior.manual;
    if (at < 0 || at >= children.length) {
      return ListView(
        keyboardDismissBehavior: dismiss,
        controller: controller,
        physics: physics,
        padding: padding,
        children: children,
      );
    }
    return CustomScrollView(
      keyboardDismissBehavior: dismiss,
      controller: controller,
      physics: physics,
      slivers: [
        SliverPadding(
          padding: padding.copyWith(bottom: 0),
          sliver: SliverList.list(children: children.sublist(0, at)),
        ),
        // Measures what is left of the screen below the earlier children and
        // hands it to the filling child as a minimum height. No intrinsic
        // sizing, so tiles with large text never get squeezed.
        SliverLayoutBuilder(
          builder: (context, c) => SliverPadding(
            padding: padding.copyWith(top: 0),
            sliver: SliverToBoxAdapter(
              child: _FillColumn(
                minHeight:
                    c.viewportMainAxisExtent -
                    c.precedingScrollExtent -
                    padding.bottom,
                children: [
                  children[at],
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children.sublist(at + 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Two children stacked: the first grows so both together reach [minHeight];
/// the second keeps its own height under it.
class _FillColumn extends MultiChildRenderObjectWidget {
  const _FillColumn({required this.minHeight, required super.children});
  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFillColumn(minHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderFillColumn r) =>
      r.minHeight = minHeight;
}

class _FillData extends ContainerBoxParentData<RenderBox> {}

class _RenderFillColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FillData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FillData> {
  _RenderFillColumn(this._minHeight);

  double _minHeight;
  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FillData) child.parentData = _FillData();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final fill = firstChild!;
    final after = childAfter(fill)!;
    after.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    fill.layout(
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        minHeight: math.max(0, _minHeight - after.size.height),
      ),
      parentUsesSize: true,
    );
    (fill.parentData! as _FillData).offset = Offset.zero;
    (after.parentData! as _FillData).offset = Offset(0, fill.size.height);
    size = constraints.constrain(
      Size(width, fill.size.height + after.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

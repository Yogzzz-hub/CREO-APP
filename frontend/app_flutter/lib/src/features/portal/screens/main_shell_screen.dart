import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../widgets/creo_top_header.dart';
import '../widgets/creo_bottom_nav.dart';
import '../widgets/creo_portal_drawer.dart';
import '../models/dashboard_model.dart';
import '../models/deliverable_model.dart';

// Screens
import 'home/home_dashboard_screen.dart';
import 'home/creative_pod_detail_screen.dart';
import 'review/deliverables_review_screen.dart';
import 'review/deliverable_detail_theater_screen.dart';
import 'calendar/content_calendar_screen.dart';
import 'library/asset_library_screen.dart';
import 'inbox/inbox_shell_screen.dart';
import 'billing/plan_and_billing_screen.dart';
import 'brand/brand_dna_screen.dart';
import 'settings/account_settings_screen.dart';
import 'support/help_support_screen.dart';
import '../../../core/auth_session.dart';
import '../client_api_service.dart';
import '../../onboarding/client_onboarding_page.dart';
import 'home/plan_call_sheet.dart';

class MainShellScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final AuthSession? session;
  final VoidCallback? onSignOut;

  const MainShellScreen({
    super.key,
    required this.onToggleTheme,
    this.session,
    this.onSignOut,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentTabIndex = 0;
  String _activeDrawerKey = 'dashboard';

  ClientApiService? _api;

  String get userInitials {
    final name = widget.session?.current?.user.fullName.trim() ?? '';
    if (name.isEmpty) return 'CL';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    return (parts.length > 1
            ? '${parts[0][0]}${parts[1][0]}'
            : parts[0].substring(0, parts[0].length < 2 ? 1 : 2))
        .toUpperCase();
  }

  String get userName {
    final name = widget.session?.current?.user.fullName.trim() ?? '';
    return name.isNotEmpty ? name : 'Your account';
  }

  // Starts empty: real data arrives from the backend (portal dashboard and deliverables APIs).
  DashboardData _dashboardData = DashboardData(
    pendingDeliverableCount: 0,
    openTicketCount: 0,
    instagramConnected: false,
    planName: null,
    reelsQuota: QuotaItem(quota: 0, used: 0, remaining: 0),
    postersQuota: QuotaItem(quota: 0, used: 0, remaining: 0),
    storiesQuota: QuotaItem(quota: 0, used: 0, remaining: 0),
    assignedTeam: [],
    recentActivity: [],
  );

  List<DeliverableItem> _deliverables = [];

  @override
  void initState() {
    super.initState();
    if (widget.session != null) {
      _api = ClientApiService(widget.session!);
      _loadLive();
    }
  }

  Future<void> _loadLive() async {
    if (_api == null) return;
    await _api!.refreshAll(onDone: () {
      if (mounted) {
        setState(() {
          if (_api!.liveDashboard != null) {
            _dashboardData = _api!.liveDashboard!;
          }
          if (_api!.liveDeliverables.isNotEmpty) {
            _deliverables = _api!.liveDeliverables;
          }
        });
      }
    });
  }

  bool get _onboardingIncomplete =>
      widget.session != null && _api?.onboardingComplete != true;

  Future<void> _openOnboarding() async {
    final session = widget.session;
    if (session == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (pageContext) => ClientOnboardingPage(
          session: session,
          onCompleted: () => Navigator.pop(pageContext),
        ),
      ),
    );
    // Progress may have moved even if setup is not finished; refresh the stage.
    await session.restore();
    if (mounted) await _loadLive();
  }

  void _signOut() {
    if (widget.onSignOut != null) {
      widget.onSignOut!();
    } else {
      widget.session?.logout(notifyServer: true);
    }
  }

  Future<void> _handleApproveDeliverable(DeliverableItem item) async {
    try {
      if (_api != null) {
        await _api!.approveDeliverable(item.id);
      }
      setState(() {
        _deliverables = _deliverables.map((d) {
          if (d.id == item.id) {
            return DeliverableItem(
              id: d.id,
              title: d.title,
              status: 'approved',
              statusLabel: 'Approved',
              deliverableType: d.deliverableType,
              formatLabel: d.formatLabel,
              version: d.version,
              fileUrl: d.fileUrl,
              downloadUrl: d.downloadUrl,
              isVideo: d.isVideo,
              scheduledDate: d.scheduledDate,
              revisionsUsed: d.revisionsUsed,
              maxRevisions: d.maxRevisions,
              voiceNoteUrl: d.voiceNoteUrl,
              voiceNoteDuration: d.voiceNoteDuration,
            );
          }
          return d;
        }).toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved "${item.title}" — Scheduled for dispatch!'),
            backgroundColor: CreoColors.amber,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving deliverable: $e')),
        );
      }
    }
  }

  Future<void> _handleRequestChanges(DeliverableItem item, String feedback) async {
    try {
      if (_api != null) {
        await _api!.requestChanges(item.id, feedback);
      }
      setState(() {
        _deliverables = _deliverables.map((d) {
          if (d.id == item.id) {
            return DeliverableItem(
              id: d.id,
              title: d.title,
              status: 'revision_requested',
              statusLabel: 'Changes asked',
              deliverableType: d.deliverableType,
              formatLabel: d.formatLabel,
              version: d.version,
              fileUrl: d.fileUrl,
              downloadUrl: d.downloadUrl,
              isVideo: d.isVideo,
              scheduledDate: d.scheduledDate,
              revisionsUsed: d.revisionsUsed + 1,
              maxRevisions: d.maxRevisions,
              voiceNoteUrl: d.voiceNoteUrl,
              voiceNoteDuration: d.voiceNoteDuration,
            );
          }
          return d;
        }).toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Revision request submitted for "${item.title}"'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting revision: $e')),
        );
      }
    }
  }

  void _openTheater(DeliverableItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliverableDetailTheaterScreen(
          deliverable: item,
          onApprove: () => _handleApproveDeliverable(item),
          onRequestChanges: (feedback) => _handleRequestChanges(item, feedback),
        ),
      ),
    );
  }

  void _openDrawerNavigation(String key) {
    Navigator.pop(context); // Close drawer
    setState(() => _activeDrawerKey = key);

    switch (key) {
      case 'dashboard':
        setState(() => _currentTabIndex = 0);
        break;
      case 'review':
        setState(() => _currentTabIndex = 1);
        break;
      case 'calendar':
        setState(() => _currentTabIndex = 2);
        break;
      case 'library':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const Scaffold(
              appBar: CreoTopHeader(roleSubtitle: 'Asset Library'),
              body: SafeArea(child: AssetLibraryScreen()),
            ),
          ),
        );
        break;
      case 'chat':
        setState(() {
          _currentTabIndex = 3;
          _activeDrawerKey = 'chat';
        });
        break;
      case 'pod':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreativePodDetailScreen(
              onOpenWorkspaceChat: () => setState(() => _currentTabIndex = 3),
            ),
          ),
        );
        break;
      case 'onboarding':
        _openOnboarding();
        break;
      case 'brand':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const Scaffold(
              appBar: CreoTopHeader(roleSubtitle: 'Brand DNA'),
              body: SafeArea(child: BrandDnaScreen()),
            ),
          ),
        );
        break;
      case 'billing':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: const CreoTopHeader(roleSubtitle: 'Billing'),
              body: SafeArea(
                child: PlanAndBillingScreen(
                  onTriggerRazorpayCheckout: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening Razorpay Payment Sheet...')),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        break;
      case 'help':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const Scaffold(
              appBar: CreoTopHeader(roleSubtitle: 'Support Desk'),
              body: SafeArea(child: HelpSupportScreen()),
            ),
          ),
        );
        break;
      case 'settings':
        setState(() {
          _currentTabIndex = 4;
          _activeDrawerKey = 'settings';
        });
        break;
      case 'logout':
        _showLogoutConfirmDialog(context);
        break;
    }
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.bentoCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Sign Out?',
          style: TextStyle(
            color: isDark ? AppColors.ivory : AppColors.lightInk,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to end your current session?',
          style: TextStyle(
            color: isDark ? AppColors.mist : AppColors.lightMist,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay', style: TextStyle(color: AppColors.mist)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _signOut();
            },
            child: const Text('Sign Out', style: TextStyle(color: AppColors.onAmber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String get _currentActiveDrawerKey {
    switch (_currentTabIndex) {
      case 0:
        return 'dashboard';
      case 1:
        return 'review';
      case 2:
        return 'calendar';
      case 3:
        return 'chat';
      case 4:
        return 'settings';
      default:
        return _activeDrawerKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _deliverables.where((d) => d.needsApproval).length;

    // Body screens mapping to the 5 bottom navigation tabs
    final screens = [
      // 0: Home Dashboard
      RefreshIndicator(
        onRefresh: _loadLive,
        color: CreoColors.amber,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: HomeDashboardScreen(
            data: _dashboardData,
            setupStage: _onboardingIncomplete
                ? widget.session!.current?.user.onboardingStage ?? 0
                : null,
            onResumeSetup: _openOnboarding,
            onBookCall: () => showPlanCallSheet(context, widget.session!),
            onNavigateToReview: () => setState(() => _currentTabIndex = 1),
            onNavigateToCalendar: () => setState(() => _currentTabIndex = 2),
            onNavigateToChat: () => setState(() => _currentTabIndex = 3),
            onNavigateToBilling: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: const CreoTopHeader(roleSubtitle: 'Billing'),
                    body: PlanAndBillingScreen(
                      onTriggerRazorpayCheckout: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening Razorpay Payment Sheet...')),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),

      // 1: Review Deliverables
      RefreshIndicator(
        onRefresh: _loadLive,
        color: CreoColors.amber,
        child: DeliverablesReviewScreen(
          deliverables: _deliverables,
          onApprove: _handleApproveDeliverable,
          onRequestChanges: _handleRequestChanges,
          onOpenTheater: _openTheater,
          onOpenVoiceRecorder: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Hold microphone in theater view to record voice note!')),
            );
          },
        ),
      ),

      // 2: Content Calendar
      ContentCalendarScreen(
        onApprove30DayCampaign: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('30-Day Campaign Approved! Production tasks dispatched to pod.'),
              backgroundColor: CreoColors.amber,
            ),
          );
        },
      ),

      // 3: Inbox (Pod Chat & Support Desk)
      const InboxShellScreen(),

      // 4: Account & Settings
      AccountSettingsScreen(
        onToggleTheme: widget.onToggleTheme,
        onSignOut: _signOut,
        session: widget.session,
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: CreoPortalDrawer(
        activeItem: _currentActiveDrawerKey,
        pendingReviewCount: pendingCount,
        showOnboarding: _onboardingIncomplete,
        userName: userName,
        userInitials: userInitials,
        onSelect: _openDrawerNavigation,
        onThemeToggle: widget.onToggleTheme,
        onSignOut: () {
          Navigator.pop(context);
          _showLogoutConfirmDialog(context);
        },
      ),
      appBar: CreoTopHeader(
        roleSubtitle: 'Client',
        userInitials: userInitials,
        notificationCount: pendingCount,
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onThemeToggle: widget.onToggleTheme,
        onNotificationTap: () => setState(() => _currentTabIndex = 1),
        onSettingsTap: () => setState(() => _currentTabIndex = 4),
        onProfileTap: () => setState(() => _currentTabIndex = 4),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_api?.isLoading == true)
              const LinearProgressIndicator(
                minHeight: 2,
                color: CreoColors.amber,
                backgroundColor: CreoColors.obsidian,
              ),
            if (_api?.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: CreoColors.terracotta.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: CreoColors.terracotta),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _api!.error!,
                        style: const TextStyle(fontSize: 12, color: CreoColors.terracotta),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadLive,
                      child: const Text('Retry', style: TextStyle(fontSize: 12, color: CreoColors.amber)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.015),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_currentTabIndex),
                  child: screens[_currentTabIndex],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CreoBottomNavBar(
        currentIndex: _currentTabIndex,
        pendingReviewCount: pendingCount,
        inboxBadgeCount: _dashboardData.openTicketCount,
        onTap: (index) => setState(() => _currentTabIndex = index),
      ),
    );
  }
}

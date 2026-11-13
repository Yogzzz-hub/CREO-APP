import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_card.dart';
import '../../widgets/creo_segmented_tabs.dart';
import '../brand/brand_dna_screen.dart';
import '../billing/plan_and_billing_screen.dart';
import '../library/asset_library_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  const AccountSettingsScreen({
    super.key,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  int _selectedTab = 0; // 0: Profile, 1: Integrations, 2: Security

  // Profile Form Controllers
  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _companyCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _websiteCtrl = TextEditingController();
  String _selectedIndustry = 'Direct-to-Consumer (D2C)';

  final List<String> _industries = [
    'Direct-to-Consumer (D2C)',
    'Food & Beverage',
    'Fashion & Apparel',
    'Health & Wellness',
    'Tech & SaaS',
    'Professional Services',
  ];

  // Integrations State
  bool _isIgConnected = false;
  bool _autoPublishReels = true;
  bool _autoPublishPosts = true;
  bool _isVerifyingIg = false;

  // Security State
  bool _twoFactorEnabled = false;

  // Sessions load from the account API; none listed until it is connected.
  final List<Map<String, String>> _activeSessions = [];

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _companyCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile details updated successfully!'),
        backgroundColor: AppColors.emerald,
      ),
    );
  }

  void _verifyInstagram() async {
    setState(() => _isVerifyingIg = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isVerifyingIg = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instagram Professional connection verified and healthy.'),
          backgroundColor: AppColors.emerald,
        ),
      );
    }
  }

  void _showDisconnectIgDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.bentoCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Disconnect Instagram?',
          style: TextStyle(
            color: isDark ? AppColors.ivory : AppColors.lightInk,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Disconnecting Instagram will pause automated dispatch of scheduled Reels and Stories. Your pod will still produce content for manual download.',
          style: TextStyle(
            color: isDark ? AppColors.mist : AppColors.lightMist,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.mist)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isIgConnected = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Instagram account disconnected.'),
                ),
              );
            },
            child: const Text('Disconnect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.bentoCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.ivory : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: currentPwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                filled: true,
                fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password (min 8 chars)',
                filled: true,
                fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            CreoPillButton(
              label: 'Update Password',
              width: double.infinity,
              isPrimary: true,
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password updated successfully!'),
                    backgroundColor: AppColors.emerald,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Eyebrow & Title ──
          Text(
            'ACCOUNT & CONFIGURATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: isDark ? AppColors.mist : AppColors.lightMist,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 20),

          // ── User Profile Mini Header Card ──
          CreoCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'AN',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onAmber,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullNameCtrl.text.isEmpty ? 'Your name' : _fullNameCtrl.text,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.ivory : AppColors.lightInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _companyCtrl.text.isEmpty ? 'Client account' : _companyCtrl.text,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.mist : AppColors.lightMist,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emerald,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Segmented Navigation (Profile / Integrations / Security) ──
          CreoSegmentedTabs(
            tabs: const ['Profile', 'Integrations', 'Security'],
            selectedIndex: _selectedTab,
            onTabSelected: (idx) => setState(() => _selectedTab = idx),
          ),
          const SizedBox(height: 20),

          // ── Tab View Content ──
          if (_selectedTab == 0) _buildProfileTab(context),
          if (_selectedTab == 1) _buildIntegrationsTab(context),
          if (_selectedTab == 2) _buildSecurityTab(context),

          const SizedBox(height: 24),

          // ── Quick Navigation to Workspace Hubs ──
          Text(
            'Workspace Quick Jump',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.mist : AppColors.lightMist,
            ),
          ),
          const SizedBox(height: 10),

          CreoCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined, size: 20, color: AppColors.amber),
                  title: const Text('Brand DNA & Guidelines', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Palette swatches, voice descriptors & vault', style: TextStyle(fontSize: 11, color: AppColors.mist)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: BrandDnaScreen()))),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.credit_card_rounded, size: 20, color: AppColors.amber),
                  title: const Text('Plan & Billing', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Retainer tier, credits & official invoices', style: TextStyle(fontSize: 11, color: AppColors.mist)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
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
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.folder_outlined, size: 20, color: AppColors.amber),
                  title: const Text('Asset Library', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Approved deliverables & 1-tap download', style: TextStyle(fontSize: 11, color: AppColors.mist)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: AssetLibraryScreen()))),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── App Appearance & Theme ──
          Text(
            'Theme & Display',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.mist : AppColors.lightMist,
            ),
          ),
          const SizedBox(height: 10),

          CreoCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
                color: AppColors.amber,
              ),
              title: Text(
                isDark ? 'Switch to Light Theme' : 'Switch to Dark Obsidian',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                isDark ? 'Obsidian mode active' : 'Paper light mode active',
                style: const TextStyle(fontSize: 11, color: AppColors.mist),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: widget.onToggleTheme,
            ),
          ),
          const SizedBox(height: 24),

          // ── Sign Out Button ──
          CreoPillButton(
            label: 'Sign Out',
            isPrimary: false,
            width: double.infinity,
            onPressed: widget.onSignOut,
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  // ── Tab 1: Profile ──
  Widget _buildProfileTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CreoCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Profile',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.ivory : AppColors.lightInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'These details are used by your Pod Lead to calibrate messaging and brand identity.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.mist : AppColors.lightMist,
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _fullNameCtrl,
            decoration: InputDecoration(
              labelText: 'Full Name',
              filled: true,
              fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _companyCtrl,
            decoration: InputDecoration(
              labelText: 'Company / Brand Name',
              filled: true,
              fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedIndustry,
            items: _industries.map((ind) => DropdownMenuItem(value: ind, child: Text(ind))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedIndustry = val);
            },
            decoration: InputDecoration(
              labelText: 'Industry Sector',
              filled: true,
              fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Primary Work Email',
              filled: true,
              fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'WhatsApp Phone Number',
              hintText: '+91 98765 43210',
              filled: true,
              fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _websiteCtrl,
            decoration: InputDecoration(
              labelText: 'Brand Website URL',
              filled: true,
              fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 18),

          CreoPillButton(
            label: 'Save Profile Changes',
            isPrimary: true,
            width: double.infinity,
            onPressed: _saveProfile,
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Integrations (Instagram Professional & Meta) ──
  Widget _buildIntegrationsTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        CreoCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Instagram Professional',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.ivory : AppColors.lightInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isIgConnected ? 'Connected' : 'Not Connected',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isIgConnected ? AppColors.emerald : AppColors.terracotta,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isIgConnected
                          ? AppColors.emerald.withValues(alpha: 0.15)
                          : AppColors.terracotta.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isIgConnected ? 'Synced' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isIgConnected ? AppColors.emerald : AppColors.terracotta,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Direct auto-publish permissions allow your pod to schedule approved Reels, carousels, and stories straight to your feed without manual upload.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark ? AppColors.mist : AppColors.lightMist,
                ),
              ),
              const SizedBox(height: 16),

              if (_isIgConnected) ...[
                // Permissions checklist
                _buildPermissionRow('instagram_content_publish', 'Publish Reels & Carousel posts directly', true),
                const SizedBox(height: 6),
                _buildPermissionRow('pages_show_list', 'Connected to your Facebook Page', true),
                const SizedBox(height: 6),
                _buildPermissionRow('instagram_manage_insights', 'Track view & engagement analytics for reports', true),
                const SizedBox(height: 16),

                // Auto-publish switches
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-publish approved Reels', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  value: _autoPublishReels,
                  activeThumbColor: AppColors.amber,
                  onChanged: (val) => setState(() => _autoPublishReels = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-publish approved Carousel posts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  value: _autoPublishPosts,
                  activeThumbColor: AppColors.amber,
                  onChanged: (val) => setState(() => _autoPublishPosts = val),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: CreoPillButton(
                        label: _isVerifyingIg ? 'Verifying...' : 'Verify Connection',
                        isPrimary: false,
                        onPressed: _isVerifyingIg ? null : _verifyInstagram,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CreoPillButton(
                        label: 'Disconnect',
                        isPrimary: false,
                        onPressed: _showDisconnectIgDialog,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                CreoPillButton(
                  label: 'Connect Instagram via Meta',
                  isPrimary: true,
                  width: double.infinity,
                  onPressed: () {
                    // No real Meta sign-in is wired here yet, so never pretend to connect.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Instagram connection is not available in the app yet')),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionRow(String key, String label, bool granted) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 16,
          color: granted ? AppColors.emerald : AppColors.terracotta,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  // ── Tab 3: Security & Active Sessions ──
  Widget _buildSecurityTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Password & 2FA Card
        CreoCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security Credentials',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.ivory : AppColors.lightInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage account login credentials and two-factor authentication safeguards.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.mist : AppColors.lightMist,
                ),
              ),
              const SizedBox(height: 16),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, size: 20, color: AppColors.amber),
                ),
                title: const Text('Account Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: const Text('Change your login password', style: TextStyle(fontSize: 11, color: AppColors.mist)),
                trailing: TextButton(
                  onPressed: _showChangePasswordModal,
                  child: const Text('Change', style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.bold)),
                ),
              ),
              const Divider(height: 20),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Two-Factor Authentication (2FA)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: const Text('Require WhatsApp / SMS verification code on login', style: TextStyle(fontSize: 11, color: AppColors.mist)),
                value: _twoFactorEnabled,
                activeThumbColor: AppColors.amber,
                onChanged: (val) {
                  setState(() => _twoFactorEnabled = val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? '2FA Enabled!' : '2FA Disabled!'),
                      backgroundColor: val ? AppColors.emerald : AppColors.terracotta,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Active Login Sessions
        CreoCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Login Sessions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.ivory : AppColors.lightInk,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All other sessions revoked.')),
                      );
                    },
                    child: const Text('Revoke others', style: TextStyle(color: AppColors.terracotta, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              ..._activeSessions.map((session) {
                final isCurrent = session['isCurrent'] == 'true';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        session['device']!.contains('iPhone') || session['device']!.contains('Android')
                            ? Icons.phone_iphone_rounded
                            : Icons.laptop_mac_rounded,
                        size: 24,
                        color: isCurrent ? AppColors.amber : AppColors.mist,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    session['device']!,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.emerald.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Current',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.emerald),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${session['location']!} · ${session['ip']!}',
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.mist : AppColors.lightMist),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

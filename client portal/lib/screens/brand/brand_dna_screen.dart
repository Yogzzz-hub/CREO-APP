import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_card.dart';
import '../../widgets/creo_segmented_tabs.dart';
import '../../widgets/creo_animations.dart';

class BrandDnaScreen extends StatefulWidget {
  const BrandDnaScreen({super.key});

  @override
  State<BrandDnaScreen> createState() => _BrandDnaScreenState();
}

class _BrandDnaScreenState extends State<BrandDnaScreen> {
  int _selectedSubTab = 0; // 0: Brand DNA, 1: Asset Vault

  String _brandName = 'Zest Foods Direct';
  String _igHandle = '@zestfoods';
  String _whatYouSell = 'Artisanal organic cold-pressed wellness beverages and snacks';

  final List<Map<String, String>> _palette = [
    {'name': 'Obsidian Void', 'hex': '#0F0E0C'},
    {'name': 'Burnished Amber', 'hex': '#D2965A'},
    {'name': 'Midnight Navy', 'hex': '#172338'},
    {'name': 'Ivory Paper', 'hex': '#F5EEE3'},
  ];

  final List<String> _voiceTags = [
    'Premium',
    'Craft-first',
    'Bold',
    'Direct',
    'Warm',
    'Artisanal',
  ];

  final List<String> _taboos = [
    'Never use generic AI stock footage with unnatural artificial motion.',
    'Never place white typography over unshaded bright backgrounds.',
    'Avoid robotic text-to-speech voiceovers; always use authentic human recording.',
    'Never use low-resolution packaging mockups or blurry product labels.',
  ];

  final List<Map<String, String>> _vaultFiles = [
    {
      'id': 'file-1',
      'name': 'Zest_Primary_Logo_Vector.svg',
      'type': 'SVG Vector',
      'size': '248 KB',
      'date': 'Oct 14, 2026',
    },
    {
      'id': 'file-2',
      'name': 'Zest_Secondary_Brandmark_Dark.png',
      'type': 'PNG 4K',
      'size': '1.8 MB',
      'date': 'Oct 14, 2026',
    },
    {
      'id': 'file-3',
      'name': 'Instrument_Sans_Typography_Suite.zip',
      'type': 'Typography Font Suite',
      'size': '4.2 MB',
      'date': 'Oct 15, 2026',
    },
    {
      'id': 'file-4',
      'name': 'Zest_Q4_Product_Catalog_Guidelines.pdf',
      'type': 'PDF Document',
      'size': '12.4 MB',
      'date': 'Oct 18, 2026',
    },
  ];

  void _openEditDnaModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: _brandName);
    final handleCtrl = TextEditingController(text: _igHandle);
    final sellCtrl = TextEditingController(text: _whatYouSell);
    final newTagCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.bentoCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Brand DNA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.ivory : AppColors.lightInk,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Brand Name',
                  filled: true,
                  fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: handleCtrl,
                decoration: InputDecoration(
                  labelText: 'Instagram Handle',
                  filled: true,
                  fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: sellCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'What You Sell / Value Proposition',
                  filled: true,
                  fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Add Voice Descriptor',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.mist : AppColors.lightMist,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newTagCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Playful, Technical',
                        filled: true,
                        fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      if (newTagCtrl.text.trim().isNotEmpty) {
                        setState(() {
                          _voiceTags.add(newTagCtrl.text.trim());
                        });
                        setModalState(() {});
                        newTagCtrl.clear();
                      }
                    },
                    child: const Text('Add', style: TextStyle(color: AppColors.onAmber, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              CreoPillButton(
                label: 'Save Brand DNA',
                width: double.infinity,
                isPrimary: true,
                onPressed: () {
                  setState(() {
                    _brandName = nameCtrl.text.trim();
                    _igHandle = handleCtrl.text.trim();
                    _whatYouSell = sellCtrl.text.trim();
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Brand DNA updated successfully!'),
                      backgroundColor: AppColors.emerald,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _uploadFileMock() {
    setState(() {
      _vaultFiles.insert(0, {
        'id': 'file-${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Brand_Asset_New_Package.zip',
        'type': 'ZIP Archive',
        'size': '5.6 MB',
        'date': 'Just now',
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Brand asset uploaded and saved to vault!'),
        backgroundColor: AppColors.emerald,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR BRAND',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: isDark ? AppColors.mist : AppColors.lightMist,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Brand DNA',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ],
              ),
              CreoPillButton(
                label: 'Edit DNA',
                isPrimary: false,
                dense: true,
                onPressed: () => _openEditDnaModal(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The core visual language, tone, and guardrails your pod enforces in every batch.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.mist : AppColors.lightMist,
            ),
          ),
          const SizedBox(height: 16),

          // ── Sub-tabs: Brand DNA vs Asset Vault ──
          CreoSegmentedTabs(
            tabs: ['Brand DNA & Rules', 'Asset Vault (${_vaultFiles.length})'],
            selectedIndex: _selectedSubTab,
            onTabSelected: (index) => setState(() => _selectedSubTab = index),
          ),
          const SizedBox(height: 20),

          if (_selectedSubTab == 0) _buildBrandDnaView(context),
          if (_selectedSubTab == 1) _buildAssetVaultView(context),

          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildBrandDnaView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Brand Overview Banner ──
        CreoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _brandName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.ivory : AppColors.lightInk,
                    ),
                  ),
                  Text(
                    _igHandle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _whatYouSell,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark ? AppColors.mist : AppColors.lightMist,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Section 1: Color Palette ──
        Text(
          'Brand Color Palette (Tap to copy hex)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.mist : AppColors.lightMist,
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: _palette.map((color) {
            final hex = color['hex']!;
            final colorVal = Color(int.parse(hex.replaceFirst('#', '0xFF')));
            return Expanded(
              child: CreoPressScale(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: hex));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied $hex (${color['name']}) to clipboard!'),
                      backgroundColor: AppColors.amber,
                    ),
                  );
                },
                pressedScale: 0.90,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: colorVal,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.line : AppColors.lightBorder,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        hex,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorVal.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // ── Section 2: Brand Voice ──
        Text(
          'Brand Voice & Tone Descriptors',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.mist : AppColors.lightMist,
          ),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _voiceTags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bentoCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.line : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, size: 13, color: AppColors.amber),
                  const SizedBox(width: 6),
                  Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.ivory : AppColors.lightInk,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // ── Section 3: Content Pillars ──
        Text(
          'Content Pillar Strategy & Cadence',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.mist : AppColors.lightMist,
          ),
        ),
        const SizedBox(height: 10),

        CreoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPillarBar('Reach & Entertainment (Reels & Hooks)', 0.40, '40%'),
              const SizedBox(height: 14),
              _buildPillarBar('Authority & Product Education (Carousels)', 0.40, '40%'),
              const SizedBox(height: 14),
              _buildPillarBar('Social Proof & Direct Conversion (Stories)', 0.20, '20%'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Section 4: Taboo Guardrails ──
        Text(
          'Taboo Rules ("Never Do" Guardrails)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.mist : AppColors.lightMist,
          ),
        ),
        const SizedBox(height: 10),

        CreoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: _taboos.map((rule) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.block, size: 16, color: AppColors.terracotta),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rule,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: isDark ? AppColors.ivory : AppColors.lightInk,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPillarBar(String label, double pct, String pctStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(pctStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.amber)),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: pct),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) => LinearProgressIndicator(
            value: val,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ── Sub-tab 2: Brand Asset Vault ──
  Widget _buildAssetVaultView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: CreoPillButton(
                label: '+ Upload Brand Asset (Logo / Font / PDF)',
                isPrimary: true,
                onPressed: _uploadFileMock,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        ..._vaultFiles.map((file) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: CreoCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surface : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        file['type']!.contains('SVG') || file['type']!.contains('PNG')
                            ? Icons.image_rounded
                            : file['type']!.contains('Font')
                                ? Icons.font_download_rounded
                                : Icons.picture_as_pdf_rounded,
                        color: AppColors.amber,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file['name']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.ivory : AppColors.lightInk,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${file['type']!} · ${file['size']!} · ${file['date']!}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.mist : AppColors.lightMist,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.terracotta),
                    onPressed: () {
                      setState(() {
                        _vaultFiles.removeWhere((f) => f['id'] == file['id']);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Asset deleted from vault.')),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

typedef BrandDNAScreen = BrandDnaScreen;

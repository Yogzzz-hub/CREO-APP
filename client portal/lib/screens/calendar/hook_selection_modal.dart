import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_pill_button.dart';

class HookSelectionModal extends StatefulWidget {
  final String dateStr;
  final String format;
  final String initialTitle;
  final VoidCallback? onApproved;

  const HookSelectionModal({
    super.key,
    required this.dateStr,
    this.format = 'Reel',
    this.initialTitle = 'Founder Story: Why traditional agencies fail',
    this.onApproved,
  });

  static Future<void> show(
    BuildContext context, {
    required String dateStr,
    String format = 'Reel',
    String title = 'Founder Story: Why traditional agencies fail',
    VoidCallback? onApproved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HookSelectionModal(
        dateStr: dateStr,
        format: format,
        initialTitle: title,
        onApproved: onApproved,
      ),
    );
  }

  @override
  State<HookSelectionModal> createState() => _HookSelectionModalState();
}

class _HookSelectionModalState extends State<HookSelectionModal> {
  int _selectedHookIndex = 0;
  bool _isConceptApproved = false;
  bool _isRequestingChanges = false;
  final TextEditingController _changeNotesCtrl = TextEditingController();

  final List<_HookOption> _hooks = [
    const _HookOption(
      tag: 'Hook A (Curiosity-Driven)',
      script: '“Stop making your ceramics look like factory inventory in 2026...”',
      visual: 'Close-up slow rotation with warm tungsten studio light',
    ),
    const _HookOption(
      tag: 'Hook B (Data / Problem Hook)',
      script: '“Why 87% of artisanal brands lose attention before the 3-second mark...”',
      visual: 'Rapid cuts of glaze cracking vs flawless matte finish',
    ),
    const _HookOption(
      tag: 'Hook C (Behind The Scenes / Craft)',
      script: '“I spent 300 hours perfecting this glaze so you wouldn\'t have to...”',
      visual: 'Macro tactile texture shot with soothing ambient ASMR audio',
    ),
  ];

  @override
  void dispose() {
    _changeNotesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.mist.withAlpha(80) : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.format.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.amber),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.ivory : AppColors.lightInk,
                        ),
                      ),
                      Text(
                        'Scheduled for ${widget.dateStr}',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.mist : AppColors.lightMist),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? AppColors.mist : AppColors.lightMist),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.line),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Concept Status Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isConceptApproved
                        ? AppColors.emerald.withAlpha(25)
                        : Colors.purple.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isConceptApproved
                          ? AppColors.emerald.withAlpha(80)
                          : Colors.purple.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isConceptApproved ? Icons.check_circle_rounded : Icons.auto_awesome_rounded,
                        color: _isConceptApproved ? AppColors.emerald : Colors.purple,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isConceptApproved ? 'Story Concept Approved' : 'Concept Blueprint Ready',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _isConceptApproved ? AppColors.emerald : const Color(0xFFD8B4FE),
                              ),
                            ),
                            Text(
                              _isConceptApproved
                                  ? 'Your pod is actively producing this deliverable according to your chosen hook.'
                                  : 'Select your preferred opening hook below, or approve the standard brief.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.mist : AppColors.lightMist,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Hook A/B/C Selector Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Creative Hook Variations',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.ivory : AppColors.lightInk,
                      ),
                    ),
                    const Text(
                      'Select 1 of 3',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.amber),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                ...List.generate(_hooks.length, (i) {
                  final hook = _hooks[i];
                  final isSelected = _selectedHookIndex == i;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedHookIndex = i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.amber.withAlpha(25)
                            : (isDark ? AppColors.cardBg : AppColors.lightSurface),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.amber : (isDark ? AppColors.line : AppColors.lightBorder),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                size: 16,
                                color: isSelected ? AppColors.amber : (isDark ? AppColors.mist : AppColors.lightMist),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hook.tag,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? AppColors.amber : (isDark ? AppColors.ivory : AppColors.lightInk),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hook.script,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: isDark ? AppColors.ivory : AppColors.lightInk,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.videocam_outlined, size: 12, color: AppColors.amber),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  hook.visual,
                                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.mist : AppColors.lightMist),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 14),

                // Creative Blueprint Metadata
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardBg : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRODUCTION BLUEPRINT',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.amber),
                      ),
                      const SizedBox(height: 8),
                      _metaRow('Angle / Narrative', 'Founder craft journey & quality differentiation', isDark),
                      const SizedBox(height: 6),
                      _metaRow('Sound & Audio', 'Trending ambient lofi + original recorded voiceover', isDark),
                      const SizedBox(height: 6),
                      _metaRow('Target Audience', 'Architects, interior stylists, design enthusiasts', isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Action Buttons
                if (!_isConceptApproved) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder),
                          ),
                          onPressed: () => setState(() => _isRequestingChanges = !_isRequestingChanges),
                          child: Text(
                            _isRequestingChanges ? 'Cancel Feedback' : 'Request Change',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.ivory : AppColors.lightInk),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: const Text('Approve Concept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          onPressed: () {
                            setState(() => _isConceptApproved = true);
                            widget.onApproved?.call();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Story Concept Approved with ${_hooks[_selectedHookIndex].tag}!'),
                                backgroundColor: AppColors.emerald,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  if (_isRequestingChanges) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _changeNotesCtrl,
                      maxLines: 3,
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.ivory : AppColors.lightInk),
                      decoration: InputDecoration(
                        hintText: 'Describe changes you\'d like to see in the hook or script...',
                        hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.mist : AppColors.lightMist),
                        filled: true,
                        fillColor: isDark ? AppColors.cardBg : AppColors.lightSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CreoPillButton(
                      label: 'Send Feedback to Creative Pod',
                      icon: Icons.send_rounded,
                      isPrimary: true,
                      fullWidth: true,
                      onPressed: () {
                        setState(() => _isRequestingChanges = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Feedback dispatched to your pod! Revised hook coming shortly.'),
                            backgroundColor: AppColors.amber,
                          ),
                        );
                      },
                    ),
                  ],
                ] else ...[
                  CreoPillButton(
                    label: 'Concept Approved · In Pod Production',
                    icon: Icons.check_circle_rounded,
                    isPrimary: true,
                    fullWidth: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.mist : AppColors.lightMist)),
        ),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppColors.ivory : AppColors.lightInk)),
        ),
      ],
    );
  }
}

class _HookOption {
  final String tag;
  final String script;
  final String visual;

  const _HookOption({
    required this.tag,
    required this.script,
    required this.visual,
  });
}

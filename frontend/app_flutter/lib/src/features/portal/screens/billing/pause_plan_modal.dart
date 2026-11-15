import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PausePlanModal extends StatefulWidget {
  final String planName;
  final String renewalDate;
  final VoidCallback? onSuccess;

  const PausePlanModal({
    super.key,
    this.planName = '',
    this.renewalDate = '',
    this.onSuccess,
  });

  static Future<void> show(BuildContext context, {String planName = '', String renewalDate = '', VoidCallback? onSuccess}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PausePlanModal(
        planName: planName,
        renewalDate: renewalDate,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<PausePlanModal> createState() => _PausePlanModalState();
}

class _PausePlanModalState extends State<PausePlanModal> {
  final List<String> reasons = [
    'Campaign / marketing hiatus',
    'Backlog of content to publish first',
    'Traveling / Team out of office',
    'Seasonal business break',
    'Budget reallocation',
    'Other reason',
  ];

  late String selectedReason;
  final TextEditingController notesController = TextEditingController();
  bool isSubmitting = false;
  bool isSubmitted = false;

  @override
  void initState() {
    super.initState();
    selectedReason = reasons[0];
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  void _submit() async {
    setState(() => isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      isSubmitting = false;
      isSubmitted = true;
    });
    widget.onSuccess?.call();
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.mist.withAlpha(80) : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            if (isSubmitted) ...[
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.amber.withAlpha(80)),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.amber, size: 36),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Pause Request Sent',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.ivory : AppColors.lightInk,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Your ${widget.planName} plan remains 100% active until ${widget.renewalDate}. Our agency administrator has been notified.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.mist : AppColors.lightMist,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withAlpha(80)),
                    ),
                    child: const Icon(Icons.pause_circle_outline_rounded, color: Colors.amber, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request Pause for Next Month',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.ivory : AppColors.lightInk,
                          ),
                        ),
                        Text(
                          'Effective from renewal: ${widget.renewalDate}',
                          style: const TextStyle(fontSize: 11, color: AppColors.amber, fontWeight: FontWeight.w600),
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
              const SizedBox(height: 16),

              // Guarantees card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardBg : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
                ),
                child: Column(
                  children: [
                    _guaranteeItem(
                      Icons.shield_outlined,
                      'Active through ${widget.renewalDate}',
                      'All deliverables and your pod continue producing normally until this monthly billing cycle completes.',
                      AppColors.emerald,
                      isDark,
                    ),
                    const SizedBox(height: 10),
                    _guaranteeItem(
                      Icons.assignment_turned_in_outlined,
                      'Admin review required',
                      'AutoPay renewal pauses once approved by your agency director.',
                      Colors.amber,
                      isDark,
                    ),
                    const SizedBox(height: 10),
                    _guaranteeItem(
                      Icons.replay_rounded,
                      'Resume anytime',
                      'Reactivate your content engine in 1-tap whenever you are ready.',
                      AppColors.amber,
                      isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Reason Dropdown
              Text(
                'Reason for pause',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.ivory : AppColors.lightInk,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardBg : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedReason,
                    isExpanded: true,
                    dropdownColor: isDark ? AppColors.surface : Colors.white,
                    style: TextStyle(fontSize: 13, color: isDark ? AppColors.ivory : AppColors.lightInk),
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedReason = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Notes
              Text(
                'Additional notes (Optional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.ivory : AppColors.lightInk,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                maxLines: 2,
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.ivory : AppColors.lightInk),
                decoration: InputDecoration(
                  hintText: 'Let your pod know what to wrap up before the pause...',
                  hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.mist : AppColors.lightMist),
                  filled: true,
                  fillColor: isDark ? AppColors.cardBg : AppColors.lightSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Keep Active',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppColors.ivory : AppColors.lightInk),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isSubmitting ? null : _submit,
                      child: isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('Confirm Pause', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _guaranteeItem(IconData icon, String title, String desc, Color iconColor, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.ivory : AppColors.lightInk),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(fontSize: 11, color: isDark ? AppColors.mist : AppColors.lightMist),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

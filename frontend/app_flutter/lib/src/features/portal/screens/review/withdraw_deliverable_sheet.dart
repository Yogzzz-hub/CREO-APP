import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class WithdrawDeliverableSheet extends StatefulWidget {
  final String deliverableTitle;
  final VoidCallback? onSuccess;

  const WithdrawDeliverableSheet({
    super.key,
    this.deliverableTitle = 'Artisanal Studio Reveal (Reel 9:16)',
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    String deliverableTitle = 'Artisanal Studio Reveal (Reel 9:16)',
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WithdrawDeliverableSheet(
        deliverableTitle: deliverableTitle,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<WithdrawDeliverableSheet> createState() => _WithdrawDeliverableSheetState();
}

class _WithdrawDeliverableSheetState extends State<WithdrawDeliverableSheet> {
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason for withdrawal')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pop(context);
    widget.onSuccess?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Asset withdrawn and archived. Creative pod notified.'),
        backgroundColor: Colors.redAccent,
      ),
    );
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
        border: Border.all(color: Colors.red.withAlpha(70)),
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

            // Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withAlpha(70)),
                  ),
                  child: const Icon(Icons.archive_outlined, color: Colors.redAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Withdraw / Archive Deliverable',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.ivory : AppColors.lightInk,
                        ),
                      ),
                      Text(
                        widget.deliverableTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.mist : AppColors.lightMist,
                        ),
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
            const SizedBox(height: 14),

            // Accountability & Archival Notice Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withAlpha(60)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Accountability & Archival Notice',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.redAccent),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Even after approval, deliverables with minor issues can be safely retracted. The asset will be safely archived (not permanently erased) so previous versions can be reviewed.',
                          style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Reason
            Text(
              'Reason for withdrawal *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.ivory : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.ivory : AppColors.lightInk),
              decoration: InputDecoration(
                hintText: 'e.g. Minor typo identified in hook caption; withdrawing for quick polish before client publishing...',
                hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.mist : AppColors.lightMist),
                filled: true,
                fillColor: isDark ? AppColors.cardBg : AppColors.lightSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 18),

            // Buttons
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
                      'Cancel',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.ivory : AppColors.lightInk),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm Withdrawal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

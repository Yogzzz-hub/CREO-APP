import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_pill_button.dart';

class InvoiceDetailModal extends StatelessWidget {
  final String invoiceId;
  final String date;
  final String amount;
  final String planName;
  final String status;

  const InvoiceDetailModal({
    super.key,
    required this.invoiceId,
    required this.date,
    required this.amount,
    required this.planName,
    this.status = 'Paid',
  });

  static Future<void> show(
    BuildContext context, {
    required String invoiceId,
    required String date,
    required String amount,
    required String planName,
    String status = 'Paid',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InvoiceDetailModal(
        invoiceId: invoiceId,
        date: date,
        amount: amount,
        planName: planName,
        status: status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final numAmount = double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 49999.0;
    final baseAmount = (numAmount / 1.18);
    final cgst = (numAmount - baseAmount) / 2;
    final sgst = cgst;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.mist.withAlpha(80) : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Top action bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: AppColors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Official Tax Invoice',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.ivory : AppColors.lightInk,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'GST COMPLIANT',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.emerald),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        invoiceId,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.amber),
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
                // Billed by / Billed to cards
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardBg : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BILLED BY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.amber)),
                            const SizedBox(height: 4),
                            Text('Creo Creative Pvt Ltd', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? AppColors.ivory : AppColors.lightInk)),
                            Text('GSTIN: 33AACCC1234F1Z9', style: TextStyle(fontSize: 10, color: isDark ? AppColors.mist : AppColors.lightMist)),
                            Text('Cyber City, Chennai', style: TextStyle(fontSize: 10, color: isDark ? AppColors.mist : AppColors.lightMist)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardBg : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BILLED TO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.amber)),
                            const SizedBox(height: 4),
                            Text('Arvind N (Brand Client)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? AppColors.ivory : AppColors.lightInk)),
                            Text('client@creo.agency', style: TextStyle(fontSize: 10, color: isDark ? AppColors.mist : AppColors.lightMist)),
                            Text('Date: $date', style: TextStyle(fontSize: 10, color: isDark ? AppColors.mist : AppColors.lightMist)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Line items
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardBg : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surface : Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text('ITEM / SAC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? AppColors.mist : AppColors.lightMist))),
                            Text('AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? AppColors.mist : AppColors.lightMist)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$planName — Monthly Retainer',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppColors.ivory : AppColors.lightInk),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'SAC Code: 998311 · 1 Month allocation',
                                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.mist : AppColors.lightMist),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${baseAmount.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? AppColors.ivory : AppColors.lightInk),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Calculation breakdown
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardBg : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
                  ),
                  child: Column(
                    children: [
                      _row('Subtotal (Excl. Tax)', '₹${baseAmount.toStringAsFixed(2)}', isDark),
                      const SizedBox(height: 8),
                      _row('CGST (9.0%)', '₹${cgst.toStringAsFixed(2)}', isDark),
                      const SizedBox(height: 8),
                      _row('SGST (9.0%)', '₹${sgst.toStringAsFixed(2)}', isDark),
                      const Divider(height: 20, color: AppColors.line),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Paid', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? AppColors.ivory : AppColors.lightInk)),
                          Text('₹${numAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.amber)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Download action
                CreoPillButton(
                  label: 'Download PDF Tax Invoice',
                  icon: Icons.download_rounded,
                  isPrimary: true,
                  fullWidth: true,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloaded tax invoice $invoiceId!'),
                        backgroundColor: AppColors.amber,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.mist : AppColors.lightMist)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.ivory : AppColors.lightInk)),
      ],
    );
  }
}

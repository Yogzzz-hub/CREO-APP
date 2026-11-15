import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_pill_button.dart';

class PlanBargainModal extends StatefulWidget {
  final String initialTopic;
  final VoidCallback? onSuccess;

  const PlanBargainModal({
    super.key,
    this.initialTopic = 'Custom Pricing / Retainer Discount',
    this.onSuccess,
  });

  static Future<void> show(BuildContext context, {String initialTopic = 'Custom Pricing / Retainer Discount', VoidCallback? onSuccess}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlanBargainModal(
        initialTopic: initialTopic,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<PlanBargainModal> createState() => _PlanBargainModalState();
}

class _PlanBargainModalState extends State<PlanBargainModal> {
  final List<String> topics = [
    'Custom Pricing / Retainer Discount',
    'Custom Quotas (More Reels / Stories)',
    'Multi-Brand / Enterprise Volume Package',
    'Plan Consultation (Starter vs Accelerator vs Enterprise)',
  ];

  final List<String> timeSlots = [
    'Immediate / ASAP (Next 30 mins)',
    'Today Afternoon (2:00 PM - 5:00 PM)',
    'Today Evening (6:00 PM - 9:00 PM)',
    'Tomorrow Morning (10:00 AM - 1:00 PM)',
  ];

  late String selectedTopic;
  late String selectedTimeSlot;
  final TextEditingController offerController = TextEditingController();
  final TextEditingController phoneController = TextEditingController(text: '+91 98401 23456');
  final TextEditingController notesController = TextEditingController();
  bool isSubmitting = false;
  bool isSubmitted = false;

  @override
  void initState() {
    super.initState();
    selectedTopic = topics.contains(widget.initialTopic) ? widget.initialTopic : topics[0];
    selectedTimeSlot = timeSlots[0];
  }

  @override
  void dispose() {
    offerController.dispose();
    phoneController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a contact phone number')),
      );
      return;
    }

    setState(() => isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      isSubmitting = false;
      isSubmitted = true;
    });
    widget.onSuccess?.call();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.amber.withAlpha(80)),
                  ),
                  child: const Icon(Icons.phone_in_talk_rounded, color: AppColors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request Custom Quota & Call',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.ivory : AppColors.lightInk,
                        ),
                      ),
                      Text(
                        'Direct consultation with Creo Agency Director',
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
          ),

          const Divider(height: 1, color: AppColors.line),

          Expanded(
            child: isSubmitted
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.amber.withAlpha(30),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.amber.withAlpha(80)),
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: AppColors.amber, size: 38),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Consultation Call Scheduled',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.ivory : AppColors.lightInk,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Our director has received your request and will call you at $selectedTimeSlot.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.mist : AppColors.lightMist,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Direct WhatsApp Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withAlpha(25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.emerald.withAlpha(70)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.emerald,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Need urgent answer?',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emerald),
                                  ),
                                  Text(
                                    'Connect on WhatsApp direct line with Agency Director',
                                    style: TextStyle(fontSize: 10, color: isDark ? AppColors.mist : AppColors.lightMist),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.emerald,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Opening WhatsApp direct channel...')),
                                );
                              },
                              child: const Text('Chat Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Topic
                      _label('Consultation Topic', isDark),
                      _dropdown(
                        value: selectedTopic,
                        items: topics,
                        onChanged: (v) => setState(() => selectedTopic = v!),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),

                      // Proposed Scope / Budget
                      _label('Proposed Scope or Target Budget (Optional)', isDark),
                      TextField(
                        controller: offerController,
                        style: TextStyle(fontSize: 13, color: isDark ? AppColors.ivory : AppColors.lightInk),
                        decoration: _inputDecoration('e.g. 10 reels/mo at ₹35,000 or custom founder shoot', isDark),
                      ),
                      const SizedBox(height: 14),

                      // Contact Phone
                      _label('Contact Phone / WhatsApp *', isDark),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(fontSize: 13, color: isDark ? AppColors.ivory : AppColors.lightInk),
                        decoration: _inputDecoration('+91 98765 43210', isDark),
                      ),
                      const SizedBox(height: 14),

                      // Preferred time
                      _label('Preferred Call Window', isDark),
                      _dropdown(
                        value: selectedTimeSlot,
                        items: timeSlots,
                        onChanged: (v) => setState(() => selectedTimeSlot = v!),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      _label('Additional Context / Brand Goals (Optional)', isDark),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        style: TextStyle(fontSize: 13, color: isDark ? AppColors.ivory : AppColors.lightInk),
                        decoration: _inputDecoration('Share your brand niche, posting rhythm, or turnaround needs...', isDark),
                      ),
                      const SizedBox(height: 24),

                      // Submit
                      CreoPillButton(
                        label: isSubmitting ? 'Sending Request...' : 'Schedule Call with Agency Director',
                        icon: Icons.send_rounded,
                        isPrimary: true,
                        fullWidth: true,
                        onPressed: isSubmitting ? null : _submit,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.ivory : AppColors.lightInk,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBg : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.surface : Colors.white,
          style: TextStyle(fontSize: 13, color: isDark ? AppColors.ivory : AppColors.lightInk),
          items: items.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.mist : AppColors.lightMist),
      filled: true,
      fillColor: isDark ? AppColors.cardBg : AppColors.lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.amber),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

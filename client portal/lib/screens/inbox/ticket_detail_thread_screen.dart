import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_pill_button.dart';
import '../../widgets/creo_animations.dart';

class TicketDetailThreadScreen extends StatefulWidget {
  final String ticketId;
  final String title;
  final String status;
  final String category;
  final String priority;

  const TicketDetailThreadScreen({
    super.key,
    required this.ticketId,
    required this.title,
    this.status = 'in_progress',
    this.category = 'Content',
    this.priority = 'High',
  });

  static Future<void> show(
    BuildContext context, {
    required String ticketId,
    required String title,
    String status = 'in_progress',
    String category = 'Content',
    String priority = 'High',
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => TicketDetailThreadScreen(
          ticketId: ticketId,
          title: title,
          status: status,
          category: category,
          priority: priority,
        ),
      ),
    );
  }

  @override
  State<TicketDetailThreadScreen> createState() => _TicketDetailThreadScreenState();
}

class _TicketDetailThreadScreenState extends State<TicketDetailThreadScreen> {
  final TextEditingController _replyController = TextEditingController();

  late List<_TicketMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = [
      _TicketMessage(
        id: 'm1',
        sender: 'Arvind N (Client)',
        role: 'Client',
        time: 'Yesterday at 4:15 PM',
        text: 'Hi team, I noticed the reel deliverable scheduled for yesterday hasn\'t appeared in the Review tab. Can you check on the color grade progress?',
        isMe: true,
      ),
      _TicketMessage(
        id: 'm2',
        sender: 'Yogalakshmi (Pod Lead)',
        role: 'Pod Lead',
        time: 'Yesterday at 4:48 PM',
        text: 'Hi Arvind, apologies for the short wait! The editor finished the 4K render and it passed QA. It is now live in your Review tab for approval.',
        isMe: false,
      ),
    ];
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    setState(() {
      _messages.add(
        _TicketMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: 'Arvind N (Client)',
          role: 'Client',
          time: 'Just now',
          text: text,
          isMe: true,
        ),
      );
      _replyController.clear();
    });

    // Simulate auto-acknowledgement
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _messages.add(
            _TicketMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: 'Support Specialist',
              role: 'Specialist',
              time: 'Just now',
              text: 'Thanks for the update! Our specialists are on it.',
              isMe: false,
            ),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isResolved = widget.status.toLowerCase() == 'resolved';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ticketId, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
            Text(widget.category, style: TextStyle(fontSize: 11, color: isDark ? AppColors.mist : AppColors.lightMist)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isResolved ? AppColors.emerald.withAlpha(25) : Colors.amber.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isResolved ? AppColors.emerald.withAlpha(70) : Colors.amber.withAlpha(70)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isResolved ? Icons.check_circle_rounded : Icons.pending_rounded, size: 12, color: isResolved ? AppColors.emerald : Colors.amber),
                const SizedBox(width: 4),
                Text(
                  isResolved ? 'RESOLVED' : 'IN PROGRESS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isResolved ? AppColors.emerald : Colors.amber),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Resolution Meta Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardBg : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? AppColors.ivory : AppColors.lightInk),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 14, color: AppColors.amber),
                        const SizedBox(width: 4),
                        Text(
                          'Creative Pod Alpha',
                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.mist : AppColors.lightMist),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: AppColors.emerald),
                        const SizedBox(width: 4),
                        Text(
                          '4h SLA Guaranteed',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? AppColors.ivory : AppColors.lightInk),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Message Thread List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                return CreoFadeSlide(
                  delay: Duration(milliseconds: 40 * i),
                  child: _buildMessageBubble(msg, isDark),
                );
              },
            ),
          ),

          // Message Composer Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardBg : AppColors.lightSurface,
              border: Border(top: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    style: TextStyle(fontSize: 13, color: isDark ? AppColors.ivory : AppColors.lightInk),
                    decoration: InputDecoration(
                      hintText: 'Reply to your creative pod...',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.mist : AppColors.lightMist),
                      filled: true,
                      fillColor: isDark ? AppColors.surface : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.amber),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_TicketMessage msg, bool isDark) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: msg.isMe
              ? AppColors.amber
              : (isDark ? AppColors.cardBg : AppColors.lightSurface),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
            bottomRight: Radius.circular(msg.isMe ? 4 : 16),
          ),
          border: Border.all(
            color: msg.isMe ? AppColors.amber : (isDark ? AppColors.line : AppColors.lightBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.sender,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: msg.isMe ? Colors.black : (isDark ? AppColors.ivory : AppColors.lightInk),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  msg.time,
                  style: TextStyle(
                    fontSize: 9,
                    color: msg.isMe ? Colors.black54 : (isDark ? AppColors.mist : AppColors.lightMist),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: msg.isMe ? Colors.black87 : (isDark ? AppColors.ivory : AppColors.lightInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketMessage {
  final String id;
  final String sender;
  final String role;
  final String time;
  final String text;
  final bool isMe;

  const _TicketMessage({
    required this.id,
    required this.sender,
    required this.role,
    required this.time,
    required this.text,
    required this.isMe,
  });
}

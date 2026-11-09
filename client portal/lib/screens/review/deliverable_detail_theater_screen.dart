import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/deliverable_model.dart';
import '../../widgets/creo_pill_button.dart';

class DeliverableDetailTheaterScreen extends StatefulWidget {
  final DeliverableItem deliverable;
  final VoidCallback onApprove;
  final Function(String) onRequestChanges;

  const DeliverableDetailTheaterScreen({
    super.key,
    required this.deliverable,
    required this.onApprove,
    required this.onRequestChanges,
  });

  @override
  State<DeliverableDetailTheaterScreen> createState() => _DeliverableDetailTheaterScreenState();
}

class _DeliverableDetailTheaterScreenState extends State<DeliverableDetailTheaterScreen> {
  bool _isPlaying = true;
  bool _isRecordingVoice = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.deliverable;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Mock 9:16 Video Player Container ──
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isPlaying = !_isPlaying),
              child: Container(
                color: const Color(0xFF141210),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: CreoColors.amber.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: CreoColors.amber,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: CreoColors.ivory,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '9:16 Theater View · v${item.version} · Tap to ${_isPlaying ? "Pause" : "Play"}',
                        style: const TextStyle(
                          color: CreoColors.mist,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Top Bar Controls ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'v${item.version} · ${item.aspectRatioTag}',
                      style: const TextStyle(
                        color: CreoColors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined, color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Action Dock ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.95),
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Caption & Topic
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hook angle: "Direct curiosity". Sound sync locked to trending audio. Ready for client sign-off.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Actions: Voice Note, Changes, Approve
                  Row(
                    children: [
                      // Voice Feedback Hold Button
                      GestureDetector(
                        onTapDown: (_) => setState(() => _isRecordingVoice = true),
                        onTapUp: (_) => setState(() => _isRecordingVoice = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _isRecordingVoice
                                ? CreoColors.terracotta
                                : Colors.white12,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isRecordingVoice ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Request Changes
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openRevisionModal(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Request changes',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 1-Click Approve (Burnished Amber)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onApprove();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CreoColors.amber,
                            foregroundColor: CreoColors.onAmber,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Approve Reel',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openRevisionModal(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: CreoColors.bentoCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revision Notes',
              style: TextStyle(
                color: CreoColors.ivory,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(color: CreoColors.ivory),
              decoration: InputDecoration(
                hintText: 'Enter feedback for your video editor...',
                hintStyle: const TextStyle(color: CreoColors.mist),
                filled: true,
                fillColor: CreoColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: CreoColors.line),
                ),
              ),
            ),
            const SizedBox(height: 16),
            CreoPillButton(
              label: 'Submit to Pod',
              width: double.infinity,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
                widget.onRequestChanges(controller.text);
              },
            ),
          ],
        ),
      ),
    );
  }
}


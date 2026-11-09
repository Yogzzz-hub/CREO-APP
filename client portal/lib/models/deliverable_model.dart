class DeliverableItem {
  final String id;
  final String title;
  final String status;
  final String statusLabel;
  final String deliverableType;
  final String formatLabel;
  final int version;
  final String? fileUrl;
  final String? downloadUrl;
  final bool isVideo;
  final int revisionsUsed;
  final int maxRevisions;
  final String? scheduledDate;
  final String? voiceNoteUrl;
  final int? voiceNoteDuration;

  DeliverableItem({
    required this.id,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.deliverableType,
    required this.formatLabel,
    required this.version,
    this.fileUrl,
    this.downloadUrl,
    required this.isVideo,
    this.revisionsUsed = 0,
    this.maxRevisions = 2,
    this.scheduledDate,
    this.voiceNoteUrl,
    this.voiceNoteDuration,
  });

  bool get needsApproval => status == 'pending_approval';
  bool get inRevision => status == 'revision_requested';
  bool get isApproved => ['approved', 'scheduled', 'publishing', 'published'].contains(status);

  String get aspectRatioTag {
    if (deliverableType == 'reel' || deliverableType == 'story' || isVideo) return '9:16';
    if (deliverableType == 'poster' || deliverableType == 'static_post') return '1:1';
    if (deliverableType == 'carousel') return '4:5';
    return '1:1';
  }

  factory DeliverableItem.fromJson(Map<String, dynamic> json) {
    final type = (json['deliverable_type'] ?? json['type'] ?? 'reel').toString().toLowerCase();
    final isVid = (json['is_video'] as bool?) ?? (type == 'reel');

    return DeliverableItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Creative',
      status: json['status']?.toString() ?? 'pending_approval',
      statusLabel: json['status_label']?.toString() ?? 'Needs you',
      deliverableType: type,
      formatLabel: json['format_label']?.toString() ?? type.toUpperCase(),
      version: json['version'] as int? ?? 1,
      fileUrl: json['file_url']?.toString(),
      downloadUrl: json['download_url']?.toString(),
      isVideo: isVid,
      revisionsUsed: json['revisions_used'] as int? ?? 0,
      maxRevisions: json['max_revisions'] as int? ?? 2,
      scheduledDate: json['scheduled_date']?.toString(),
      voiceNoteUrl: json['voice_note_url']?.toString(),
      voiceNoteDuration: json['voice_note_duration'] as int?,
    );
  }
}


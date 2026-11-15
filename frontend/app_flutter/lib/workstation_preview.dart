// Explicit development entrypoint. Never creates or adopts an auth session.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/core/app_appearance.dart';
import 'src/core/app_theme.dart';
import 'src/core/auth_repository.dart';
import 'src/features/workstation/workstation_data.dart';
import 'src/features/workstation/workstation_page.dart';

const workstationPreviewUser = AuthUser(
  id: 'preview-member',
  email: 'preview@example.invalid',
  fullName: 'Preview Member',
  role: 'editor',
  accountStatus: 'active',
  onboardingStage: 8,
);

Future<WorkstationData> loadWorkstationPreview() async => WorkstationData(
  podName: 'Preview Pod',
  members: const [
    WorkstationMember(
      'Preview Lead',
      'team_lead',
      'Pod lead · Review & direction',
    ),
    WorkstationMember('Preview Member', 'editor', 'Video editor'),
  ],
  inProduction: [
    WorkstationTask(
      id: 'preview-1',
      client: 'Sample brand',
      title: 'Product story · first cut',
      format: 'reel',
      status: 'in_production',
      assignedTo: 'preview-member',
      due: DateTime.now().add(const Duration(hours: 4)),
    ),
    WorkstationTask(
      id: 'preview-2',
      client: 'Sample studio',
      title: 'Weekly editorial carousel',
      format: 'carousel',
      status: 'in_production',
      assignedTo: 'preview-other',
      due: DateTime.now().add(const Duration(days: 2)),
    ),
  ],
  inQa: const [
    WorkstationTask(
      id: 'preview-3',
      client: 'Sample brand',
      title: 'Behind the scenes',
      format: 'story',
      status: 'internal_qa',
      assignedTo: 'preview-member',
      feedback:
          'Please adjust the opening title and keep the final frame on screen a little longer.',
    ),
  ],
  backlog: const [
    WorkstationTask(
      id: 'preview-4',
      client: 'Sample brand',
      title: 'Next week’s launch teaser',
      format: 'reel',
      status: 'yet_to_do',
    ),
  ],
  completed: const [
    WorkstationTask(
      id: 'preview-5',
      client: 'Sample brand',
      title: 'Brand introduction',
      format: 'reel',
      status: 'completed',
      assignedTo: 'preview-member',
      version: 2,
    ),
  ],
  notices: const [
    WorkstationNotice(
      'Sample review feedback',
      'The preview includes one task with review notes.',
    ),
  ],
);

void main() {
  if (!kDebugMode) {
    throw StateError(
      'The workstation preview is only available in debug builds.',
    );
  }
  runApp(const WorkstationPreviewApp());
}

class WorkstationPreviewApp extends StatefulWidget {
  const WorkstationPreviewApp({super.key});
  @override
  State<WorkstationPreviewApp> createState() => _WorkstationPreviewAppState();
}

class _WorkstationPreviewAppState extends State<WorkstationPreviewApp> {
  final appearance = CreoAppearance(
    read: () async => null,
    write: (_) async {},
  );
  @override
  void dispose() {
    appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appearance,
    builder: (context, _) => MaterialApp(
      title: 'Creo — Workstation Preview',
      debugShowCheckedModeBanner: false,
      theme: buildCreoTheme(brightness: Brightness.light),
      darkTheme: buildCreoTheme(),
      themeMode: appearance.mode,
      themeAnimationDuration: Duration.zero,
      builder: (context, child) =>
          CreoAppearanceScope(appearance: appearance, child: child!),
      home: const WorkstationPage(
        user: workstationPreviewUser,
        load: loadWorkstationPreview,
        preview: true,
      ),
    ),
  );
}

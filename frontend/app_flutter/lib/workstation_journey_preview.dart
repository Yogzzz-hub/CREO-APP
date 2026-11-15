import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'main.dart';
import 'src/core/app_appearance.dart';
import 'src/features/workstation/workstation_preview_fixtures.dart';
import 'src/features/workstation/workstation_meetings_page.dart';

/// Run only with -t lib/workstation_journey_preview.dart.
/// Choose freelancer with --dart-define=PREVIEW_ROLE=freelancer.
Future<void> main() async {
  if (!kDebugMode) {
    throw StateError(
      'Development journey preview cannot run in a release/profile build.',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  const configuredRole = String.fromEnvironment(
    'PREVIEW_ROLE',
    defaultValue: 'editor',
  );
  // URL selection is confined to this debug fixture entrypoint. The fixture
  // constructor rejects every role other than editor/freelancer.
  runApp(
    WorkstationJourneyPreview(
      role: Uri.base.queryParameters['role'] ?? configuredRole,
    ),
  );
}

class WorkstationJourneyPreview extends StatefulWidget {
  const WorkstationJourneyPreview({super.key, this.role = 'editor'});
  final String role;
  @override
  State<WorkstationJourneyPreview> createState() =>
      _WorkstationJourneyPreviewState();
}

class _WorkstationJourneyPreviewState extends State<WorkstationJourneyPreview> {
  late final fixtures = WorkstationPreviewFixtures(role: widget.role);
  late final session = fixtures.createSession();
  final _meetingPreferences = <String, String>{};
  late final meetingStore = WorkstationMeetingStore(
    read: (key) async => _meetingPreferences[key],
    write: (key, value) async {
      if (value == null) {
        _meetingPreferences.remove(key);
      } else {
        _meetingPreferences[key] = value;
      }
    },
  );
  late final appearance = CreoAppearance(
    read: () async => null,
    write: (_) async {},
  );
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF5C371D),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: const Text(
                'DEVELOPMENT PREVIEW · Sample data · No live account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFFF2DF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: WorkstationMeetingScope(
                store: meetingStore,
                child: CreoApp(session: session, appearance: appearance),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    session.dispose();
    appearance.dispose();
    fixtures.close();
    super.dispose();
  }
}

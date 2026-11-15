import 'dart:convert';
import 'dart:io';

import 'package:app_flutter/src/features/portal/portal_repository.dart';
import 'package:app_flutter/src/features/portal/screens/portal_workspace_page.dart';
import 'package:app_flutter/src/features/workstation/workstation_files.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'auth_contract_test.dart' show code;
import 'session_lifecycle_test.dart' show jsonResponse;
import 'workstation_hub_test.dart' show hubOwner;

void main() {
  test(
    'calendar records preserve the standalone per-entry response contract',
    () async {
      final requests = <http.Request>[];
      final session = await hubOwner((request) async {
        requests.add(request);
        return jsonResponse([
          {
            'id': 'slot-1',
            'concept_status': 'concept_pending',
            'blueprint': {
              'hooks': [
                {
                  'angle': 'story',
                  'text': 'Hook from server',
                  'rationale': 'Why it works',
                },
              ],
            },
          },
        ]);
      }, role: 'client');
      addTearDown(session.dispose);

      final entries = await PortalRepository(session).calendarEntries();

      expect(requests.single.url.path, '/api/v1/calendar/entries');
      expect(entries.single['id'], 'slot-1');
      expect((entries.single['blueprint'] as Map)['hooks'], hasLength(1));
    },
  );

  test(
    'concept approval sends selected server hook and validates confirmation',
    () async {
      final requests = <http.Request>[];
      final session = await hubOwner((request) async {
        requests.add(request);
        return jsonResponse({
          'status': 'concept_approved',
          'slot_id': 'slot-1',
          'selected_hook': {'text': 'Hook from server'},
        });
      }, role: 'client');
      addTearDown(session.dispose);

      await PortalRepository(
        session,
      ).approveConcept('slot-1', selectedHook: {'text': 'Hook from server'});

      expect(
        requests.single.url.path,
        '/api/v1/calendar/slots/slot-1/approve-concept',
      );
      expect(jsonDecode(requests.single.body), {
        'selected_hook': {'text': 'Hook from server'},
        'notes': 'Client approved concept',
      });
    },
  );

  test(
    'concept revision posts actual client notes and checks slot id',
    () async {
      final requests = <http.Request>[];
      final session = await hubOwner((request) async {
        requests.add(request);
        return jsonResponse({
          'status': 'revision_requested',
          'slot_id': 'slot-1',
          'feedback': 'Use a calmer opening',
        });
      }, role: 'client');
      addTearDown(session.dispose);

      await PortalRepository(
        session,
      ).requestConceptChanges('slot-1', 'Use a calmer opening');

      expect(
        requests.single.url.path,
        '/api/v1/calendar/slots/slot-1/request-changes',
      );
      expect(jsonDecode(requests.single.body), {
        'notes': 'Use a calmer opening',
      });
    },
  );

  test('deliverable approval includes an idempotency key', () async {
    http.Request? submitted;
    final session = await hubOwner((request) async {
      submitted = request;
      return jsonResponse({
        'status': 'approved',
        'deliverable_id': 'delivery-1',
      });
    }, role: 'client');
    addTearDown(session.dispose);

    await PortalRepository(session).approveDeliverable('delivery-1');

    expect(submitted?.url.path, '/api/v1/deliverables/delivery-1/approve');
    expect(
      submitted?.headers['idempotency-key'],
      matches(RegExp(r'^[0-9a-f-]{36}$')),
    );
  });

  test(
    'voice feedback revision retains audio URL in the server request',
    () async {
      http.Request? submitted;
      final session = await hubOwner((request) async {
        submitted = request;
        return jsonResponse({
          'status': 'revision_requested',
          'deliverable_id': 'delivery-1',
          'revision_round': 2,
        });
      }, role: 'client');
      addTearDown(session.dispose);

      await PortalRepository(session).requestDeliverableChanges(
        'delivery-1',
        'Please adjust the pacing',
        voiceNoteUrl: 'https://media.example.test/voice-note.m4a',
        voiceNoteDuration: 18,
      );

      expect(
        submitted?.url.path,
        '/api/v1/deliverables/delivery-1/request-changes',
      );
      expect(jsonDecode(submitted!.body), {
        'rejection_comment': 'Please adjust the pacing',
        'voice_note_url': 'https://media.example.test/voice-note.m4a',
        'voice_note_duration': 18,
      });
    },
  );

  test(
    'write response with a different slot cannot be reported as success',
    () async {
      final session = await hubOwner(
        (_) async => jsonResponse({
          'status': 'concept_approved',
          'slot_id': 'another-slot',
        }),
        role: 'client',
      );
      addTearDown(session.dispose);

      await expectLater(
        PortalRepository(session).approveConcept('slot-1'),
        throwsA(code('WRITE_UNCONFIRMED')),
      );
    },
  );

  test(
    'voice upload uses authenticated multipart audio field and real deliverable id',
    () async {
      final audio = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'portal-audio-${DateTime.now().microsecondsSinceEpoch}.m4a',
      );
      await audio.writeAsBytes([0, 1, 2, 3]);
      addTearDown(() async {
        if (await audio.exists()) await audio.delete();
      });
      http.Request? submitted;
      final session = await hubOwner((request) async {
        submitted = request;
        return jsonResponse({
          'storage_key': 'voice-notes/client/file.m4a',
          'voice_note_url': 'https://media.example.test/file.m4a',
          'duration': null,
          'file_size_bytes': 4,
        });
      }, role: 'client');
      addTearDown(session.dispose);

      final uploaded = await PortalRepository(session).uploadVoiceNote(
        'deliverable-1',
        WorkstationFile(
          path: audio.path,
          name: 'feedback.m4a',
          size: 4,
          mimeType: 'audio/mp4',
        ),
      );

      expect(
        submitted?.url.path,
        '/api/v1/deliverables/deliverable-1/upload-voice-note',
      );
      expect(submitted?.headers['authorization'], startsWith('Bearer '));
      expect(
        submitted?.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(
        submitted?.body,
        contains('name="audio"; filename="feedback.m4a"'),
      );
      expect(uploaded['voice_note_url'], 'https://media.example.test/file.m4a');
    },
  );

  test(
    'approved archive uses authenticated binary endpoint and headers',
    () async {
      http.Request? submitted;
      final session = await hubOwner((request) async {
        submitted = request;
        return http.Response.bytes(
          [0x50, 0x4b, 0x03, 0x04],
          200,
          headers: {
            'content-type': 'application/zip',
            'content-disposition':
                'attachment; filename=creo_approved_assets.zip',
          },
        );
      }, role: 'client');
      addTearDown(session.dispose);

      final archive = await PortalRepository(session).approvedAssetsArchive();

      expect(submitted?.url.path, '/api/v1/portal/deliverables/download-zip');
      expect(submitted?.headers['authorization'], startsWith('Bearer '));
      expect(archive.contentType, 'application/zip');
      expect(archive.contentDisposition, contains('creo_approved_assets.zip'));
      expect(archive.bytes, [0x50, 0x4b, 0x03, 0x04]);
    },
  );

  test(
    'native archive save sends bytes and metadata to OS save channel',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MethodCall? received;
      messenger.setMockMethodCallHandler(WorkstationFileTransfer.channel, (
        call,
      ) async {
        received = call;
        return true;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          WorkstationFileTransfer.channel,
          null,
        ),
      );

      expect(
        await WorkstationFileTransfer.saveBytes(
          bytes: Uint8List.fromList([0x50, 0x4b]),
          name: 'assets.zip',
          mimeType: 'application/zip',
        ),
        isTrue,
      );
      expect(received?.method, 'save');
      expect(received?.arguments, {
        'bytes': Uint8List.fromList([0x50, 0x4b]),
        'name': 'assets.zip',
        'mimeType': 'application/zip',
      });
    },
  );

  testWidgets(
    'calendar hook choice is submitted and only server success is shown',
    (tester) async {
      var approved = false;
      final requests = <http.Request>[];
      final session = await hubOwner((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/portal/calendar') {
          return jsonResponse({'cycle': null, 'slots': [], 'shoot_days': []});
        }
        if (request.url.path == '/api/v1/calendar/entries') {
          return jsonResponse([
            {
              'id': 'slot-1',
              'topic': 'Spring launch reel',
              'date': '2030-04-01',
              'status': approved ? 'approved' : 'draft',
              'concept_status': approved
                  ? 'concept_approved'
                  : 'concept_pending',
              'blueprint': {
                'hooks': [
                  {
                    'angle': 'story',
                    'text': 'Hook from the real brief',
                    'rationale': 'This speaks to the saved audience',
                  },
                ],
              },
            },
          ]);
        }
        if (request.url.path.endsWith('/approve-concept')) {
          approved = true;
          return jsonResponse({
            'status': 'concept_approved',
            'slot_id': 'slot-1',
            'selected_hook': jsonDecode(request.body)['selected_hook'],
          });
        }
        return jsonResponse({'detail': 'Unexpected test request'}, 404);
      }, role: 'client');
      addTearDown(session.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: PortalWorkspacePage(
            session: session,
            section: PortalSection.calendar,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Spring launch reel'), findsOneWidget);
      await tester.tap(find.text('Review concept and hooks'));
      await tester.pumpAndSettle();
      expect(find.text('Hook from the real brief'), findsOneWidget);
      await tester.tap(find.text('Approve selected concept'));
      await tester.pumpAndSettle();

      final approval = requests.singleWhere(
        (request) => request.url.path.endsWith('/approve-concept'),
      );
      expect(
        jsonDecode(approval.body)['selected_hook']['text'],
        'Hook from the real brief',
      );
      expect(
        find.text('Concept approval was confirmed by the server.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

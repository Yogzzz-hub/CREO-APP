import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/src/core/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<String> _messageFor(int status, Object body) async {
  final repo = AuthRepository(
    client: MockClient(
      (_) async => http.Response(
        body is String ? body : jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      ),
    ),
    origin: Uri.parse('https://api.example.test'),
  );
  try {
    await repo.requestJson('GET', '/api/v1/anything');
  } on HttpError catch (e) {
    return e.message;
  }
  fail('expected an HttpError');
}

void main() {
  test('server messages written for people pass through', () async {
    expect(
      await _messageFor(404, {
        'error': {'code': 'NOT_FOUND', 'message': 'Lead not found.'},
      }),
      'Lead not found.',
    );
  });

  test(
    'framework defaults and raw status lines become plain language',
    () async {
      expect(
        await _messageFor(404, {'detail': 'Not Found'}),
        "We couldn't find that. It may have been moved or deleted.",
      );
      expect(
        await _messageFor(401, {'detail': 'Not authenticated'}),
        'Your session has ended. Please sign in again.',
      );
      expect(
        await _messageFor(500, {
          'error': {
            'code': 'INTERNAL_SERVER_ERROR',
            'message': 'An unexpected server error occurred.',
          },
        }),
        'Something went wrong on our side. Please try again in a moment.',
      );
      expect(
        await _messageFor(502, '<html>Bad gateway</html>'),
        'Something went wrong on our side. Please try again in a moment.',
      );
      expect(
        await _messageFor(400, {
          'detail': 'psycopg.errors.UniqueViolation: duplicate key value',
        }),
        "That request couldn't be completed. Check the details and try again.",
      );
    },
  );

  test('validation errors name the field in plain words', () async {
    expect(
      await _messageFor(422, {
        'error': {
          'code': 'VALIDATION_ERROR',
          'message':
              'full_name: Field required; email: value is not a valid email address',
          'details': {
            'errors': [
              {
                'type': 'missing',
                'loc': ['body', 'full_name'],
                'msg': 'Field required',
              },
              {
                'type': 'value_error',
                'loc': ['body', 'email'],
                'msg':
                    'value is not a valid email address: An email address must have an @-sign.',
              },
            ],
          },
        },
      }),
      'Full name: is required\nEmail: enter a valid email address',
    );
  });

  test('friendlyError hides technical text from any thrown error', () {
    expect(
      friendlyError(StateError('That save is already in progress.')),
      'That save is already in progress.',
    );
    expect(
      friendlyError(StateError('Session changed')),
      'Something went wrong. Please try again.',
    );
    expect(
      friendlyError(const FormatException('Unverified response')),
      'Something went wrong. Please try again.',
    );
    expect(
      friendlyError(
        const FormatException('Your subscription could not be verified.'),
      ),
      'Your subscription could not be verified.',
    );
    expect(
      friendlyError(Exception('boom'), fallback: 'Could not save.'),
      'Could not save.',
    );
    expect(
      friendlyError(TimeoutException('x')),
      'This is taking too long. Please try again.',
    );
  });
}

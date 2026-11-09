import 'package:app_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('root exposes the existing auth routes', (tester) async {
    late MaterialApp configuration;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          final root = const CreoApp().build(context) as ListenableBuilder;
          configuration = root.builder(context, null) as MaterialApp;
          return const SizedBox();
        },
      ),
    );
    expect(configuration.routes?.keys, containsAll(['/', '/login', '/signup']));
  });
}

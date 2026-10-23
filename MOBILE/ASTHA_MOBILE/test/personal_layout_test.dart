import 'dart:convert';
import 'package:astha_app/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:astha_app/core/api_client.dart';
import 'package:astha_app/core/session_store.dart';
import 'package:astha_app/state/session_controller.dart';
import 'package:astha_app/repositories/personal_repository.dart';
import 'package:astha_app/features/personal/personal_shell.dart';

void main() {
  for (final width in [360.0, 640.0]) {
    for (final populated in [false, true]) {
      testWidgets(
        'Personal tabs lay out at phone width, populated=$populated, width=$width',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final api = ApiClient(
            baseUrl: 'https://api.example.invalid',
            client: MockClient(
              (_) async => http.Response(
                jsonEncode(
                  populated
                      ? [
                          {
                            'id': 1,
                            'name': 'Meu quarto',
                            'width': 6,
                            'depth': 5,
                            'objects': [
                              {
                                'id': 'desk-1',
                                'modelId': 'desk',
                                'name': 'Mesa',
                                'width': 1.4,
                                'depth': 0.6,
                                'height': 0.8,
                                'x': 1,
                                'z': 1,
                              },
                            ],
                            'belongings': [
                              {
                                'id': 'book-1',
                                'name': 'Livro',
                                'objectId': 'desk-1',
                              },
                            ],
                            'tasks': [
                              {
                                'id': 'task-1',
                                'title': 'Organizar mesa',
                                'due': '2026-10-22',
                                'status': 'pending',
                              },
                            ],
                            'history': [],
                          },
                        ]
                      : [],
                ),
                200,
              ),
            ),
          );
          final session = SessionController(SessionStore(), api);

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<SessionController>.value(value: session),
                ChangeNotifierProvider<ApiClient>.value(value: api),
                Provider(create: (_) => PersonalRepository(api)),
              ],
              child: MaterialApp(
                theme: AppTheme.light(),
                home: const PersonalShell(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final label in [
            'Móveis',
            'Pertences',
            'Agenda',
            'Resumo',
            'Espaços',
          ]) {
            await tester.tap(find.widgetWithText(NavigationDestination, label));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: label);
          }
          if (!populated) {
            await tester.tap(find.text('Criar meu primeiro espaço'));
            await tester.pumpAndSettle();
            expect(find.text('Criar espaço'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.tap(find.text('Cancelar'));
            await tester.pumpAndSettle();
          }
          await tester.pumpWidget(const SizedBox());
          session.dispose();
        },
      );
    }
  }
}

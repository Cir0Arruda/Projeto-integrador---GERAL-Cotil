import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:astha_app/core/connection_service.dart';

void main() {
  test(
    'only a healthy ASTHA API is online; failure never changes the selected server',
    () async {
      for (final status in [200, 401, 503]) {
        var switched = false;
        final service = ConnectionService(
          initialUrl: 'https://api.example.invalid',
          startMonitoring: false,
          onServerChanged: (_) => switched = true,
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'status': 'operational',
                'application': 'astha-raven-web',
              }),
              status,
            ),
          ),
        );
        expect(await service.checkCurrent(), status == 200);
        expect(service.isOnline, status == 200);
        expect(
          await service.autoScanAndConnect(),
          status == 200 ? service.activeUrl : null,
        );
        expect(switched, isFalse);
        expect(service.activeUrl, 'https://api.example.invalid');
        service.dispose();
      }
    },
  );
  test('an arbitrary HTTP 200 page is not an ASTHA connection', () async {
    final service = ConnectionService(
      initialUrl: 'https://api.example.invalid',
      startMonitoring: false,
      onServerChanged: (_) {},
      client: MockClient((_) async => http.Response('<html>Proxy</html>', 200)),
    );
    expect(await service.checkCurrent(), isFalse);
    expect(service.status, ConnectionStateStatus.offline);
    service.dispose();
  });
}

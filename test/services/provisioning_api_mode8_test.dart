import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pettrack_app/services/provisioning_api.dart';
import 'package:pettrack_app/services/wizard_step_result.dart';

void main() {
  group('ProvisioningApi.scan', () {
    test('returns WizardStepOk on 200 with payload', () async {
      final mockClient = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, contains('/devices/123456789012345/scan'));
        expect(req.url.queryParameters['via'], 'tcp');
        expect(req.url.queryParameters['queue'], 'true');
        expect(req.url.queryParameters['queueMs'], '60000');
        expect(req.headers['x-api-key'], isNotNull);
        return http.Response(
          jsonEncode({
            'success': true,
            'reply': {'command': 'scan', 'payload': 'AABBCCDDEE01:-45,AABBCCDDEE02:-50'},
          }),
          200,
        );
      });

      final api = ProvisioningApi(httpClient: mockClient);
      final result = await api.scan(imei: '123456789012345', queueMs: 60000);

      expect(result, isA<WizardStepOk>());
      expect((result as WizardStepOk).payload, contains('AABBCCDDEE01'));
    });

    test('returns WizardStepQueueExpired on 408', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({'error': 'queued command expired', 'queueTtlMs': 60000}),
            408,
          ));

      final api = ProvisioningApi(httpClient: mockClient);
      final result = await api.scan(imei: '123456789012345', queueMs: 60000);

      expect(result, isA<WizardStepQueueExpired>());
      expect((result as WizardStepQueueExpired).queueTtlMs, 60000);
    });

    test('returns WizardStepTimedOut on 504', () async {
      final mockClient = MockClient((_) async =>
          http.Response(jsonEncode({'error': 'command timed out'}), 504));

      final api = ProvisioningApi(httpClient: mockClient);
      final result = await api.scan(imei: '123456789012345');
      expect(result, isA<WizardStepTimedOut>());
    });

    test('returns WizardStepDeviceOffline on 503', () async {
      final mockClient = MockClient(
          (_) async => http.Response(jsonEncode({'error': 'offline'}), 503));
      final api = ProvisioningApi(httpClient: mockClient);
      final result = await api.scan(imei: '123456789012345');
      expect(result, isA<WizardStepDeviceOffline>());
    });

    test('returns WizardStepFailed on transport error (no throw)', () async {
      final mockClient = MockClient((_) async => throw Exception('boom'));
      final api = ProvisioningApi(httpClient: mockClient);
      final result = await api.scan(imei: '123456789012345');
      expect(result, isA<WizardStepFailed>());
      expect((result as WizardStepFailed).error, contains('Network error'));
    });
  });

  group('ProvisioningApi.setAccessPoints', () {
    test('sends 3 MACs as JSON body and returns Ok on AP,OK', () async {
      final mockClient = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['mac1'], 'AA:BB:CC:DD:EE:01');
        expect(body['mac2'], 'AA:BB:CC:DD:EE:02');
        expect(body['mac3'], 'AA:BB:CC:DD:EE:03');
        expect(req.url.path, contains('/access-points'));
        return http.Response(
          jsonEncode({
            'success': true,
            'reply': {'command': 'setAccessPoints', 'payload': 'AP,OK'},
          }),
          200,
        );
      });

      final api = ProvisioningApi(httpClient: mockClient);
      final result = await api.setAccessPoints(
        imei: '123456789012345',
        mac1: 'AA:BB:CC:DD:EE:01',
        mac2: 'AA:BB:CC:DD:EE:02',
        mac3: 'AA:BB:CC:DD:EE:03',
      );
      expect(result, isA<WizardStepOk>());
      expect((result as WizardStepOk).payload, 'AP,OK');
    });

    test('returns WizardStepFailed on 400 invalid MAC', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({'error': '"mac1" must be a valid MAC'}),
            400,
          ));

      final api = ProvisioningApi(httpClient: mockClient);
      final result = await api.setAccessPoints(
        imei: '123456789012345',
        mac1: 'not-a-mac',
        mac2: 'AA:BB:CC:DD:EE:02',
        mac3: 'AA:BB:CC:DD:EE:03',
      );
      expect(result, isA<WizardStepFailed>());
      expect((result as WizardStepFailed).statusCode, 400);
    });
  });

  group('ProvisioningApi.setGeoFence', () {
    test('sends lat/lon/radius and returns Ok on GEO success', () async {
      final mockClient = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['latitude'], closeTo(4.681, 0.001));
        expect(body['longitude'], closeTo(-74.048, 0.001));
        expect(body['radiusMeters'], 100);
        expect(req.url.path, contains('/geo-fence'));
        return http.Response(
          jsonEncode({
            'success': true,
            'reply': {'command': 'setGeoFence', 'payload': 'GEO,OK'},
          }),
          200,
        );
      });

      final api = ProvisioningApi(httpClient: mockClient);
      final result = await api.setGeoFence(
        imei: '123456789012345',
        latitude: 4.681,
        longitude: -74.048,
        radiusMeters: 100,
      );
      expect(result, isA<WizardStepOk>());
    });
  });

  group('ProvisioningApi.setModeHome', () {
    test('sends type=home with intervalSeconds and returns Ok', () async {
      final mockClient = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['type'], 'home');
        expect(body['intervalSeconds'], 30);
        expect(req.url.path, contains('/mode'));
        return http.Response(
          jsonEncode({
            'success': true,
            'reply': {'command': 'modeHome', 'payload': 'MODE,OK'},
          }),
          200,
        );
      });

      final api = ProvisioningApi(httpClient: mockClient);
      final result = await api.setModeHome(
        imei: '123456789012345',
        intervalSeconds: 30,
      );
      expect(result, isA<WizardStepOk>());
    });

    test('rejects intervalSeconds outside 10..60 with ArgumentError', () async {
      final api = ProvisioningApi(
          httpClient: MockClient((_) async => throw 'should not call'));
      expect(
        () => api.setModeHome(imei: '123456789012345', intervalSeconds: 9),
        throwsArgumentError,
      );
      expect(
        () => api.setModeHome(imei: '123456789012345', intervalSeconds: 61),
        throwsArgumentError,
      );
    });

    test('returns WizardStepDeviceRejected on 502 MODE,FS', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({'error': 'device rejected', 'payload': 'MODE,FS'}),
            502,
          ));

      final api = ProvisioningApi(httpClient: mockClient);
      final result = await api.setModeHome(
        imei: '123456789012345',
        intervalSeconds: 30,
      );
      expect(result, isA<WizardStepDeviceRejected>());
      expect((result as WizardStepDeviceRejected).payload, 'MODE,FS');
    });
  });
}

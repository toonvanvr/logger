import 'package:app/models/data_state_models.dart';
import 'package:app/models/log_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IconRef', () {
    test('constructor sets fields', () {
      const icon = IconRef(icon: 'check', color: 'green', size: 16.0);
      expect(icon.icon, 'check');
      expect(icon.color, 'green');
      expect(icon.size, 16.0);
    });

    test('fromJson parses all fields', () {
      final icon = IconRef.fromJson({
        'icon': 'warn',
        'color': 'yellow',
        'size': 24,
      });
      expect(icon.icon, 'warn');
      expect(icon.color, 'yellow');
      expect(icon.size, 24.0);
    });

    test('fromJson handles missing optional fields', () {
      final icon = IconRef.fromJson({'icon': 'info'});
      expect(icon.icon, 'info');
      expect(icon.color, isNull);
      expect(icon.size, isNull);
    });

    test('toJson round-trips', () {
      const icon = IconRef(icon: 'check', color: 'green', size: 16.0);
      final json = icon.toJson();
      expect(json['icon'], 'check');
      expect(json['color'], 'green');
      expect(json['size'], 16.0);
    });

    test('toJson omits null fields', () {
      const icon = IconRef(icon: 'info');
      final json = icon.toJson();
      expect(json.containsKey('color'), isFalse);
      expect(json.containsKey('size'), isFalse);
    });
  });

  group('WidgetPayload', () {
    test('constructor sets fields', () {
      const wp = WidgetPayload(type: 'chart', data: {'value': 42});
      expect(wp.type, 'chart');
      expect(wp.data['value'], 42);
    });

    test('fromJson extracts type and remaining data', () {
      final wp = WidgetPayload.fromJson({
        'type': 'progress',
        'percent': 75,
        'label': 'Loading',
      });
      expect(wp.type, 'progress');
      expect(wp.data['percent'], 75);
      expect(wp.data['label'], 'Loading');
      expect(wp.data.containsKey('type'), isFalse);
    });

    test('toJson merges type back into data', () {
      const wp = WidgetPayload(type: 'table', data: {'rows': 5});
      final json = wp.toJson();
      expect(json['type'], 'table');
      expect(json['rows'], 5);
    });
  });

  group('DataState', () {
    test('constructor with minimal fields', () {
      const ds = DataState(value: 'hello');
      expect(ds.value, 'hello');
      expect(ds.display, DisplayLocation.defaultLoc);
      expect(ds.history, isNull);
      expect(ds.widget, isNull);
      expect(ds.label, isNull);
      expect(ds.icon, isNull);
      expect(ds.updatedAt, isNull);
    });

    test('fromJson parses full payload', () {
      final ds = DataState.fromJson({
        'value': 42,
        'history': [41, 40],
        'display': 'shelf',
        'label': 'Counter',
        'updated_at': '2026-01-01T00:00:00Z',
        'icon': {'icon': 'counter'},
        'widget': {'type': 'chart', 'series': [1, 2]},
      });

      expect(ds.value, 42);
      expect(ds.history, [41, 40]);
      expect(ds.display, DisplayLocation.shelf);
      expect(ds.label, 'Counter');
      expect(ds.updatedAt, '2026-01-01T00:00:00Z');
      expect(ds.icon, isNotNull);
      expect(ds.widget!.type, 'chart');
    });

    test('fromJson defaults display to defaultLoc', () {
      final ds = DataState.fromJson({'value': 'x'});
      expect(ds.display, DisplayLocation.defaultLoc);
    });

    test('toJson round-trips', () {
      final ds = DataState.fromJson({
        'value': 'test',
        'display': 'static',
        'label': 'L',
      });
      final json = ds.toJson();
      expect(json['value'], 'test');
      expect(json['display'], 'static');
      expect(json['label'], 'L');
    });

    test('toJson omits null fields', () {
      const ds = DataState(value: 1);
      final json = ds.toJson();
      expect(json.containsKey('history'), isFalse);
      expect(json.containsKey('widget'), isFalse);
      expect(json.containsKey('label'), isFalse);
      expect(json.containsKey('icon'), isFalse);
      expect(json.containsKey('updated_at'), isFalse);
    });
  });
}

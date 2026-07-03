import 'package:flutter_test/flutter_test.dart';
import 'package:VosPass/models/w2m_models.dart';

void main() {
  group('W2MUserInfo', () {
    test('fromJson parses all fields', () {
      final json = {'id': 'u1', 'name': 'Alice', 'avatar': 'https://img/a.png'};
      final user = W2MUserInfo.fromJson(json);
      expect(user.id, 'u1');
      expect(user.name, 'Alice');
      expect(user.avatarURL, 'https://img/a.png');
      expect(user.displayName, 'Alice');
    });

    test('displayName falls back to id when name is empty', () {
      final json = {'id': 'u2', 'name': ''};
      final user = W2MUserInfo.fromJson(json);
      expect(user.displayName, 'u2');
    });

    test('avatarURL returns null when avatar is null', () {
      final json = {'id': 'u3', 'name': 'Bob'};
      final user = W2MUserInfo.fromJson(json);
      expect(user.avatarURL, isNull);
    });

    test('avatarURL returns null for empty avatar', () {
      final json = {'id': 'u4', 'name': 'Carol', 'avatar': ''};
      final user = W2MUserInfo.fromJson(json);
      expect(user.avatarURL, isNull);
    });
  });

  group('W2MEventSummary', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'e1',
        'title': 'Lunch',
        'description': 'Group lunch',
        'dates': ['2024-07-01', '2024-07-02'],
        'creator': {'id': 'u1', 'name': 'Alice'},
      };
      final summary = W2MEventSummary.fromJson(json);
      expect(summary.id, 'e1');
      expect(summary.title, 'Lunch');
      expect(summary.description, 'Group lunch');
      expect(summary.dates, ['2024-07-01', '2024-07-02']);
      expect(summary.creator.name, 'Alice');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'e2',
        'creator': {'id': 'u2', 'name': ''},
      };
      final summary = W2MEventSummary.fromJson(json);
      expect(summary.title, '');
      expect(summary.description, '');
      expect(summary.dates, isEmpty);
    });
  });

  group('W2MEventListResponse', () {
    test('fromJson parses created and participated lists', () {
      final json = {
        'created': [
          {
            'id': 'e1',
            'title': 'A',
            'description': '',
            'dates': [],
            'creator': {'id': 'u1', 'name': 'Alice'},
          },
        ],
        'participated': [
          {
            'id': 'e2',
            'title': 'B',
            'description': '',
            'dates': [],
            'creator': {'id': 'u2', 'name': 'Bob'},
          },
        ],
      };
      final response = W2MEventListResponse.fromJson(json);
      expect(response.created.length, 1);
      expect(response.created[0].title, 'A');
      expect(response.participated.length, 1);
      expect(response.participated[0].title, 'B');
    });

    test('fromJson handles missing lists', () {
      final json = <String, dynamic>{};
      final response = W2MEventListResponse.fromJson(json);
      expect(response.created, isEmpty);
      expect(response.participated, isEmpty);
    });
  });

  group('W2MEvent', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'ev1',
        'title': 'Meeting',
        'slots': ['2024-07-01 09:00', '2024-07-01 09:30', '2024-07-02 10:00'],
        'availability': [
          {
            'user': {'id': 'u1', 'name': 'Alice'},
            'slots': ['2024-07-01 09:00', '2024-07-01 09:30'],
          },
          {
            'user': {'id': 'u2', 'name': 'Bob'},
            'slots': ['2024-07-01 09:00'],
          },
        ],
        'creator': {'id': 'u1', 'name': 'Alice'},
      };
      final event = W2MEvent.fromJson(json);
      expect(event.id, 'ev1');
      expect(event.title, 'Meeting');
      expect(event.slots.length, 3);
      expect(event.availability.length, 2);
      expect(event.creator!.name, 'Alice');
    });

    test('dates extracts unique date prefixes', () {
      final event = W2MEvent(
        id: 'ev2',
        title: '',
        slots: ['2024-07-01 09:00', '2024-07-01 09:30', '2024-07-02 10:00'],
        availability: [],
      );
      expect(event.dates, ['2024-07-01', '2024-07-02']);
    });

    test('slotCount counts users available for a slot', () {
      final event = W2MEvent(
        id: 'ev3',
        title: '',
        slots: ['2024-07-01 09:00'],
        availability: [
          W2MUserAvailability(
            user: W2MUserInfo(id: 'u1', name: 'A'),
            slots: ['2024-07-01 09:00'],
          ),
          W2MUserAvailability(
            user: W2MUserInfo(id: 'u2', name: 'B'),
            slots: ['2024-07-01 09:00'],
          ),
          W2MUserAvailability(
            user: W2MUserInfo(id: 'u3', name: 'C'),
            slots: ['2024-07-01 10:00'],
          ),
        ],
      );
      expect(event.slotCount('2024-07-01 09:00'), 2);
      expect(event.slotCount('2024-07-01 10:00'), 1);
      expect(event.slotCount('2024-07-01 11:00'), 0);
    });

    test('usersAvailable returns matching users', () {
      final event = W2MEvent(
        id: 'ev4',
        title: '',
        slots: ['slot1'],
        availability: [
          W2MUserAvailability(
            user: W2MUserInfo(id: 'u1', name: 'A'),
            slots: ['slot1'],
          ),
          W2MUserAvailability(
            user: W2MUserInfo(id: 'u2', name: 'B'),
            slots: ['slot2'],
          ),
        ],
      );
      final available = event.usersAvailable('slot1');
      expect(available.length, 1);
      expect(available[0].user.id, 'u1');
    });

    test('maxCount returns highest slot count or 1 if zero', () {
      final emptyEvent = W2MEvent(
        id: 'ev5',
        title: '',
        slots: ['s1'],
        availability: [],
      );
      expect(emptyEvent.maxCount, 1);

      final event = W2MEvent(
        id: 'ev6',
        title: '',
        slots: ['s1', 's2'],
        availability: [
          W2MUserAvailability(
            user: W2MUserInfo(id: 'u1', name: 'A'),
            slots: ['s1', 's2'],
          ),
          W2MUserAvailability(
            user: W2MUserInfo(id: 'u2', name: 'B'),
            slots: ['s1'],
          ),
        ],
      );
      expect(event.maxCount, 2);
    });

    test('fromJson with null creator', () {
      final json = {
        'id': 'ev7',
        'title': '',
        'slots': [],
        'availability': [],
      };
      final event = W2MEvent.fromJson(json);
      expect(event.creator, isNull);
    });
  });

  group('W2MUserAvailability', () {
    test('fromJson parses fields', () {
      final json = {
        'user': {'id': 'u1', 'name': 'Alice'},
        'slots': ['s1', 's2'],
      };
      final avail = W2MUserAvailability.fromJson(json);
      expect(avail.user.name, 'Alice');
      expect(avail.slots, ['s1', 's2']);
    });
  });

  group('W2MSlot', () {
    test('label concatenates date and time', () {
      const slot = W2MSlot(dateString: '2024-07-01', timeString: '09:00');
      expect(slot.label, '2024-07-01 09:00');
    });

    test('equality and hashCode', () {
      const a = W2MSlot(dateString: '2024-07-01', timeString: '09:00');
      const b = W2MSlot(dateString: '2024-07-01', timeString: '09:00');
      const c = W2MSlot(dateString: '2024-07-01', timeString: '10:00');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('w2mDisplayTimes', () {
    test('generates times from 06:00 to 23:30', () {
      final times = w2mDisplayTimes();
      expect(times.first, '06:00');
      expect(times.last, '23:30');
      expect(times.length, 36);
      expect(times.contains('12:00'), true);
      expect(times.contains('12:30'), true);
    });
  });

  group('w2mShortDate', () {
    test('formats valid date string', () {
      final result = w2mShortDate('2024-07-01');
      expect(result, contains('7/1'));
      expect(result, contains('(一)'));
    });

    test('returns original string for invalid date', () {
      expect(w2mShortDate('not-a-date'), 'not-a-date');
    });

    test('formats Sunday correctly', () {
      final result = w2mShortDate('2024-06-30');
      expect(result, contains('6/30'));
      expect(result, contains('(日)'));
    });

    test('formats Saturday correctly', () {
      final result = w2mShortDate('2024-06-29');
      expect(result, contains('6/29'));
      expect(result, contains('(六)'));
    });
  });
}

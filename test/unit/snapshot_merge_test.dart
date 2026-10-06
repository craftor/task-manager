import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/data/sync/snapshot.dart';
import 'package:task_manager/data/sync/snapshot_codec.dart';

void main() {
  group('SnapshotCodec.merge — row-based collections', () {
    test('last-write-wins on updated_at', () {
      final local = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        projects: [
          {
            'id': 'p1',
            'name': 'Local newer',
            'updated_at': 2000,
          },
        ],
      );
      final remote = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        projects: [
          {
            'id': 'p1',
            'name': 'Remote older',
            'updated_at': 1000,
          },
        ],
      );
      final merged = SnapshotCodec.merge(local, remote);
      expect(merged.projects, hasLength(1));
      expect(merged.projects.single['name'], 'Local newer');
    });

    test('newer remote beats older local', () {
      final local = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        projects: [
          {'id': 'p1', 'name': 'Local older', 'updated_at': 1000},
        ],
      );
      final remote = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        projects: [
          {'id': 'p1', 'name': 'Remote newer', 'updated_at': 2000},
        ],
      );
      final merged = SnapshotCodec.merge(local, remote);
      expect(merged.projects.single['name'], 'Remote newer');
    });

    test('rows present on only one side are kept', () {
      final local = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        projects: [
          {'id': 'p1', 'name': 'Only local', 'updated_at': 1000},
        ],
      );
      final remote = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        projects: [
          {'id': 'p2', 'name': 'Only remote', 'updated_at': 1000},
        ],
      );
      final merged = SnapshotCodec.merge(local, remote);
      expect(merged.projects, hasLength(2));
      final names = merged.projects.map((m) => m['name']).toSet();
      expect(names, {'Only local', 'Only remote'});
    });

    test('tombstone wins even when local row is newer', () {
      final local = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        projects: [
          {
            'id': 'p1',
            'name': 'Local edited',
            'updated_at': 5000,
          },
        ],
      );
      final remote = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        projects: [
          {
            'id': 'p1',
            'name': 'To delete',
            'updated_at': 1000,
            'deleted_at': '2026-01-01T00:00:00.000Z',
          },
        ],
      );
      final merged = SnapshotCodec.merge(local, remote);
      expect(merged.projects, hasLength(1));
      expect(merged.projects.single['deleted_at'], isNotNull);
    });

    test('local tombstone is preserved if remote has live row', () {
      final local = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        projects: [
          {
            'id': 'p1',
            'name': 'To delete locally',
            'updated_at': 5000,
            'deleted_at': '2026-01-02T00:00:00.000Z',
          },
        ],
      );
      final remote = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        projects: [
          {'id': 'p1', 'name': 'Live remote', 'updated_at': 1000},
        ],
      );
      final merged = SnapshotCodec.merge(local, remote);
      expect(merged.projects.single['deleted_at'], isNotNull);
    });
  });

  group('SnapshotCodec.merge — cache-based stores', () {
    test('moods: present on both sides → keep newer; tie → local', () {
      final t = DateTime.utc(2026, 1, 1).toIso8601String();
      final local = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        moods: {
          '2026-01-01': ['😊'],
          '2026-01-02': ['😢'],
        },
      );
      final remote = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        moods: {
          '2026-01-02': ['😡'], // would conflict on local side
          '2026-01-03': ['🎉'], // only on remote
        },
      );
      final merged = SnapshotCodec.merge(local, remote);
      // mood entries don't carry a timestamp — local wins on conflict.
      expect(merged.moods['2026-01-01'], ['😊']);
      expect(merged.moods['2026-01-02'], ['😢']);
      expect(merged.moods['2026-01-03'], ['🎉']);
      expect(merged.moods.length, 3);
      // Mark `t` as used to silence the unused-local-variable lint.
      expect(t, isNotEmpty);
    });

    test('journal: only on one side → keep it', () {
      final local = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        journal: {
          '2026-01-01': [
            {'id': 'j1', 'created_at': '2026-01-01T08:00:00.000Z', 'content': 'hello'},
          ],
        },
      );
      final remote = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 1),
        journal: {
          '2026-01-02': [
            {'id': 'j2', 'created_at': '2026-01-02T08:00:00.000Z', 'content': 'world'},
          ],
        },
      );
      final merged = SnapshotCodec.merge(local, remote);
      expect(merged.journal.keys, {'2026-01-01', '2026-01-02'});
      expect(merged.journal['2026-01-01']!.single['content'], 'hello');
      expect(merged.journal['2026-01-02']!.single['content'], 'world');
    });
  });

  group('SnapshotCodec.encodeToJson + decodeFromJson', () {
    test('round-trips a non-trivial snapshot', () {
      final snap = SyncSnapshot(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 5, 1, 12),
        projects: [
          {
            'id': 'p1',
            'name': 'Demo',
            'updated_at': 1700000000000,
          },
        ],
        tasks: [
          {
            'id': 't1',
            'project_id': 'p1',
            'title': 'Write tests',
            'tags': ['test'],
            'updated_at': 1700000000000,
          },
        ],
        timeEntries: [
          {
            'id': 'e1',
            'task_id': 't1',
            'start_time': '2026-05-01T08:00:00.000Z',
            'note': 'morning',
            'updated_at': 1700000000000,
          },
        ],
        journal: {
          '2026-05-01': [
            {'id': 'j1', 'created_at': '2026-05-01T09:00:00.000Z', 'content': 'a'},
          ],
        },
        moods: {'2026-05-01': ['😊']},
        specialDays: {'2026-05-01': {'color': '0', 'desc': 'anniversary'}},
      );

      final json = SnapshotCodec.encodeToJson(snap);
      final restored = SnapshotCodec.decodeFromJson(json);

      expect(restored.schemaVersion, snap.schemaVersion);
      expect(restored.projects, snap.projects);
      expect(restored.tasks, snap.tasks);
      expect(restored.timeEntries, snap.timeEntries);
      expect(restored.journal, snap.journal);
      expect(restored.moods, snap.moods);
      expect(restored.specialDays, snap.specialDays);
    });

    test('decode rejects future schema versions', () {
      const futureJson = '{"schema_version": 999}';
      expect(
        () => SnapshotCodec.decodeFromJson(futureJson),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

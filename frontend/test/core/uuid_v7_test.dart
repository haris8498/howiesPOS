import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('UUID v7 Verification Tests (§4.2)', () {
    const uuid = Uuid();

    test('generates valid RFC 9562 UUID v7 format', () {
      final id = uuid.v7();
      expect(id.length, equals(36));

      // Standard UUID format: 8-4-4-4-12
      final regex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(regex.hasMatch(id), isTrue, reason: 'UUID v7 must match RFC 9562 structure with version nibble 7');
    });

    test('UUID v7 generation is monotonically increasing over time', () async {
      final ids = <String>[];
      for (int i = 0; i < 20; i++) {
        ids.add(uuid.v7());
        await Future.delayed(const Duration(milliseconds: 2));
      }

      // Verify lexicographical ordering (time locality)
      for (int i = 0; i < ids.length - 1; i++) {
        expect(ids[i].compareTo(ids[i + 1]), lessThan(0),
            reason: 'Sequential UUID v7 instances must be strictly monotonically ordered');
      }
    });

    test('generates unique identifiers across rapid loop iterations', () {
      final set = <String>{};
      for (int i = 0; i < 1000; i++) {
        final id = uuid.v7();
        expect(set.add(id), isTrue, reason: 'UUID v7 should never collide even in rapid loops');
      }
      expect(set.length, equals(1000));
    });
  });
}

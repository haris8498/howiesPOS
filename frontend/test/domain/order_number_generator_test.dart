import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/domain/services/order_number_generator.dart';

void main() {
  group('OrderNumberGenerator Tests (§4.2, §4.3)', () {
    test('generateUniqueId returns valid RFC 9562 UUID v7', () {
      final generator = OrderNumberGenerator();
      final id = generator.generateUniqueId();

      expect(id.length, equals(36));
      final uuidV7Regex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(uuidV7Regex.hasMatch(id), isTrue,
          reason: 'Generated ID must be a standard RFC 9562 UUID v7');
    });

    test('generateOrderNumber generates P<terminal>-<seq> starting at 101', () {
      final generator = OrderNumberGenerator(terminalId: '1');
      final num1 = generator.generateOrderNumber();
      final num2 = generator.generateOrderNumber();
      final num3 = generator.generateOrderNumber();

      expect(num1, equals('P1-101'));
      expect(num2, equals('P1-102'));
      expect(num3, equals('P1-103'));
    });

    test('custom terminal prefixes partition the namespace (P2-101)', () {
      final genTerminal2 = OrderNumberGenerator(terminalId: '2');
      expect(genTerminal2.generateOrderNumber(), equals('P2-101'));
    });

    test('generateOrderNumber cycles back to 101 when exceeding 999', () {
      final generator = OrderNumberGenerator(terminalId: '1', initialSequence: 998);
      expect(generator.generateOrderNumber(), equals('P1-999'));
      expect(generator.generateOrderNumber(), equals('P1-101'),
          reason: 'Sequence should roll over to 101 after 999');
      expect(generator.generateOrderNumber(), equals('P1-102'));
    });

    test('generateTakeawayToken outputs TK-seq format', () {
      final generator = OrderNumberGenerator();
      generator.generateOrderNumber(); // 101
      expect(generator.generateTakeawayToken(), equals('TK-101'));
      expect(generator.generateTakeawayToken(currentCounter: 250), equals('TK-250'));
    });

    test('nextAtomicReceiptNumber increments Drift TerminalSequences table atomically', () async {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        final generator = OrderNumberGenerator(
          terminalId: '1',
          terminalSequencesDao: db.terminalSequencesDao,
        );

        final today = DateTime(2026, 10, 17);
        final r1 = await generator.nextAtomicReceiptNumber(date: today);
        final r2 = await generator.nextAtomicReceiptNumber(date: today);
        final r3 = await generator.nextAtomicReceiptNumber(date: today);

        expect(r1, equals('P1-101'));
        expect(r2, equals('P1-102'));
        expect(r3, equals('P1-103'));

        // Verify stored in Drift database table
        final record = await db.terminalSequencesDao.getSequenceRecord('ORDER_NUMBER');
        expect(record, isNotNull);
        expect(record!.currentValue, equals(103));
        expect(record.businessDate, equals('2026-10-17'));

        // Next business date resets sequence to 101
        final tomorrow = DateTime(2026, 10, 18);
        final rTomorrow = await generator.nextAtomicReceiptNumber(date: tomorrow);
        expect(rTomorrow, equals('P1-101'));

        final recordTomorrow = await db.terminalSequencesDao.getSequenceRecord('ORDER_NUMBER');
        expect(recordTomorrow!.currentValue, equals(101));
        expect(recordTomorrow.businessDate, equals('2026-10-18'));
      } finally {
        await db.close();
      }
    });

    test('SYNC-009: useLegacyFormat generates HH-yyMMdd-seq without terminal prefix', () {
      final gen = OrderNumberGenerator(useLegacyFormat: true, initialSequence: 1000);
      final num1 = gen.generateOrderNumber();
      final num2 = gen.generateOrderNumber();

      expect(num1, matches(RegExp(r'^HH-\d{6}-1001$')));
      expect(num2, matches(RegExp(r'^HH-\d{6}-1002$')));
    });
  });
}

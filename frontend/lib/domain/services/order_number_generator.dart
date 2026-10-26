import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/daos/terminal_sequences_dao.dart';

/// Abstract Contract for Order and Token numbering
abstract class IOrderNumberGenerator {
  /// Generates a unique, chronological order number (e.g. P1-101) per Spec §4.3
  String generateOrderNumber();

  /// Generates a takeaway token sequence string (e.g. TK-101)
  String generateTakeawayToken({int? currentCounter});

  /// Generates an RFC 9562 UUID v7 identifier per Spec §4.2
  String generateUniqueId();
}

/// Order Number Generator per Architecture Spec §4.2 and §4.3.
///
/// Features:
/// 1. Entity Identity: RFC 9562 UUID v7 generated via `uuid` package.
///    Timestamp prefix guarantees monotonic ordering in PostgreSQL B-trees.
/// 2. Receipt Sequencing: Terminal-prefixed receipt numbers `P{terminal}-{seq}`
///    (e.g., P1-101). The counter cycles from 101 to 999 and resets daily.
/// 3. Atomic Sequence Support: Can allocate sequences atomically inside a Drift
///    database transaction using `TerminalSequencesDao`.
class OrderNumberGenerator implements IOrderNumberGenerator {
  final String terminalId;
  final TerminalSequencesDao? _terminalSequencesDao;
  final Uuid _uuid;
  final bool useLegacyFormat;

  int _currentSequence = 100;
  String? _lastBusinessDate;

  OrderNumberGenerator({
    this.terminalId = '1',
    TerminalSequencesDao? terminalSequencesDao,
    int initialSequence = 100,
    String? businessDate,
    Uuid? uuid,
    this.useLegacyFormat = false,
  })  : _terminalSequencesDao = terminalSequencesDao,
        _currentSequence = (useLegacyFormat && initialSequence == 100)
            ? (((DateTime.now().millisecondsSinceEpoch ~/ 1000) % 9000) + 1000)
            : initialSequence,
        _lastBusinessDate = businessDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
        _uuid = uuid ?? const Uuid();

  /// Generates an RFC 9562 UUID v7 identifier per Spec §4.2.
  @override
  String generateUniqueId() {
    return _uuid.v7();
  }

  /// Generates a terminal-prefixed receipt number (e.g. P1-101) per Spec §4.3,
  /// or legacy pre-offline format 'HH-yyMMdd-seq' when useLegacyFormat is true (SYNC-009).
  @override
  String generateOrderNumber() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_lastBusinessDate != today) {
      _lastBusinessDate = today;
      _currentSequence = useLegacyFormat ? 1000 : 100;
    }
    _currentSequence++;
    if (!useLegacyFormat && _currentSequence > 999) {
      _currentSequence = 101;
    }
    if (useLegacyFormat) {
      final datePrefix = DateFormat('yyMMdd').format(DateTime.now());
      return 'HH-$datePrefix-$_currentSequence';
    }
    return formatReceiptNumber(terminalId, _currentSequence);
  }

  /// Formats receipt number string: `P{terminal}-{sequence}` e.g. P1-101
  static String formatReceiptNumber(String terminal, int sequence) {
    return 'P$terminal-$sequence';
  }

  /// Asynchronously generates next receipt sequence from Drift TerminalSequences table
  /// inside an atomic database transaction.
  Future<String> nextAtomicReceiptNumber({DateTime? date}) async {
    final today = DateFormat('yyyy-MM-dd').format(date ?? DateTime.now());
    final dao = _terminalSequencesDao;
    if (dao != null) {
      final seq = await dao.getNextSequence(
        'ORDER_NUMBER',
        today,
        start: 101,
        max: 999,
      );
      _currentSequence = seq;
      _lastBusinessDate = today;
      return formatReceiptNumber(terminalId, seq);
    }
    return generateOrderNumber();
  }

  /// Generates takeaway token sequence (e.g. TK-101)
  @override
  String generateTakeawayToken({int? currentCounter}) {
    final counter = currentCounter ?? (_currentSequence % 1000);
    return 'TK-$counter';
  }
}

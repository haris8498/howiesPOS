import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hungry_howies_pos/core/sync/sync_health_provider.dart';
import 'package:hungry_howies_pos/core/widgets/sync_status_indicator_widget.dart';

void main() {
  Widget buildTestableWidget({required SyncHealthState state}) {
    return ProviderScope(
      overrides: [
        rawSyncHealthProvider.overrideWithValue(state),
        syncHealthProvider.overrideWith((ref) => Stream.value(state)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SyncStatusIndicatorWidget(),
          ),
        ),
      ),
    );
  }

  group('SyncStatusIndicatorWidget tests', () {
    testWidgets('renders green idle state when synced', (WidgetTester tester) async {
      const idleState = SyncHealthState(
        status: SyncHealthStatus.green,
        isPulsing: false,
        pendingCount: 0,
        failedCount: 0,
        tooltipText: 'Synced',
        semanticsLabel: 'Sync status: Synced',
      );

      await tester.pumpWidget(buildTestableWidget(state: idleState));
      await tester.pumpAndSettle();

      // Verify tooltip and semantics
      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsOneWidget);
      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      expect(tooltip.message, contains('Synced'));

      final semanticsFinder = find.byType(Semantics);
      expect(semanticsFinder, findsWidgets);
      final semantics = tester.widget<Semantics>(
        find.ancestor(of: tooltipFinder, matching: find.byType(Semantics)).first,
      );
      expect(semantics.properties.label, 'Sync status: Synced');

      // Verify green dot container
      final greenContainerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == const Color(0xFF16A34A) && box.shape == BoxShape.circle;
        }
        return false;
      });
      expect(greenContainerFinder, findsOneWidget);

      // Verify no pending count badge when 0
      expect(find.text('0'), findsNothing);
    });

    testWidgets('renders green pulsing state with badge when syncing', (WidgetTester tester) async {
      const pulsingState = SyncHealthState(
        status: SyncHealthStatus.green,
        isPulsing: true,
        pendingCount: 3,
        failedCount: 0,
        tooltipText: 'Syncing - 3 pending',
        semanticsLabel: 'Sync status: Syncing with 3 pending items.',
      );

      await tester.pumpWidget(buildTestableWidget(state: pulsingState));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify tooltip
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('Syncing - 3 pending'));

      // Verify green dot
      final greenContainerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == const Color(0xFF16A34A) && box.shape == BoxShape.circle;
        }
        return false;
      });
      expect(greenContainerFinder, findsOneWidget);

      // Verify pending count badge text '3'
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('renders red state when offline with pending orders', (WidgetTester tester) async {
      const offlineState = SyncHealthState(
        status: SyncHealthStatus.red,
        isPulsing: false,
        pendingCount: 2,
        failedCount: 0,
        tooltipText: 'Offline - 2 saved locally',
        semanticsLabel: 'Sync status: Offline. 2 orders saved locally.',
      );

      await tester.pumpWidget(buildTestableWidget(state: offlineState));
      await tester.pumpAndSettle();

      // Verify tooltip
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('Offline - 2 saved locally'));

      // Verify red dot
      final redContainerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == const Color(0xFFDC2626) && box.shape == BoxShape.circle;
        }
        return false;
      });
      expect(redContainerFinder, findsOneWidget);

      // Verify pending count badge text '2'
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('renders red state when sync failed', (WidgetTester tester) async {
      const failedState = SyncHealthState(
        status: SyncHealthStatus.red,
        isPulsing: false,
        pendingCount: 1,
        failedCount: 1,
        tooltipText: 'Sync error - 1 failed',
        semanticsLabel: 'Sync status: Error with 1 failed items.',
      );

      await tester.pumpWidget(buildTestableWidget(state: failedState));
      await tester.pumpAndSettle();

      // Verify tooltip
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('Sync error - 1 failed'));

      // Verify red dot
      final redContainerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == const Color(0xFFDC2626) && box.shape == BoxShape.circle;
        }
        return false;
      });
      expect(redContainerFinder, findsOneWidget);

      // Verify badge text '1'
      expect(find.text('1'), findsOneWidget);
    });
  });
}

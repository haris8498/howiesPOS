import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/models/expense_model.dart';
import 'download/download_helper.dart';

class ExpenseExportService {
  /// 1. Export Expenses to Excel / CSV format (Exact 3 Columns: Expense Description, Date, Price)
  static Future<bool> exportToExcelCsv({
    required List<ExpenseRecord> expenses,
    DateTime? selectedDate,
  }) async {
    try {
      // Sort date-wise (oldest to newest)
      final sortedList = List<ExpenseRecord>.from(expenses)
        ..sort((a, b) => a.date.compareTo(b.date));

      final totalAmount = sortedList.fold<double>(0.0, (sum, e) => sum + e.amount);
      final dateStr = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());

      final csvBuffer = StringBuffer();

      // Excel UTF-8 BOM Header (ensures Excel opens Unicode without mojibake)
      final utf8Bom = [0xEF, 0xBB, 0xBF];

      // Exact 3 Column Headers: Expense Description, Date, Price
      csvBuffer.writeln('"Expense Description","Date","Price"');

      // Date-wise Data Rows
      for (final exp in sortedList) {
        final description = exp.title;
        final cleanDesc = description.replaceAll('"', '""');
        final dateCol = DateFormat('dd-MMM-yyyy').format(exp.date);
        final priceCol = exp.amount.toStringAsFixed(2);

        csvBuffer.writeln('"$cleanDesc","$dateCol",$priceCol');
      }

      // Summary Footer Row (Total)
      csvBuffer.writeln('"TOTAL","","${totalAmount.toStringAsFixed(2)}"');

      final rawBytes = utf8.encode(csvBuffer.toString());
      final fullBytes = [...utf8Bom, ...rawBytes];
      final filename = 'HungryHowies_Expenses_${selectedDate == null ? 'AllDates' : DateFormat('yyyyMMdd').format(selectedDate)}_$dateStr.csv';

      final saved = await downloadFileFromBytes(fullBytes, filename, 'text/csv;charset=utf-8');
      return saved;
    } catch (e) {
      debugPrint('Export to Excel CSV error: $e');
      return false;
    }
  }

  static String _safeText(String text) {
    if (text.isEmpty) return '';
    return text
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('•', '-')
        .replaceAll('…', '...')
        .replaceAll('PKR ', 'PKR')
        .replaceAll('PKR ', 'PKR ')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ');
  }

  /// 2. Export Expenses to PDF Grouped Date-wise (Date Heading -> Items & Expenses -> Next Date)
  static Future<bool> exportToPdf({
    required List<ExpenseRecord> expenses,
    DateTime? selectedDate,
  }) async {
    try {
      if (expenses.isEmpty) return false;

      final sortedList = List<ExpenseRecord>.from(expenses)
        ..sort((a, b) => a.date.compareTo(b.date));

      final totalAmount = sortedList.fold<double>(0.0, (sum, e) => sum + e.amount);
      final nowFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      final scopeText = selectedDate == null
          ? 'All Dates (Complete Financial History)'
          : DateFormat('dd MMM yyyy').format(selectedDate);

      // Group expenses by formatted Date String
      final Map<String, List<ExpenseRecord>> groupedByDate = {};
      for (final exp in sortedList) {
        final dateKey = DateFormat('EEEE, dd MMM yyyy').format(exp.date);
        groupedByDate.putIfAbsent(dateKey, () => []).add(exp);
      }

      // Safe Font Loading
      pw.ThemeData themeData = pw.ThemeData.base();
      try {
        final regularFont = await PdfGoogleFonts.robotoRegular().timeout(const Duration(seconds: 2));
        final boldFont = await PdfGoogleFonts.robotoBold().timeout(const Duration(seconds: 2));
        themeData = pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        );
      } catch (e) {
        debugPrint('Pdf font fallback: $e');
      }

      final pdf = pw.Document(theme: themeData);

      // Brand Colors for PDF
      const primaryRed = PdfColor.fromInt(0xFFD32F2F);
      const darkRed = PdfColor.fromInt(0xFF991B1B);
      const brandYellow = PdfColor.fromInt(0xFFFBBF24);
      const textDark = PdfColor.fromInt(0xFF1E293B);
      const textMuted = PdfColor.fromInt(0xFF64748B);
      const bgLight = PdfColor.fromInt(0xFFF8FAFC);
      const dateHeaderBg = PdfColor.fromInt(0xFFFEF2F2);
      const borderGray = PdfColor.fromInt(0xFFE2E8F0);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.portrait,
          margin: const pw.EdgeInsets.all(24),
          header: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: pw.BoxDecoration(
                color: primaryRed,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "HUNGRY HOWIES - EXPENSE REPORT",
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'DATE-WISE ITEMIZED EXPENDITURE BREAKDOWN',
                        style: const pw.TextStyle(
                          color: brandYellow,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated: ${_safeText(nowFormatted)}',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 8),
                      ),
                      pw.Text(
                        'Scope: ${_safeText(scopeText)}',
                        style: const pw.TextStyle(color: brandYellow, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              padding: const pw.EdgeInsets.only(top: 4),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: borderGray, width: 0.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Hungry Howie's POS - Confidential Financial Record",
                    style: const pw.TextStyle(color: textMuted, fontSize: 7.5),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(color: textMuted, fontSize: 7.5),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            final List<pw.Widget> widgets = [];

            // Top Summary Bar
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: bgLight,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderGray),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL DATES: ${groupedByDate.keys.length}',
                      style: pw.TextStyle(color: textDark, fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                    ),
                    pw.Text(
                      'TOTAL ENTRIES: ${sortedList.length}',
                      style: pw.TextStyle(color: textDark, fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                    ),
                    pw.Text(
                      'GRAND TOTAL: PKR ${totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(color: darkRed, fontWeight: pw.FontWeight.bold, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            );

            // Date-Wise Sections (Direct paginatable widgets)
            for (final entry in groupedByDate.entries) {
              final dateLabel = entry.key;
              final dayExpenses = entry.value;
              final daySubtotal = dayExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

              // Date Header Bar
              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 8),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: dateHeaderBg,
                    borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
                    border: pw.Border.all(color: borderGray),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'DATE: ${_safeText(dateLabel.toUpperCase())}',
                        style: pw.TextStyle(color: primaryRed, fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                      ),
                      pw.Text(
                        'Subtotal: PKR ${daySubtotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(color: darkRed, fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              );

              // Itemized Table (Direct child so it breaks across pages cleanly)
              widgets.add(
                pw.TableHelper.fromTextArray(
                  border: const pw.TableBorder(
                    left: pw.BorderSide(color: borderGray, width: 0.5),
                    right: pw.BorderSide(color: borderGray, width: 0.5),
                    bottom: pw.BorderSide(color: borderGray, width: 0.5),
                    horizontalInside: pw.BorderSide(color: borderGray, width: 0.5),
                  ),
                  headerStyle: pw.TextStyle(
                    color: textDark,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8.5,
                  ),
                  headerDecoration: const pw.BoxDecoration(color: bgLight),
                  headerHeight: 20,
                  cellHeight: 20,
                  cellStyle: const pw.TextStyle(color: textDark, fontSize: 8),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerRight,
                  },
                  headers: <String>[
                    'Expense Description',
                    'Time / Notes',
                    'Price (PKR)',
                  ],
                  data: dayExpenses.map((exp) {
                    final timeStr = DateFormat('hh:mm a').format(exp.date);
                    return [
                      _safeText(exp.title),
                      _safeText(timeStr),
                      'PKR ${exp.amount.toStringAsFixed(2)}',
                    ];
                  }).toList(),
                ),
              );

              widgets.add(pw.SizedBox(height: 6));
            }

            // Grand Total Footer Box
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 8),
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: bgLight,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: primaryRed, width: 1.2),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'GRAND TOTAL EXPENDITURE:',
                      style: pw.TextStyle(color: textDark, fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                    pw.Text(
                      'PKR ${totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(color: darkRed, fontWeight: pw.FontWeight.bold, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            );

            return widgets;
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final filename = 'HungryHowies_Expenses_${selectedDate == null ? 'AllDates' : DateFormat('yyyyMMdd').format(selectedDate)}.pdf';

      final saved = await downloadFileFromBytes(pdfBytes, filename, 'application/pdf');
      return saved;
    } catch (e, stack) {
      debugPrint('Export to PDF error: $e\n$stack');
      return false;
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'download/download_helper.dart';

class ReportExportItem {
  final String productName;
  final String category;
  final double unitPrice;
  final int unitsSold;
  final double totalRevenue;

  const ReportExportItem({
    required this.productName,
    required this.category,
    required this.unitPrice,
    required this.unitsSold,
    required this.totalRevenue,
  });
}

class ReportExportService {
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

  /// 1. Export Sales & Product Report to Excel (.CSV)
  static Future<bool> exportToExcelCsv({
    required List<ReportExportItem> items,
    required String periodFilter,
    required String categoryFilter,
    required String productFilter,
    double? grossSubtotal,
    double? totalDiscount,
    double? totalTax,
  }) async {
    try {
      if (items.isEmpty) return false;

      final totalRevenue = items.fold<double>(0.0, (sum, i) => sum + i.totalRevenue);
      final totalUnits = items.fold<int>(0, (sum, i) => sum + i.unitsSold);
      final dateStr = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());

      final csvBuffer = StringBuffer();
      final utf8Bom = [0xEF, 0xBB, 0xBF];

      // Headers
      csvBuffer.writeln('"Product Name","Category","Unit Price (PKR)","Units Sold","Total Revenue (PKR)"');

      // Data Rows
      for (final item in items) {
        final cleanName = item.productName.replaceAll('"', '""');
        final cleanCategory = item.category.replaceAll('"', '""');
        final unitPrice = item.unitPrice.toStringAsFixed(2);
        final units = item.unitsSold.toString();
        final revenue = item.totalRevenue.toStringAsFixed(2);

        csvBuffer.writeln('"$cleanName","$cleanCategory",$unitPrice,$units,$revenue');
      }

      // Summary Footer Rows
      csvBuffer.writeln('"TOTAL UNITS / PRODUCTS","","",$totalUnits,"${totalRevenue.toStringAsFixed(2)}"');
      if (grossSubtotal != null && grossSubtotal > 0) {
        csvBuffer.writeln('"GROSS SUBTOTAL (PKR)","","","","${grossSubtotal.toStringAsFixed(2)}"');
      }
      if (totalDiscount != null && totalDiscount > 0) {
        csvBuffer.writeln('"TOTAL DISCOUNT (PKR)","","","","-${totalDiscount.toStringAsFixed(2)}"');
      }
      if (totalTax != null && totalTax > 0) {
        csvBuffer.writeln('"TAX COLLECTED (PKR)","","","","+${totalTax.toStringAsFixed(2)}"');
      }
      csvBuffer.writeln('"NET SALES REVENUE (PKR)","","","","${totalRevenue.toStringAsFixed(2)}"');

      final rawBytes = utf8.encode(csvBuffer.toString());
      final fullBytes = [...utf8Bom, ...rawBytes];
      final safePeriod = periodFilter.replaceAll(' ', '_');
      final filename = 'HungryHowies_SalesReport_${safePeriod}_$dateStr.csv';

      final saved = await downloadFileFromBytes(fullBytes, filename, 'text/csv;charset=utf-8');
      return saved;
    } catch (e) {
      debugPrint('Export Sales Excel error: $e');
      return false;
    }
  }

  /// 2. Export Sales & Product Report to PDF
  static Future<bool> exportToPdf({
    required List<ReportExportItem> items,
    required String periodFilter,
    required String categoryFilter,
    required String productFilter,
    double? grossSubtotal,
    double? totalDiscount,
    double? totalTax,
  }) async {
    try {
      if (items.isEmpty) return false;

      final totalRevenue = items.fold<double>(0.0, (sum, i) => sum + i.totalRevenue);
      final totalUnits = items.fold<int>(0, (sum, i) => sum + i.unitsSold);
      final nowFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

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

      const primaryRed = PdfColor.fromInt(0xFFD32F2F);
      const darkRed = PdfColor.fromInt(0xFF991B1B);
      const brandYellow = PdfColor.fromInt(0xFFFBBF24);
      const textDark = PdfColor.fromInt(0xFF1E293B);
      const textMuted = PdfColor.fromInt(0xFF64748B);
      const bgLight = PdfColor.fromInt(0xFFF8FAFC);
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
                        "HUNGRY HOWIES - SALES REPORT",
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'EXECUTIVE SALES & PRODUCT PERFORMANCE AUDIT',
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
                        'Period: ${_safeText(periodFilter)}',
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
                    "Hungry Howie's POS - Confidential Sales Audit Record",
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

            // Top KPI Summary Cards
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: bgLight,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderGray),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('GROSS SUBTOTAL', style: const pw.TextStyle(color: textMuted, fontSize: 7)),
                        pw.Text('PKR ${(grossSubtotal != null && grossSubtotal > 0 ? grossSubtotal : totalRevenue).toStringAsFixed(2)}', style: pw.TextStyle(color: textDark, fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                      ],
                    ),
                    if (totalDiscount != null && totalDiscount > 0) ...[
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TOTAL DISCOUNT', style: const pw.TextStyle(color: textMuted, fontSize: 7)),
                          pw.Text('-PKR ${totalDiscount.toStringAsFixed(2)}', style: pw.TextStyle(color: primaryRed, fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        ],
                      ),
                    ],
                    if (totalTax != null && totalTax > 0) ...[
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TAX COLLECTED', style: const pw.TextStyle(color: textMuted, fontSize: 7)),
                          pw.Text('+PKR ${totalTax.toStringAsFixed(2)}', style: pw.TextStyle(color: textDark, fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        ],
                      ),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('NET REVENUE', style: const pw.TextStyle(color: textMuted, fontSize: 7)),
                        pw.Text('PKR ${totalRevenue.toStringAsFixed(2)}', style: pw.TextStyle(color: darkRed, fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('UNITS SOLD', style: const pw.TextStyle(color: textMuted, fontSize: 7)),
                        pw.Text('$totalUnits Units', style: pw.TextStyle(color: textDark, fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                      ],
                    ),
                  ],
                ),
              ),
            );

            // Itemized Product Table
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
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
                headers: <String>[
                  'Product Name',
                  'Category',
                  'Unit Price (PKR)',
                  'Units Sold',
                  'Total Revenue (PKR)',
                ],
                data: items.map((item) {
                  return [
                    _safeText(item.productName),
                    _safeText(item.category),
                    'PKR ${item.unitPrice.toStringAsFixed(0)}',
                    '${item.unitsSold}',
                    'PKR ${item.totalRevenue.toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
            );

            // Grand Total Footer Box
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 10),
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
                      'TOTAL SALES REVENUE ($periodFilter):',
                      style: pw.TextStyle(color: textDark, fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                    pw.Text(
                      'PKR ${totalRevenue.toStringAsFixed(2)}',
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
      final safePeriod = periodFilter.replaceAll(' ', '_');
      final filename = 'HungryHowies_SalesReport_$safePeriod.pdf';

      final saved = await downloadFileFromBytes(pdfBytes, filename, 'application/pdf');
      return saved;
    } catch (e, stack) {
      debugPrint('Export Sales PDF error: $e\n$stack');
      return false;
    }
  }
}

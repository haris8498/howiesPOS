import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../receipt_printer_service.dart';

enum EscPosAlign { left, center, right }

enum EscPosFontSize {
  normal,
  bold,
  doubleHeight,
  doubleWidth,
  doubleBoth,
}

class EscPosColumn {
  final String text;
  final int width;
  final EscPosAlign align;
  final bool isBold;

  const EscPosColumn({
    required this.text,
    required this.width,
    this.align = EscPosAlign.left,
    this.isBold = false,
  });
}

/// Pure Dart ESC/POS Command & Byte Stream Generator
/// Generates thermal-optimized binary commands for POS receipt printers.
class EscPosBuilder {
  final BytesBuilder _buffer = BytesBuilder();
  final int lineWidth; // 48 chars for 80mm, 32 chars for 58mm

  EscPosBuilder({this.lineWidth = 48});

  static const List<int> cmdInit = [0x1B, 0x40]; // ESC @
  static const List<int> cmdCodePage = [0x1B, 0x74, 0x00]; // ESC t 0 (CP437)
  static const List<int> cmdFontA = [0x1B, 0x4D, 0x00]; // ESC M 0 (Font A 12x24 Sans-Serif)
  static const List<int> cmdCutPartial = [0x1D, 0x56, 0x42, 0x00]; // GS V B 0
  static const List<int> cmdCutFull = [0x1D, 0x56, 0x00]; // GS V 0
  static const List<int> cmdDrawerKick = [0x1B, 0x70, 0x00, 0x19, 0xFA]; // ESC p 0 25 250

  void reset() {
    _buffer.clear();
  }

  void initialize() {
    _buffer.add(cmdInit);
    _buffer.add(cmdCodePage);
    _buffer.add(cmdFontA); // Font A (Arial / Helvetica-style thermal sans-serif)
  }

  void setAlign(EscPosAlign align) {
    switch (align) {
      case EscPosAlign.left:
        _buffer.add([0x1B, 0x61, 0x00]); // ESC a 0
        break;
      case EscPosAlign.center:
        _buffer.add([0x1B, 0x61, 0x01]); // ESC a 1
        break;
      case EscPosAlign.right:
        _buffer.add([0x1B, 0x61, 0x02]); // ESC a 2
        break;
    }
  }

  void setStyle({
    bool bold = false,
    bool doubleHeight = false,
    bool doubleWidth = false,
    bool underline = false,
    bool invert = false,
  }) {
    int mode = 0;
    if (bold) mode |= 0x08;
    if (doubleHeight) mode |= 0x10;
    if (doubleWidth) mode |= 0x20;
    if (underline) mode |= 0x80;

    _buffer.add([0x1B, 0x21, mode]); // ESC ! n
    _buffer.add([0x1D, 0x42, invert ? 0x01 : 0x00]); // GS B n (Invert)
  }

  void setBold(bool enable) {
    _buffer.add([0x1B, 0x45, enable ? 0x01 : 0x00]); // ESC E n
  }

  void setLeftMargin(int dots) {
    final nL = dots & 0xFF;
    final nH = (dots >> 8) & 0xFF;
    _buffer.add([0x1D, 0x4C, nL, nH]); // GS L nL nH (Set left margin in dots)
  }

  void setPrintAreaWidth(int dots) {
    final nL = dots & 0xFF;
    final nH = (dots >> 8) & 0xFF;
    _buffer.add([0x1D, 0x57, nL, nH]); // GS W nL nH (Set printable area width)
  }

  void writeRawText(String text) {
    final clean = _sanitize(text);
    _buffer.add(latin1.encode(clean));
  }

  void writeLine(
    String text, {
    EscPosAlign align = EscPosAlign.left,
    EscPosFontSize size = EscPosFontSize.normal,
    bool invert = false,
  }) {
    setAlign(align);
    switch (size) {
      case EscPosFontSize.normal:
        setStyle(invert: invert);
        break;
      case EscPosFontSize.bold:
        setStyle(bold: true, invert: invert);
        break;
      case EscPosFontSize.doubleHeight:
        setStyle(bold: true, doubleHeight: true, invert: invert);
        break;
      case EscPosFontSize.doubleWidth:
        setStyle(bold: true, doubleWidth: true, invert: invert);
        break;
      case EscPosFontSize.doubleBoth:
        setStyle(bold: true, doubleHeight: true, doubleWidth: true, invert: invert);
        break;
    }

    writeRawText('$text\n');
    setStyle(); // Reset to normal Font A
  }

  void divider({String char = '-', bool doubleLine = false}) {
    final fillChar = doubleLine ? '=' : char;
    final line = fillChar * lineWidth;
    writeLine(line, align: EscPosAlign.center);
  }

  void keyValue(
    String key,
    String value, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    final k = _sanitize(key);
    final v = _sanitize(value);
    final spaces = lineWidth - k.length - v.length;

    setAlign(EscPosAlign.left);
    if (isLarge) {
      setStyle(bold: true, doubleHeight: true);
    } else if (isBold) {
      setStyle(bold: true);
    } else {
      setStyle();
    }

    if (spaces > 0) {
      writeRawText('$k${' ' * spaces}$v\n');
    } else {
      writeRawText('$k $v\n');
    }
    setStyle();
  }

  void row(List<EscPosColumn> cols, {bool isLarge = false}) {
    setAlign(EscPosAlign.left);
    if (isLarge) {
      setStyle(doubleHeight: true);
    } else {
      setStyle();
    }

    for (final col in cols) {
      final text = _sanitize(col.text);
      String colContent = '';
      if (text.length > col.width) {
        colContent = text.substring(0, col.width);
      } else {
        final padding = col.width - text.length;
        if (col.align == EscPosAlign.left) {
          colContent = '$text${' ' * padding}';
        } else if (col.align == EscPosAlign.right) {
          colContent = '${' ' * padding}$text';
        } else {
          final leftPad = padding ~/ 2;
          final rightPad = padding - leftPad;
          colContent = '${' ' * leftPad}$text${' ' * rightPad}';
        }
      }

      if (col.isBold) {
        _buffer.add([0x1B, 0x45, 0x01]); // ESC E 1 (Emphasize / Bold ON)
        writeRawText(colContent);
        _buffer.add([0x1B, 0x45, 0x00]); // ESC E 0 (Emphasize / Bold OFF)
      } else {
        writeRawText(colContent);
      }
    }

    writeRawText('\n');
    setStyle();
  }

  void feed([int lines = 1]) {
    for (int i = 0; i < lines; i++) {
      _buffer.add([0x0A]);
    }
  }

  void cut({bool fullCut = false}) {
    feed(1);
    _buffer.add(fullCut ? cmdCutFull : cmdCutPartial);
  }

  void kickCashDrawer() {
    _buffer.add(cmdDrawerKick);
  }

  Uint8List getBytes() {
    return _buffer.toBytes();
  }

  static String _sanitize(String input) {
    if (input.isEmpty) return '';
    return input
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('•', '-')
        .replaceAll('…', '...')
        .replaceAll('×', 'x')
        .replaceAll(RegExp(r'[^\x20-\x7E\n]'), ' ');
  }

  // ---------------------------------------------------------------------------
  // Complete Receipt ESC/POS Byte Generator
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // Complete Receipt ESC/POS Byte Generator (Clean Minimalist Invoice)
  // ---------------------------------------------------------------------------
  static Uint8List buildReceiptBytes({
    required ReceiptData receipt,
    PaperWidth paperWidth = PaperWidth.roll80mm,
    bool autoCut = true,
    bool openCashDrawer = false,
    bool isKitchenPrinter = false,
  }) {
    if (receipt.type == ReceiptType.kitchenKot) {
      return _buildKitchenKotBytes(
        receipt: receipt,
        paperWidth: paperWidth,
        autoCut: autoCut,
        isKitchenPrinter: isKitchenPrinter,
      );
    }

    final bool is58 = paperWidth == PaperWidth.roll58mm;
    final int width = is58 ? 30 : 42;
    final builder = EscPosBuilder(lineWidth: width);

    builder.initialize();

    // Set Left Margin (Side Margin) so receipt has spacious, elegant borders
    builder.setLeftMargin(is58 ? 16 : 36);

    if (openCashDrawer && receipt.type == ReceiptType.customerReceipt) {
      builder.kickCashDrawer();
    }

    // 1. BRAND HEADER: INVOICE / HUNGRY HOWIES / ADDRESS
    builder.writeLine('INVOICE', align: EscPosAlign.center, size: EscPosFontSize.normal);
    builder.writeLine(receipt.storeName.toUpperCase(), align: EscPosAlign.center, size: EscPosFontSize.bold);

    final address = receipt.branchName.isNotEmpty
        ? receipt.branchName
        : 'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.';
    builder.writeLine(address, align: EscPosAlign.center, size: EscPosFontSize.normal);

    if (receipt.storePhone.isNotEmpty && receipt.storePhone != '+1 (800) 555-HOWIE') {
      builder.writeLine('Tel: ${receipt.storePhone}', align: EscPosAlign.center, size: EscPosFontSize.normal);
    }

    // 2. METADATA: Receipt # and Date
    final displayOrderNum = format3DigitOrderNumber(receipt.orderNumber);
    final dateStr = DateFormat('dd-MMM-yyyy hh:mm:ss a').format(receipt.dateTime);
    builder.writeLine('Receipt #: $displayOrderNum', align: EscPosAlign.left);
    builder.writeLine('Date: $dateStr', align: EscPosAlign.left);

    if (receipt.tableNumber != null && receipt.tableNumber!.isNotEmpty) {
      builder.writeLine('Table: ${receipt.tableName ?? receipt.tableNumber}', align: EscPosAlign.left);
    }

    // 3. TABLE HEADER: Sr.  Product  Price  Qty  Total
    builder.divider();
    final srWidth = is58 ? 3 : 3;
    final prodWidth = is58 ? 11 : 18;
    final priceWidth = is58 ? 5 : 7;
    final qtyWidth = is58 ? 5 : 6;
    final totalWidth = width - srWidth - prodWidth - priceWidth - qtyWidth;

    builder.row([
      EscPosColumn(text: 'Sr.', width: srWidth, align: EscPosAlign.left, isBold: true),
      EscPosColumn(text: 'Product', width: prodWidth, align: EscPosAlign.left, isBold: true),
      EscPosColumn(text: 'Price', width: priceWidth, align: EscPosAlign.right, isBold: true),
      EscPosColumn(text: 'Qty', width: qtyWidth, align: EscPosAlign.right, isBold: true),
      EscPosColumn(text: 'Total', width: totalWidth, align: EscPosAlign.right, isBold: true),
    ]);
    builder.divider();

    // 4. ITEM ROWS (Only active, non-cancelled items are shown on the customer invoice)
    final activeItems = receipt.items.where((i) => !i.isCancelled).toList();
    double calculatedGrossActive = 0.0;
    double calculatedTotalQtyActive = 0.0;

    for (int i = 0; i < activeItems.length; i++) {
      final item = activeItems[i];
      final srNo = '${i + 1}';
      final priceStr = item.unitPrice.round().toString();
      final qtyStr = item.quantity.toString();
      final totalStr = item.totalPrice.round().toString();

      calculatedGrossActive += item.totalPrice;
      calculatedTotalQtyActive += item.quantity;

      final displayName = item.name;
      final nameLines = _wrapText(displayName, prodWidth);
      final firstLine = nameLines.isNotEmpty ? nameLines.first : displayName;

      builder.row([
        EscPosColumn(text: srNo, width: srWidth, align: EscPosAlign.left),
        EscPosColumn(text: firstLine, width: prodWidth, align: EscPosAlign.left),
        EscPosColumn(text: priceStr, width: priceWidth, align: EscPosAlign.right),
        EscPosColumn(text: qtyStr, width: qtyWidth, align: EscPosAlign.right),
        EscPosColumn(text: totalStr, width: totalWidth, align: EscPosAlign.right),
      ]);

      for (int l = 1; l < nameLines.length; l++) {
        builder.row([
          EscPosColumn(text: '', width: srWidth, align: EscPosAlign.left),
          EscPosColumn(text: nameLines[l], width: prodWidth, align: EscPosAlign.left),
          EscPosColumn(text: '', width: priceWidth, align: EscPosAlign.right),
          EscPosColumn(text: '', width: qtyWidth, align: EscPosAlign.right),
          EscPosColumn(text: '', width: totalWidth, align: EscPosAlign.right),
        ]);
      }

      // Modifiers in parentheses e.g. (Medium)
      final modifiers = <String>[];
      if (item.size != null && item.size!.isNotEmpty && item.size != 'Regular') {
        modifiers.add('(${item.size})');
      }
      if (item.crust != null && item.crust!.isNotEmpty && item.crust != 'Original') {
        modifiers.add('(${item.crust})');
      }
      if (item.toppings.isNotEmpty) {
        modifiers.add('(${item.toppings.join(", ")})');
      }
      if (item.notes != null && item.notes!.isNotEmpty) {
        modifiers.add('(${item.notes})');
      }

      for (final mod in modifiers) {
        final modLines = _wrapText(mod, prodWidth);
        for (final ml in modLines) {
          builder.row([
            EscPosColumn(text: '', width: srWidth, align: EscPosAlign.left),
            EscPosColumn(text: ml, width: prodWidth, align: EscPosAlign.left),
            EscPosColumn(text: '', width: priceWidth, align: EscPosAlign.right),
            EscPosColumn(text: '', width: qtyWidth, align: EscPosAlign.right),
            EscPosColumn(text: '', width: totalWidth, align: EscPosAlign.right),
          ]);
        }
      }
    }

    builder.divider();

    // 5. TOTALS SECTION
    final grossAmt = calculatedGrossActive.clamp(0.0, double.infinity);
    final totalQty = calculatedTotalQtyActive.clamp(0.0, double.infinity);

    final labelWidth = width - qtyWidth - totalWidth;
    builder.row([
      EscPosColumn(text: 'Gross Total:', width: labelWidth, align: EscPosAlign.right, isBold: true),
      EscPosColumn(text: totalQty.round().toString(), width: qtyWidth, align: EscPosAlign.right, isBold: true),
      EscPosColumn(text: grossAmt.round().toString(), width: totalWidth, align: EscPosAlign.right, isBold: true),
    ]);

    if (receipt.discountAmount > 0) {
      builder.keyValue('Discount:', '- ${receipt.discountAmount.round()}', isBold: false);
    }

    final double calcTax = receipt.taxRate > 0
        ? (grossAmt * receipt.taxRate / 100)
        : (receipt.items.any((i) => i.isCancelled) ? 0.0 : receipt.taxAmount);

    if (calcTax > 0) {
      final taxPctStr = receipt.taxRate == receipt.taxRate.roundToDouble()
          ? receipt.taxRate.toInt().toString()
          : receipt.taxRate.toStringAsFixed(1);
      final taxLabel = receipt.taxRate > 0
          ? 'GST / Tax ($taxPctStr%):'
          : 'GST / Tax:';
      builder.keyValue(taxLabel, '+ ${calcTax.round()}', isBold: false);
    }
    if (receipt.serviceChargeAmount > 0) {
      builder.keyValue('Service Charge:', '+ ${receipt.serviceChargeAmount.round()}', isBold: false);
    }
    if (receipt.deliveryFee > 0) {
      builder.keyValue('Delivery Fee:', '+ ${receipt.deliveryFee.round()}', isBold: false);
    }

    builder.divider();

    // Net Total (Strictly excludes cancelled items from the final bill total)
    final double netTotal = (grossAmt - receipt.discountAmount + calcTax + receipt.serviceChargeAmount + receipt.deliveryFee).clamp(0.0, double.infinity);

    builder.row([
      EscPosColumn(text: 'Net Total:', width: width - totalWidth - 4, align: EscPosAlign.right, isBold: true),
      EscPosColumn(text: netTotal.round().toString(), width: totalWidth + 4, align: EscPosAlign.right, isBold: true),
    ]);

    builder.divider();

    // 6. FOOTER
    builder.writeLine('Thank you for your visit', align: EscPosAlign.center, size: EscPosFontSize.normal);

    // 7. FEED & CUT
    if (autoCut) {
      builder.cut();
    } else {
      builder.feed(1);
    }

    return builder.getBytes();
  }

  // ---------------------------------------------------------------------------
  // Dedicated Kitchen Order Ticket (Food Picker) Format Generator
  // ---------------------------------------------------------------------------
  static Uint8List _buildKitchenKotBytes({
    required ReceiptData receipt,
    PaperWidth paperWidth = PaperWidth.roll80mm,
    bool autoCut = true,
    bool isKitchenPrinter = false,
  }) {
    final int width = paperWidth == PaperWidth.roll58mm ? 32 : 48;
    final builder = EscPosBuilder(lineWidth: width);

    builder.initialize();

    // 1. HEADER: "Kitchen Receipt" on Kitchen printer; "Food Picker - Dine In" on POS printer
    String orderTypeTitle = 'Dine In';
    if (receipt.orderType != null) {
      final ot = receipt.orderType!.toUpperCase();
      if (ot.contains('TAKEAWAY') || ot.contains('TAKE AWAY')) {
        orderTypeTitle = 'Takeaway';
      } else if (ot.contains('DELIVERY')) {
        orderTypeTitle = 'Delivery';
      } else if (ot.contains('ONLINE')) {
        orderTypeTitle = 'Online';
      } else {
        orderTypeTitle = 'Dine In';
      }
    }

    final headerTitle = isKitchenPrinter
        ? 'Kitchen Receipt'
        : 'Food Picker - $orderTypeTitle';

    builder.writeLine(
      headerTitle,
      align: EscPosAlign.center,
      size: EscPosFontSize.normal,
    );

    // 2. SUB-HEADER: "Hall - TABLE 1"
    final displayOrderNum = format3DigitOrderNumber(receipt.orderNumber);
    String subHeader = '';
    if (orderTypeTitle == 'Dine In') {
      final section = receipt.tableSection ?? 'Hall';
      final table = receipt.tableName ?? 'TABLE ${receipt.tableNumber ?? "1"}';
      subHeader = '$section - $table';
    } else if (orderTypeTitle == 'Takeaway') {
      subHeader = 'Takeaway - Token #$displayOrderNum';
    } else if (orderTypeTitle == 'Delivery') {
      subHeader = 'Delivery - #$displayOrderNum';
    } else {
      subHeader = 'Online - #$displayOrderNum';
    }

    builder.writeLine(
      subHeader,
      align: EscPosAlign.center,
      size: EscPosFontSize.bold,
    );

    if (receipt.isReprint) {
      builder.writeLine(
        '*** REPRINT ***',
        align: EscPosAlign.center,
        size: EscPosFontSize.bold,
      );
    } else if (receipt.isModified) {
      builder.writeLine(
        '*** ORDER MODIFIED / UPDATED ***',
        align: EscPosAlign.center,
        size: EscPosFontSize.bold,
      );
    }

    // 3. METADATA: Date & Time (immediately following subheader without extra gap)
    final dateStr = 'Date: ${DateFormat('MMM d yyyy').format(receipt.dateTime)}';
    final timeStr = 'Time: ${DateFormat('HH:mm').format(receipt.dateTime)}';

    _writeTwoColumnLine(builder, width, 'Ticket: #$displayOrderNum', timeStr);
    builder.writeLine(dateStr, align: EscPosAlign.left);

    // 4. ITEMS TABLE HEADER
    // ------------------------------------------------
    // Product Name                            Quantity
    // ------------------------------------------------
    builder.divider();
    final nameColWidth = width == 32 ? 22 : 38;
    final qtyColWidth = width - nameColWidth;

    builder.row([
      EscPosColumn(text: 'Product Name', width: nameColWidth, align: EscPosAlign.left, isBold: true),
      EscPosColumn(text: 'Quantity', width: qtyColWidth, align: EscPosAlign.right, isBold: true),
    ]);
    builder.divider();

    // 5. ITEM ROWS WITH HORIZONTAL BORDER SEPARATORS
    for (final item in receipt.items) {
      final qtyStr = item.isCancelled
          ? '-${item.quantity}'
          : '${item.quantity}';
      final displayName = item.isCancelled ? _strikeThrough(item.name) : item.name;

      final nameLines = _wrapText(displayName, nameColWidth);
      final firstLine = nameLines.isNotEmpty ? nameLines.first : displayName;

      builder.row([
        EscPosColumn(text: firstLine, width: nameColWidth, align: EscPosAlign.left, isBold: false),
        EscPosColumn(text: qtyStr, width: qtyColWidth, align: EscPosAlign.right, isBold: true),
      ]);

      for (int i = 1; i < nameLines.length; i++) {
        builder.row([
          EscPosColumn(text: nameLines[i], width: nameColWidth, align: EscPosAlign.left, isBold: false),
          EscPosColumn(text: '', width: qtyColWidth, align: EscPosAlign.right),
        ]);
      }

      // Modifiers in parentheses e.g. (Medium), (Original Crust)
      final modifiers = <String>[];
      if (item.size != null && item.size!.isNotEmpty && item.size != 'Regular') {
        modifiers.add('(${item.size})');
      }
      if (item.crust != null && item.crust!.isNotEmpty && item.crust != 'Original') {
        modifiers.add('(${item.crust})');
      }
      if (item.toppings.isNotEmpty) {
        modifiers.add('(${item.toppings.join(', ')})');
      }
      if (item.notes != null && item.notes!.isNotEmpty) {
        modifiers.add('(${item.notes})');
      }

      for (final mod in modifiers) {
        final modLines = _wrapText(mod, nameColWidth);
        for (final ml in modLines) {
          builder.row([
            EscPosColumn(text: ml, width: nameColWidth, align: EscPosAlign.left, isBold: false),
            EscPosColumn(text: '', width: qtyColWidth, align: EscPosAlign.right),
          ]);
        }
      }

      builder.divider();
    }

    // 6. TOTAL QUANTITY ROW (Net remaining active quantity)
    final totalQty = receipt.items.where((i) => !i.isCancelled).fold<int>(0, (sum, i) => sum + i.quantity);
    final totalQtyStr = totalQty.toString();

    builder.row([
      EscPosColumn(text: 'Total:', width: nameColWidth, align: EscPosAlign.left, isBold: true),
      EscPosColumn(text: totalQtyStr, width: qtyColWidth, align: EscPosAlign.right, isBold: true),
    ]);
    builder.divider();

    if (receipt.notes != null && receipt.notes!.isNotEmpty) {
      builder.writeLine('Note: ${receipt.notes}', align: EscPosAlign.left);
      builder.divider();
    }

    // 7. FEED & CUT
    if (autoCut) {
      builder.cut();
    } else {
      builder.feed(1);
    }

    return builder.getBytes();
  }

  /// Converts raw RGBA image pixels (from PdfRaster) into ESC/POS GS v 0 raster bit image bytes
  /// This physically burns the exact pixel graphics (including strikethrough lines) straight onto thermal paper!
  static Uint8List rasterToEscPosBytes({
    required Uint8List rgbaPixels,
    required int width,
    required int height,
    bool autoCut = true,
    bool openCashDrawer = false,
  }) {
    final builder = BytesBuilder();
    builder.add(cmdInit); // ESC @

    if (openCashDrawer) {
      builder.add(cmdDrawerKick);
    }

    final int widthBytes = (width + 7) ~/ 8;
    final int pixelStride = width * 4;
    final int totalLength = rgbaPixels.length;

    // 1. Ultra-fast bottom whitespace detection (scans bottom-up with row offsets)
    int effectiveHeight = 0;
    for (int y = height - 1; y >= 0; y--) {
      final int rowOffset = y * pixelStride;
      bool hasContent = false;
      for (int x = 0; x < width; x += 2) {
        final int offset = rowOffset + (x * 4);
        if (offset + 3 < totalLength) {
          if (rgbaPixels[offset + 3] > 40) {
            final int r = rgbaPixels[offset];
            final int g = rgbaPixels[offset + 1];
            final int b = rgbaPixels[offset + 2];
            // Luminance threshold < 190 (r*299 + g*587 + b*114 < 190000)
            if ((r * 299 + g * 587 + b * 114) < 190000) {
              hasContent = true;
              break;
            }
          }
        }
      }
      if (hasContent) {
        effectiveHeight = (y + 4 <= height) ? y + 4 : height;
        break;
      }
    }
    if (effectiveHeight == 0) {
      effectiveHeight = height;
    }

    // 2. High-performance raster chunk encoding (max 240 lines per thermal buffer chunk)
    const int maxChunkHeight = 240;
    for (int yStart = 0; yStart < effectiveHeight; yStart += maxChunkHeight) {
      final int currentChunkHeight = (yStart + maxChunkHeight <= effectiveHeight) ? maxChunkHeight : (effectiveHeight - yStart);

      final int xL = widthBytes & 0xFF;
      final int xH = (widthBytes >> 8) & 0xFF;
      final int yL = currentChunkHeight & 0xFF;
      final int yH = (currentChunkHeight >> 8) & 0xFF;

      // GS v 0 0 xL xH yL yH
      builder.add([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);

      final int chunkDataSize = currentChunkHeight * widthBytes;
      final Uint8List chunkBuffer = Uint8List(chunkDataSize);
      int chunkOffset = 0;

      for (int y = yStart; y < yStart + currentChunkHeight; y++) {
        final int rowOffset = y * pixelStride;
        for (int byteIdx = 0; byteIdx < widthBytes; byteIdx++) {
          int byteVal = 0;
          final int xBase = byteIdx * 8;
          for (int bit = 0; bit < 8; bit++) {
            final int x = xBase + bit;
            if (x < width) {
              final int offset = rowOffset + (x * 4);
              if (offset + 3 < totalLength && rgbaPixels[offset + 3] > 40) {
                final int r = rgbaPixels[offset];
                final int g = rgbaPixels[offset + 1];
                final int b = rgbaPixels[offset + 2];
                if ((r * 299 + g * 587 + b * 114) < 190000) {
                  byteVal |= (1 << (7 - bit));
                }
              }
            }
          }
          chunkBuffer[chunkOffset++] = byteVal;
        }
      }
      builder.add(chunkBuffer);
    }

    if (autoCut) {
      builder.add([0x1B, 0x64, 0x01]); // Minimal feed 1 line to clear printhead
      builder.add(cmdCutPartial);
    } else {
      builder.add([0x1B, 0x64, 0x01]); // Feed 1 line
    }

    return builder.toBytes();
  }

  static void _writeTwoColumnLine(EscPosBuilder builder, int lineWidth, String left, String right) {
    final cleanLeft = EscPosBuilder._sanitize(left);
    final cleanRight = EscPosBuilder._sanitize(right);
    final spaces = lineWidth - cleanLeft.length - cleanRight.length;
    if (spaces > 0) {
      builder.writeRawText('$cleanLeft${' ' * spaces}$cleanRight\n');
    } else {
      builder.writeRawText('$cleanLeft $cleanRight\n');
    }
  }

  static List<String> _wrapText(String text, int maxWidth) {
    if (text.length <= maxWidth) return [text];
    final words = text.split(' ');
    final lines = <String>[];
    String current = '';
    for (final word in words) {
      if (current.isEmpty) {
        current = word;
      } else if (current.length + 1 + word.length <= maxWidth) {
        current += ' $word';
      } else {
        lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) {
      lines.add(current);
    }
    return lines;
  }

  static String _strikeThrough(String text) {
    if (text.isEmpty) return text;
    return text;
  }

  static String format3DigitOrderNumber(String orderNumber) {
    if (orderNumber.isEmpty) return '101';
    final digits = orderNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 3) return digits;
    if (digits.length > 3) {
      return digits.substring(digits.length - 3);
    }
    if (digits.isNotEmpty) {
      return digits.padLeft(3, '0');
    }
    return orderNumber.length > 3 ? orderNumber.substring(orderNumber.length - 3) : orderNumber.padLeft(3, '0');
  }
}


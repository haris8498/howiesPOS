import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../services/receipt_printer_service.dart';

class PrinterSettingsDialog extends StatefulWidget {
  const PrinterSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const PrinterSettingsDialog(),
    );
  }

  @override
  State<PrinterSettingsDialog> createState() => _PrinterSettingsDialogState();
}

class _PrinterSettingsDialogState extends State<PrinterSettingsDialog> {
  List<String> _printerOptions = [];
  String? _selectedPosPrinter;
  String? _selectedKitchenPrinter;

  bool _isLoading = true;
  bool _isTestingPos = false;
  bool _isTestingKitchen = false;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() => _isLoading = true);
    try {
      final options = await ReceiptPrinterService.getAllPrinterOptions();
      // Filter out any ports so only real physical/spooler printers are shown
      final cleanPrinters = options.where((p) => !p.toLowerCase().startsWith('port:')).toList();

      final savedPos = await ReceiptPrinterService.getSavedPrinterName();
      final savedKitchen = await ReceiptPrinterService.getKitchenPrinterName();

      if (mounted) {
        setState(() {
          _printerOptions = cleanPrinters;

          // POS Printer selection: select saved printer if currently detected, otherwise default to first detected
          if (savedPos != null && cleanPrinters.contains(savedPos)) {
            _selectedPosPrinter = savedPos;
          } else if (cleanPrinters.isNotEmpty) {
            _selectedPosPrinter = cleanPrinters.first;
          } else {
            _selectedPosPrinter = 'None';
          }

          // Kitchen Printer selection: only select if user previously saved a real detected printer
          if (savedKitchen != null && cleanPrinters.contains(savedKitchen)) {
            _selectedKitchenPrinter = savedKitchen;
          } else {
            _selectedKitchenPrinter = 'None';
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAndApply() async {
    final posToSave = (_selectedPosPrinter == null || _selectedPosPrinter == 'None')
        ? 'None'
        : _selectedPosPrinter!;
    final kitchenToSave = (_selectedKitchenPrinter == null || _selectedKitchenPrinter == 'None')
        ? 'None'
        : _selectedKitchenPrinter!;

    await ReceiptPrinterService.savePrinterSettings(
      printerName: posToSave,
      kitchenPrinterName: kitchenToSave,
      kitchenSameAsCustomer: false,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Printer setup saved successfully!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _runTestPrintPos() async {
    if (_selectedPosPrinter == null || _selectedPosPrinter == 'None') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a POS printer first to run a test print.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    setState(() => _isTestingPos = true);
    try {
      await ReceiptPrinterService.savePrinterSettings(
        printerName: _selectedPosPrinter,
        kitchenPrinterName: _selectedKitchenPrinter ?? 'None',
        kitchenSameAsCustomer: false,
      );

      final testReceipt = ReceiptData(
        type: ReceiptType.customerReceipt,
        storeName: "HUNGRY HOWIES",
        branchName: 'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.',
        branchCode: 'Branch #402',
        storePhone: '+1 (800) 555-HOWIE',
        orderNumber: 'TEST-101',
        tokenNumber: '101',
        tableNumber: '1',
        tableName: 'POS TEST SLIP',
        orderType: 'DINE-IN',
        cashierOrServer: 'CASHIER',
        dateTime: DateTime.now(),
        items: const [
          ReceiptItemData(
            name: 'Chicken Tikka Pizza',
            quantity: 1,
            unitPrice: 1250,
            totalPrice: 1250,
            size: 'Medium',
          ),
          ReceiptItemData(
            name: 'Mineral Water 500ml',
            quantity: 2,
            unitPrice: 80,
            totalPrice: 160,
          ),
        ],
        subtotal: 1410,
        discountAmount: 0,
        taxAmount: 70.5,
        taxRate: 5.0,
        grandTotal: 1480.5,
        paymentMethod: 'CASH',
        tenderedAmount: 1500,
        changeReturned: 19.5,
      );

      if (mounted) {
        await ReceiptPrinterService.printReceipt(
          context: context,
          receipt: testReceipt,
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingPos = false);
    }
  }

  Future<void> _runTestPrintKitchen() async {
    if (_selectedKitchenPrinter == null || _selectedKitchenPrinter == 'None') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Kitchen printer first to run a test print.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    setState(() => _isTestingKitchen = true);
    try {
      await ReceiptPrinterService.savePrinterSettings(
        printerName: _selectedPosPrinter ?? 'None',
        kitchenPrinterName: _selectedKitchenPrinter,
        kitchenSameAsCustomer: false,
      );

      final testKot = ReceiptData(
        type: ReceiptType.kitchenKot,
        storeName: "HUNGRY HOWIES",
        orderNumber: 'KOT-101',
        tokenNumber: '101',
        tableNumber: '1',
        tableName: 'HALL - TABLE 1',
        tableSection: 'Hall',
        orderType: 'Dine In',
        cashierOrServer: 'KITCHEN TEST',
        dateTime: DateTime.now(),
        items: const [
          ReceiptItemData(
            name: '1x Large Fajita Pizza (Spicy)',
            quantity: 1,
            unitPrice: 1850,
            totalPrice: 1850,
            size: 'Large',
            crust: 'Stuffed Crust',
            notes: 'Extra Jalapenos & Well Done',
          ),
          ReceiptItemData(
            name: '1x Garlic Bread Stix',
            quantity: 1,
            unitPrice: 450,
            totalPrice: 450,
          ),
        ],
        subtotal: 2300,
        grandTotal: 2300,
      );

      if (mounted) {
        await ReceiptPrinterService.printReceipt(
          context: context,
          receipt: testKot,
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingKitchen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canTestPos = _selectedPosPrinter != null &&
        _selectedPosPrinter != 'None' &&
        _selectedPosPrinter!.isNotEmpty;

    final bool canTestKitchen = _selectedKitchenPrinter != null &&
        _selectedKitchenPrinter != 'None' &&
        _selectedKitchenPrinter!.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header with Close Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.print_rounded, color: AppColors.primaryRed, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Printer Setup',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Configure POS printer and Kitchen printer',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                  splashRadius: 20,
                  tooltip: 'Close',
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 14),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(color: AppColors.primaryRed),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rescan Hardware Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.devices_other_rounded, size: 16, color: Color(0xFF475569)),
                            const SizedBox(width: 8),
                            Text(
                              'Printers Detected: ${_printerOptions.length}',
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: _loadPrinters,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Row(
                              children: const [
                                Icon(Icons.refresh_rounded, size: 14, color: AppColors.primaryRed),
                                SizedBox(width: 4),
                                Text(
                                  'Rescan',
                                  style: TextStyle(
                                    color: AppColors.primaryRed,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // FIELD 1: POS printer
                  _buildPrinterDropdownField(
                    title: 'POS printer',
                    subtitle: 'Prints customer bills, takeaway receipts & settlement slips',
                    icon: Icons.point_of_sale_rounded,
                    iconColor: AppColors.primaryRed,
                    selectedValue: _selectedPosPrinter,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPosPrinter = val);
                    },
                  ),

                  const SizedBox(height: 16),

                  // FIELD 2: Kitchen printer
                  _buildPrinterDropdownField(
                    title: 'Kitchen printer',
                    subtitle: 'Prints Kitchen Order Tickets (KOT) for kitchen staff',
                    icon: Icons.restaurant_rounded,
                    iconColor: const Color(0xFFD97706),
                    selectedValue: _selectedKitchenPrinter,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedKitchenPrinter = val);
                    },
                  ),
                ],
              ),

            const SizedBox(height: 18),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 14),

            // Footer Action Buttons
            Row(
              children: [
                // Test POS Printer Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF15803D),
                    backgroundColor: const Color(0xFFF0FDF4),
                    side: const BorderSide(color: Color(0xFF22C55E), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isTestingPos
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF15803D)),
                        )
                      : const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text(
                    'Test POS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: (!canTestPos || _isTestingPos || _isTestingKitchen)
                      ? null
                      : _runTestPrintPos,
                ),
                const SizedBox(width: 8),

                // Test Kitchen Printer Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    backgroundColor: const Color(0xFFFFFBEB),
                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isTestingKitchen
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB45309)),
                        )
                      : const Icon(Icons.soup_kitchen_rounded, size: 16),
                  label: const Text(
                    'Test Kitchen',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: (!canTestKitchen || _isTestingPos || _isTestingKitchen)
                      ? null
                      : _runTestPrintKitchen,
                ),

                const Spacer(),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: const Text(
                    'Save Settings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  onPressed: _saveAndApply,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterDropdownField({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    // Collect dropdown items: 'None' first, then strictly real detected printers
    final cleanPrinters = _printerOptions.where((p) => !p.toLowerCase().startsWith('port:')).toList();
    final List<String> allItems = ['None', ...cleanPrinters];
    final effectiveValue = (selectedValue != null && allItems.contains(selectedValue))
        ? selectedValue
        : (cleanPrinters.isNotEmpty ? cleanPrinters.first : 'None');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 10),

          // Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: Colors.white,
                value: effectiveValue,
                items: allItems.map((p) {
                  final isNone = (p == 'None');
                  return DropdownMenuItem<String>(
                    value: p,
                    child: Row(
                      children: [
                        Icon(
                          isNone
                              ? Icons.block_rounded
                              : (p.toLowerCase().contains('pos') || p.toLowerCase().contains('receipt')
                                  ? Icons.receipt_long_rounded
                                  : Icons.print_outlined),
                          color: isNone ? const Color(0xFF94A3B8) : iconColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isNone ? 'None (Do not print)' : p,
                            style: TextStyle(
                              color: isNone ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                              fontSize: 12.5,
                              fontWeight: isNone ? FontWeight.normal : FontWeight.w600,
                              fontStyle: isNone ? FontStyle.italic : FontStyle.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

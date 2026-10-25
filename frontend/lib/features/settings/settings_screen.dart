import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../core/updater/app_version_provider.dart';
import '../../services/api/api_providers.dart';
import '../../core/network/realtime_socket_service.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../updater/auto_update_controller.dart';
import 'widgets/printer_settings_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _chainNameController = TextEditingController(text: "Hungry Howie's");
  final _branchCodeController = TextEditingController(text: 'Branch #402');
  final _branchNameController = TextEditingController(
    text: 'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.',
  );
  final _storePhoneController = TextEditingController(
    text: '+1 (800) 555-HOWIE',
  );
  final _salesTaxController = TextEditingController(text: '8.50');
  final _serviceChargeController = TextEditingController(text: '5.00');

  bool _isLoading = false;
  bool _isSaving = false;
  String _installedVersion = '';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    RealtimeSocketService.instance.on('settings:updated', _onRealtimeSettingsUpdated);
  }

  @override
  void dispose() {
    _chainNameController.dispose();
    _branchCodeController.dispose();
    _branchNameController.dispose();
    _storePhoneController.dispose();
    _salesTaxController.dispose();
    _serviceChargeController.dispose();
    RealtimeSocketService.instance.off('settings:updated', _onRealtimeSettingsUpdated);
    super.dispose();
  }

  void _onRealtimeSettingsUpdated(Map<String, dynamic> payload) {
    if (mounted) {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await ref.read(settingsApiServiceProvider).getSettings();
      if (settings.isNotEmpty) {
        _chainNameController.text =
            settings['chain_name']?.toString() ?? "Hungry Howie's";
        _branchCodeController.text =
            settings['branch_code']?.toString() ?? 'Branch #402';
        _branchNameController.text =
            settings['branch_name']?.toString() ??
            'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.';
        _storePhoneController.text =
            settings['store_phone']?.toString() ?? '+1 (800) 555-HOWIE';
        _salesTaxController.text =
            settings['sales_tax_rate']?.toString() ?? '8.50';
        _serviceChargeController.text =
            settings['dine_in_service_charge_rate']?.toString() ?? '5.00';
      }
      final ver = await const DefaultAppVersionProvider().getAppVersion();
      _installedVersion = ver;
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkManualUpdate() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final update = await ref
          .read(autoUpdateControllerProvider.notifier)
          .manualCheckForUpdate(context);
      if (update == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hungry Howie\'s POS is up to date (version ${_installedVersion.isNotEmpty ? _installedVersion : "1.0.0"}).',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final dto = {
        'chain_name': _chainNameController.text.trim(),
        'branch_code': _branchCodeController.text.trim(),
        'branch_name': _branchNameController.text.trim(),
        'store_phone': _storePhoneController.text.trim(),
        'sales_tax_rate': double.tryParse(_salesTaxController.text) ?? 8.5,
        'dine_in_service_charge_rate':
            double.tryParse(_serviceChargeController.text) ?? 5.0,
      };

      await ref.read(settingsApiServiceProvider).updateSettings(dto);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store settings updated successfully in backend!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: AppColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'SYSTEM SETTINGS & STORE CONFIGURATION',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                onPressed: _isSaving ? null : _saveSettings,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Branch & Restaurant Profile
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.storefront_rounded,
                      color: AppColors.primaryRed,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'RESTAURANT & BRANCH PROFILE',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Spacer(),
                    StatusBadge(
                      label: 'ACTIVE STORE BRANCH',
                      color: AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _chainNameController,
                  decoration: const InputDecoration(
                    labelText: 'Chain Name',
                    hintText: "Hungry Howies",
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _branchCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Branch Code',
                          hintText: 'Branch #402',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _branchNameController,
                        decoration: const InputDecoration(
                          labelText: 'Branch Name',
                          hintText:
                              'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _storePhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Store Phone',
                    hintText: '+1 (800) 555-HOWIE',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tax & Charges Settings
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TAX & SERVICE CHARGE CONFIGURATION',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _salesTaxController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Sales Tax Rate (%)',
                          hintText: '8.50',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _serviceChargeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Dine In Service Charge (%)',
                          hintText: '5.00',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // POS Thermal Printer Hardware Settings
          GlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.print_rounded,
                    color: AppColors.gold,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'POS THERMAL PRINTER & RECEIPT HARDWARE',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Direct USB/Network printer connectivity, 80mm/58mm thermal rolls, and one-click test print',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                  label: const Text('Configure Printer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => PrinterSettingsDialog.show(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Backend Database Status & Health
          GlassCard(
            child: Row(
              children: [
                const Icon(
                  Icons.storage_rounded,
                  color: AppColors.gold,
                  size: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'BACKEND DATABASE STATUS & HEALTH',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Connected via NestJS REST API & PostgreSQL schema',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                  ),
                  onPressed: _loadSettings,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Automatic Software Updates & Version
          GlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppColors.primaryRed,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AUTOMATIC SOFTWARE UPDATES',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Installed Version: ${_installedVersion.isNotEmpty ? _installedVersion : "1.0.0"} • Channel: Production GitHub Releases',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: _isCheckingUpdate
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_sync_rounded, size: 16),
                  label: Text(
                    _isCheckingUpdate ? 'Checking...' : 'Check for Updates',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                  ),
                  onPressed: _isCheckingUpdate ? null : _checkManualUpdate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

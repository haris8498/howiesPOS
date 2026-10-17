import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

/// Professional, reusable confirmation dialog for all deletion operations across the POS application.
class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String itemName;
  final String? itemType;
  final String? description;
  final String? warningNote;
  final String confirmButtonText;
  final String cancelButtonText;
  final IconData icon;

  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.itemName,
    this.itemType,
    this.description,
    this.warningNote = 'This action is permanent and cannot be undone.',
    this.confirmButtonText = 'YES, DELETE',
    this.cancelButtonText = 'CANCEL',
    this.icon = Icons.delete_forever_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      elevation: 24,
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Premium Danger Top Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // 2. Content Body
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target item highlighted card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFDC2626),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (itemType != null && itemType!.isNotEmpty)
                                Text(
                                  itemType!.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF991B1B),
                                  ),
                                ),
                              Text(
                                itemName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF7F1D1D),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Descriptive message
                  Text(
                    description ??
                        'Are you sure you want to permanently delete this item? All associated settings and configurations will be removed from the database.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: isDark ? const Color(0xFFCBD5E1) : AppColors.textPrimary,
                    ),
                  ),

                  if (warningNote != null && warningNote!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            warningNote!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // 3. Action Buttons (Cancel / Delete)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : AppColors.textSecondary,
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          cancelButtonText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          elevation: 2,
                          shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.delete_forever_rounded, size: 18),
                        label: Text(
                          confirmButtonText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.4,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience helper to prompt a standardized professional delete confirmation dialog anywhere.
Future<bool> showConfirmDeleteDialog({
  required BuildContext context,
  required String title,
  required String itemName,
  String? itemType,
  String? description,
  String? warningNote = 'This action is permanent and cannot be undone.',
  String confirmButtonText = 'YES, DELETE',
  String cancelButtonText = 'CANCEL',
  IconData icon = Icons.delete_forever_rounded,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (ctx) => ConfirmDeleteDialog(
      title: title,
      itemName: itemName,
      itemType: itemType,
      description: description,
      warningNote: warningNote,
      confirmButtonText: confirmButtonText,
      cancelButtonText: cancelButtonText,
      icon: icon,
    ),
  );
  return result ?? false;
}

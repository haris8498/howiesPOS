import 'package:flutter/material.dart';
import '../tables/tables_screen.dart';

/// Legacy POS Screen has been deprecated and removed.
/// All dine-in, takeaway, and delivery operations are handled by TablesScreen, TakeawayScreen, and DeliveryScreen.
class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TablesScreen();
  }
}

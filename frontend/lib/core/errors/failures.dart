/// Abstract base Failure class for pure domain and application exceptions.
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  String toString() => '$runtimeType: $message${code != null ? ' ($code)' : ''}';
}

/// Authentication and authorization failures
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

/// Order validation and processing failures
class OrderFailure extends Failure {
  const OrderFailure(super.message, {super.code});
}

/// Inventory and stock deduction failures
class InventoryFailure extends Failure {
  const InventoryFailure(super.message, {super.code});
}

/// Restaurant table and dining failures
class TableFailure extends Failure {
  const TableFailure(super.message, {super.code});
}

/// Kitchen display system failures
class KitchenFailure extends Failure {
  const KitchenFailure(super.message, {super.code});
}

/// Database and local storage failures
class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.code});
}

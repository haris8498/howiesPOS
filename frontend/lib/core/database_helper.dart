/// Pure Frontend Mode: Backend / SQLite database helper removed.
/// All application state is managed in-memory via Riverpod providers.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();
}

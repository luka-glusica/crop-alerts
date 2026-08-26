import 'location_book.dart';

/// Persistence for the grower's saved plots.
abstract class LocationStore {
  /// The saved book, or `null` on a fresh install.
  LocationBook? read();

  /// Replaces the saved book.
  Future<void> write(LocationBook book);
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/location_book.dart';
import '../domain/location_store.dart';

/// [LocationStore] backed by [SharedPreferences].
///
/// The whole book is stored as one JSON string rather than as separate keys:
/// the list and the active selection have to change together, and a single
/// value cannot be left half-written.
class PrefsLocationStore implements LocationStore {
  PrefsLocationStore(this._prefs);

  static const String storageKey = 'locations.book';

  final SharedPreferences _prefs;

  @override
  LocationBook? read() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return LocationBook.fromJson(json);
    } on FormatException {
      // A corrupted value should cost the saved plots, not every launch.
      return null;
    }
  }

  @override
  Future<void> write(LocationBook book) =>
      _prefs.setString(storageKey, jsonEncode(book.toJson()));
}

/// [LocationStore] held in memory, for tests.
class InMemoryLocationStore implements LocationStore {
  InMemoryLocationStore([this._book]);

  LocationBook? _book;

  /// How many times the book has been written, for assertions in tests.
  int writes = 0;

  @override
  LocationBook? read() => _book;

  @override
  Future<void> write(LocationBook book) async {
    writes++;
    _book = book;
  }
}

import 'dart:ui';

import 'crop.dart';

/// Supplies the crop catalogue for a language.
///
/// An interface because the catalogue is exactly what changes when community
/// contributions arrive: a remote implementation slots in behind the
/// `communityCrops` flag without anything above it noticing.
abstract class CropRepository {
  /// The crops available in [locale], falling back to the app's primary
  /// language when that locale has no catalogue.
  Future<List<Crop>> load(Locale locale);
}

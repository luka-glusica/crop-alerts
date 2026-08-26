import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local_crop_repository.dart';
import 'domain/crop.dart';
import 'domain/crop_repository.dart';
import 'domain/crop_risk_evaluator.dart';

/// The crop catalogue source.
///
/// The seam where a remote, community-contributed catalogue slots in behind the
/// `communityCrops` flag.
final cropRepositoryProvider = Provider<CropRepository>((ref) {
  return LocalCropRepository();
});

/// The crops for a given language.
final cropsProvider = FutureProvider.family<List<Crop>, Locale>((ref, locale) {
  return ref.watch(cropRepositoryProvider).load(locale);
});

/// Joins the rule engine to crops and their growing seasons.
final cropRiskEvaluatorProvider = Provider<CropRiskEvaluator>((ref) {
  return const CropRiskEvaluator();
});

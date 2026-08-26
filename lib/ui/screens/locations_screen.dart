import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../features/locations/domain/location_draft.dart';
import '../../features/locations/domain/saved_location.dart';
import '../../features/locations/locations_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../icons/app_icons.dart';
import 'location_map_screen.dart';

/// Manages the grower's locations: add, rename, move, reorder and select.
class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  static const String routeName = '/locations';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(locationsProvider);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.locations)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(AppIcons.addLocation),
        label: Text(l10n.addLocation),
        backgroundColor: palette.brand,
        foregroundColor: palette.textOnBrand,
      ),
      body: book.isEmpty
          ? _EmptyState(l10n: l10n)
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s2,
                AppSpacing.s4,
                AppSpacing.s16 + AppSpacing.s12,
              ),
              itemCount: book.locations.length,
              onReorderItem: (oldIndex, newIndex) =>
                  ref.read(locationsProvider.notifier).reorder(oldIndex, newIndex),
              itemBuilder: (context, index) {
                final location = book.locations[index];
                return _LocationTile(
                  key: ValueKey(location.id),
                  index: index,
                  location: location,
                  isActive: location.id == book.active?.id,
                  onSelect: () => ref
                      .read(locationsProvider.notifier)
                      .setActive(location.id),
                  onEdit: () => _openEditor(context, ref, existing: location),
                  onDelete: () => _confirmDelete(context, ref, location),
                );
              },
            ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    SavedLocation? existing,
  }) async {
    final draft = await Navigator.of(context).push<LocationDraft>(
      MaterialPageRoute<LocationDraft>(
        builder: (context) => LocationMapScreen(existing: existing),
      ),
    );
    if (draft == null || !context.mounted) return;

    final controller = ref.read(locationsProvider.notifier);
    final name = draft.name.trim();
    if (existing == null) {
      await controller.add(name: name, coordinates: draft.coordinates);
    } else {
      await controller.edit(existing.id, name: name, coordinates: draft.coordinates);
    }

    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? l10n.locationAdded(name) : l10n.locationUpdated(name),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SavedLocation location,
  ) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteLocationConfirm(location.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(locationsProvider.notifier).remove(location.id);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.location, size: 48, color: palette.textMuted),
            const SizedBox(height: AppSpacing.s4),
            Text(l10n.noLocations, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s2),
            Text(
              l10n.noLocationsHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.index,
    required this.location,
    required this.isActive,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final int index;
  final SavedLocation location;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Material(
        color: isActive ? palette.brandMuted : palette.surface,
        borderRadius: AppRadii.xl2All,
        child: InkWell(
          onTap: onSelect,
          borderRadius: AppRadii.xl2All,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(
              borderRadius: AppRadii.xl2All,
              border: Border.all(
                color: isActive ? palette.brand : palette.border,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.location,
                  color: isActive ? palette.brand : palette.textMuted,
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isActive)
                        Text(
                          l10n.activeLocation.toUpperCase(),
                          style: text.labelSmall,
                        ),
                      Text(location.name, style: text.titleSmall),
                      Text(
                        '${location.coordinates.latitudeParam}, '
                        '${location.coordinates.longitudeParam}',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(AppIcons.edit),
                  tooltip: l10n.editLocation,
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(AppIcons.delete),
                  tooltip: l10n.delete,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s2),
                    child: Icon(AppIcons.reorder, color: palette.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


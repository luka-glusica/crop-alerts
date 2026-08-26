import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:latlong2/latlong.dart';

import '../../core/theme/theme.dart';
import '../../features/locations/domain/device_location_service.dart';
import '../../features/locations/domain/location_draft.dart';
import '../../features/locations/domain/saved_location.dart';
import '../../features/locations/locations_controller.dart';
import '../../features/weather/domain/coordinates.dart';
import '../../l10n/generated/app_localizations.dart';
import '../icons/app_icons.dart';

/// Picks a point on a satellite map and names it.
///
/// Pops the resulting [LocationDraft] rather than saving it — the caller
/// decides whether that means adding a new location or editing [existing].
class LocationMapScreen extends ConsumerStatefulWidget {
  const LocationMapScreen({this.existing, super.key});

  /// The location being edited, or `null` when adding a new one.
  final SavedLocation? existing;

  @override
  ConsumerState<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends ConsumerState<LocationMapScreen> {
  static const String _tileUrlTemplate =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  final MapController _mapController = MapController();
  late final TextEditingController _name;

  /// The chosen point. `null` on a fresh add until the grower taps the map or
  /// locates themselves; pre-filled with the saved point on edit, so the
  /// drawer starts open.
  Coordinates? _selected;

  /// Whether Save has been pressed, so the name error only appears once the
  /// grower has actually tried to confirm.
  bool _submitted = false;

  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _selected = widget.existing?.coordinates;
  }

  @override
  void dispose() {
    _name.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Coordinates get _initialCenter =>
      widget.existing?.coordinates ??
      ref.read(activeLocationProvider)?.coordinates ??
      Coordinates.belgrade;

  void _selectPoint(LatLng point) {
    setState(() {
      _selected = Coordinates(
        latitude: point.latitude,
        longitude: point.longitude,
      );
    });
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final result = await ref.read(deviceLocationServiceProvider).current();
    if (!mounted) return;
    setState(() => _locating = false);

    final coordinates = result.coordinates;
    if (coordinates != null) {
      setState(() => _selected = coordinates);
      _mapController.move(
        LatLng(coordinates.latitude, coordinates.longitude),
        16,
      );
      return;
    }

    _showFailure(result.failure!);
  }

  void _showFailure(DeviceLocationFailure failure) {
    final l10n = AppLocalizations.of(context);
    final message = switch (failure) {
      DeviceLocationFailure.servicesDisabled => l10n.locationServicesOff,
      DeviceLocationFailure.permissionDenied => l10n.locationPermissionDenied,
      DeviceLocationFailure.permissionBlocked => l10n.locationPermissionBlocked,
      DeviceLocationFailure.unavailable => l10n.locationUnavailable,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: failure == DeviceLocationFailure.permissionBlocked
            ? SnackBarAction(
                label: l10n.openSettings,
                onPressed: Geolocator.openAppSettings,
              )
            : null,
      ),
    );
  }

  void _save() {
    setState(() => _submitted = true);
    final selected = _selected;
    if (selected == null || _name.text.trim().isEmpty) return;
    Navigator.of(context)
        .pop(LocationDraft(name: _name.text, coordinates: selected));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final center = _initialCenter;
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pickLocation)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(center.latitude, center.longitude),
              initialZoom: 15,
              // Below the tile layer's own zoom range (0..19) it renders
              // nothing at all, so the camera must never reach that — without
              // a floor, zooming out with two fingers goes past 0 and the map
              // turns blank.
              minZoom: 3,
              maxZoom: 19,
              // A tilted map makes it harder to tell where a tap will land.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, point) => _selectPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrlTemplate,
                userAgentPackageName: 'com.cropalert.app',
                maxNativeZoom: 17,
                tileProvider: ref.watch(mapTileProviderProvider),
              ),
              if (selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(selected.latitude, selected.longitude),
                      // The pin's tip, not its center, marks the coordinate.
                      alignment: Alignment.topCenter,
                      width: 40,
                      height: 40,
                      child: Icon(
                        AppIcons.location,
                        size: 40,
                        color: palette.brand,
                      ),
                    ),
                  ],
                ),
              RichAttributionWidget(
                attributions: [TextSourceAttribution(l10n.attributionEsri)],
              ),
            ],
          ),
          if (selected == null)
            Positioned(
              top: AppSpacing.s3,
              left: AppSpacing.s4,
              right: AppSpacing.s4,
              child: _Hint(text: l10n.pickLocationHint),
            ),
          Positioned(
            top: AppSpacing.s3,
            right: AppSpacing.s4,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              tooltip: l10n.myLocation,
              backgroundColor: palette.surface,
              foregroundColor: palette.textPrimary,
              onPressed: _locating ? null : _locate,
              child: _locating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.brand,
                      ),
                    )
                  : const Icon(AppIcons.myLocation),
            ),
          ),
          if (selected != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _NameDrawer(
                nameController: _name,
                coordinates: selected,
                autofocusName: widget.existing == null,
                showNameError: _submitted && _name.text.trim().isEmpty,
                // Only live once a save has actually been rejected — the
                // grower should not be scolded for a field they have not
                // reached yet.
                onNameChanged: _submitted ? () => setState(() {}) : null,
                onCancel: () => Navigator.of(context).pop(),
                onSave: _save,
              ),
            ),
        ],
      ),
    );
  }
}

/// Banner shown until the grower has picked a point, since the drawer has
/// nothing to show yet.
class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.surface,
      borderRadius: AppRadii.xlAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

/// The bottom panel for naming the point currently selected on the map.
///
/// A panel inside the [Stack] rather than a modal bottom sheet: it has to stay
/// in sync as the pin moves, and must not swallow taps on the rest of the map.
class _NameDrawer extends StatelessWidget {
  const _NameDrawer({
    required this.nameController,
    required this.coordinates,
    required this.autofocusName,
    required this.showNameError,
    required this.onNameChanged,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController nameController;
  final Coordinates coordinates;
  final bool autofocusName;
  final bool showNameError;
  final VoidCallback? onNameChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;

    return Material(
      color: palette.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadii.xl3),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.s4,
          right: AppSpacing.s4,
          top: AppSpacing.s6,
          // The keyboard (viewInsets) and the system nav bar/gesture area
          // (padding) both eat into the bottom of the screen and neither is
          // covered by the other — both have to be added, or the buttons end
          // up under the Samsung navigation pill or the keyboard.
          bottom:
              MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom +
              AppSpacing.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              autofocus: autofocusName,
              textInputAction: TextInputAction.done,
              onChanged: onNameChanged == null ? null : (_) => onNameChanged!(),
              onSubmitted: (_) => onSave(),
              decoration: InputDecoration(
                labelText: l10n.locationName,
                errorText: showNameError ? l10n.nameRequired : null,
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              l10n.coordinates.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              '${coordinates.latitudeParam}, ${coordinates.longitudeParam}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: FilledButton(
                    onPressed: onSave,
                    child: Text(l10n.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

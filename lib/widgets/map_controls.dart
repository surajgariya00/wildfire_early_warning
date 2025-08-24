import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final VoidCallback onLocate;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final bool exploreMode;
  final ValueChanged<bool> onToggleExplore;
  final VoidCallback onSearch;

  const MapControls({
    super.key,
    required this.onLocate,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.exploreMode,
    required this.onToggleExplore,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    ButtonStyle btn() => IconButton.styleFrom(
      backgroundColor: scheme.surface.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: onSearch, icon: const Icon(Icons.search), style: btn(), tooltip: 'Search place'),
            const SizedBox(height: 8),
            IconButton(onPressed: onLocate, icon: const Icon(Icons.my_location), style: btn(), tooltip: 'Go to my location'),
            const SizedBox(height: 8),
            IconButton(onPressed: onZoomIn, icon: const Icon(Icons.add), style: btn(), tooltip: 'Zoom in'),
            const SizedBox(height: 8),
            IconButton(onPressed: onZoomOut, icon: const Icon(Icons.remove), style: btn(), tooltip: 'Zoom out'),
            const SizedBox(height: 8),
            FilterChip(
              label: Text(exploreMode ? 'Explore: Global' : 'Explore: Local'),
              selected: exploreMode,
              onSelected: (v) => onToggleExplore(v),
            ),
          ],
        ),
      ),
    );
  }
}

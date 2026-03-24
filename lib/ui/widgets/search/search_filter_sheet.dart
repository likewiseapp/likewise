import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/theme_provider.dart';
import '../../../core/providers/hobby_providers.dart';


class SearchActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final AppColorScheme colors;
  final bool isDark;

  const SearchActiveChip({
    required this.label,
    required this.onRemove,
    required this.colors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : colors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 12,
                color: isDark ? Colors.white70 : colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Filter Bottom Sheet
// ═════════════════════════════════════════════════════════════════════════════

class SearchFilterSheet extends ConsumerStatefulWidget {
  final AppColorScheme colors;
  final bool isDark;
  final List<String> selectedHobbies;
  final double searchDistance;
  final Function(List<String>, double) onApply;
  final Set<String> ownedHobbyNames;
  final String? primaryHobbyName;

  const SearchFilterSheet({
    required this.colors,
    required this.isDark,
    required this.selectedHobbies,
    required this.searchDistance,
    required this.onApply,
    this.ownedHobbyNames = const {},
    this.primaryHobbyName,
  });

  @override
  ConsumerState<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends ConsumerState<SearchFilterSheet> {
  late List<String> _tempSelectedHobbies;
  late double _tempDistance;
  static const int _previewCount = 8;

  @override
  void initState() {
    super.initState();
    _tempSelectedHobbies = List.from(widget.selectedHobbies);
    _tempDistance = widget.searchDistance;
  }

  bool get _hasChanges =>
      _tempSelectedHobbies.isNotEmpty || _tempDistance != 500.0;

  void _openAllHobbiesSheet(
    BuildContext context,
    List<Map<String, dynamic>> allHobbies,
    Color surfaceColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllHobbiesDialog(
        colors: widget.colors,
        isDark: widget.isDark,
        allHobbies: allHobbies,
        selectedHobbies: _tempSelectedHobbies,
        surfaceColor: surfaceColor,
        onChanged: (updated) => setState(() => _tempSelectedHobbies = updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allHobbiesAsync = ref.watch(allHobbiesProvider);
    final allHobbiesMaps = (allHobbiesAsync.value ?? [])
        .where((h) => !widget.ownedHobbyNames.contains(h.name))
        .map((h) => {
              'name': h.name,
              'icon': h.icon,
              'color': h.color,
              'category': h.category,
            })
        .toList();
    final surfaceColor =
        widget.isDark ? AppColors.darkScaffold : AppColors.lightScaffold;

    return Scaffold(
      backgroundColor: widget.isDark ? AppColors.darkSurface : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                  ),
                  const Spacer(),
                  if (_hasChanges)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _tempSelectedHobbies.clear();
                          _tempDistance = 500.0;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent.shade100,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Scrollable Content ─────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Distance ───────────────────────────────────────
                    _SectionLabel(
                      icon: Icons.near_me_rounded,
                      label: 'Distance',
                      color: widget.colors.primary,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Up to',
                                style: TextStyle(
                                  color: widget.isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.colors.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_tempDistance.round()} km',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: widget.colors.primary,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              activeTrackColor: widget.colors.primary,
                              inactiveTrackColor: widget.colors.primary
                                  .withValues(alpha: 0.12),
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 9,
                                elevation: 3,
                                pressedElevation: 5,
                              ),
                              overlayColor: widget.colors.primary
                                  .withValues(alpha: 0.08),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 20,
                              ),
                            ),
                            child: Slider(
                              value: _tempDistance,
                              min: 5,
                              max: 500,
                              divisions: 99,
                              onChanged: (value) {
                                setState(() => _tempDistance = value);
                                HapticFeedback.selectionClick();
                              },
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '5 km',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                Text(
                                  '500 km',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Hobbies ────────────────────────────────────────
                    _SectionLabel(
                      icon: Icons.interests_rounded,
                      label: 'Interests',
                      color: widget.colors.primary,
                    ),
                    const SizedBox(height: 14),

                    // User's own hobbies — display-only, all fit in one row
                    if (widget.ownedHobbyNames.isNotEmpty) ...[
                      Text(
                        'Your hobbies',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? Colors.white54
                              : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(builder: (_) {
                        final allHobbies =
                            ref.read(allHobbiesProvider).value ?? [];
                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.ownedHobbyNames.map((name) {
                            final hobbyData = allHobbies
                                .where((h) => h.name == name)
                                .firstOrNull;
                            final icon = hobbyData?.icon ?? '✨';
                            final isPrimary =
                                name == widget.primaryHobbyName;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: widget.colors.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.colors.primary
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isPrimary) ...[
                                    Icon(
                                      Icons.star_rounded,
                                      size: 13,
                                      color: widget.colors.primary,
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                  Text(
                                    '$icon $name',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: widget.colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],

                    // Filter-selected hobbies — wrap, 5 per row then new line
                    if (_tempSelectedHobbies.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _tempSelectedHobbies.map((name) {
                          final hobbyData = allHobbiesMaps.firstWhere(
                            (h) => h['name'] == name,
                            orElse: () => {'name': name, 'icon': '✨'},
                          );
                          final icon = hobbyData['icon'] ?? '✨';
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(
                                  () => _tempSelectedHobbies.remove(name));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: widget.colors.primary
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.colors.primary
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$icon $name',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: widget.colors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: widget.colors.primary
                                        .withValues(alpha: 0.7),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Text(
                      'Add more interests',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? Colors.white54
                            : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Unselected hobbies — wrap grid (first 8 that aren't selected)
                    Builder(builder: (_) {
                      final unselected = allHobbiesMaps
                          .where((h) =>
                              !_tempSelectedHobbies.contains(h['name']))
                          .toList();
                      final visible = unselected.length > _previewCount
                          ? unselected.sublist(0, _previewCount)
                          : unselected;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          ...visible.map((hobby) {
                            final name = hobby['name'] as String;
                            final icon = hobby['icon'] ?? '✨';
                            return _HobbyChip(
                              name: name,
                              icon: icon,
                              isSelected: false,
                              colors: widget.colors,
                              isDark: widget.isDark,
                              surfaceColor: surfaceColor,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(
                                    () => _tempSelectedHobbies.add(name));
                              },
                            );
                          }),
                          // Show more button
                          if (allHobbiesMaps.length > _previewCount)
                            GestureDetector(
                              onTap: () => _openAllHobbiesSheet(
                                context,
                                allHobbiesMaps,
                                surfaceColor,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: widget.isDark
                                        ? Colors.white12
                                        : Colors.black12,
                                  ),
                                ),
                                child: Text(
                                  'Show more',
                                  style: TextStyle(
                                    color: widget.colors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // ── Apply Button ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              decoration: BoxDecoration(
                color:
                    widget.isDark ? AppColors.darkSurface : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onApply(_tempSelectedHobbies, _tempDistance);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _hasChanges ? 'Apply Filters' : 'Done',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// All Hobbies Bottom Sheet Dialog
// ═════════════════════════════════════════════════════════════════════════════

class _AllHobbiesDialog extends StatefulWidget {
  final AppColorScheme colors;
  final bool isDark;
  final List<Map<String, dynamic>> allHobbies;
  final List<String> selectedHobbies;
  final Color surfaceColor;
  final ValueChanged<List<String>> onChanged;

  const _AllHobbiesDialog({
    required this.colors,
    required this.isDark,
    required this.allHobbies,
    required this.selectedHobbies,
    required this.surfaceColor,
    required this.onChanged,
  });

  @override
  State<_AllHobbiesDialog> createState() => _AllHobbiesDialogState();
}

class _AllHobbiesDialogState extends State<_AllHobbiesDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedHobbies);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.allHobbies
        : widget.allHobbies
            .where((h) => (h['name'] as String)
                .toLowerCase()
                .contains(_query.toLowerCase()))
            .toList();
    final bg = widget.isDark ? AppColors.darkSurface : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // ── Handle bar ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Title + Unselect all + Done ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 8, 0),
                child: Row(
                  children: [
                    Text(
                      'All Interests',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    if (_selected.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selected.clear());
                        },
                        child: Text(
                          'Unselect all',
                          style: TextStyle(
                            color: Colors.redAccent.shade100,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () {
                        widget.onChanged(_selected);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: widget.colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search field ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search interests...',
                      hintStyle: TextStyle(
                        color: widget.isDark
                            ? Colors.white24
                            : Colors.black26,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: widget.isDark
                            ? Colors.white70
                            : Colors.black26,
                        size: 20,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(
                                Icons.close_rounded,
                                color: widget.isDark
                                    ? Colors.white38
                                    : Colors.black38,
                                size: 20,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              // ── Hobby list ─────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No interests found',
                          style: TextStyle(
                            color: widget.isDark
                                ? Colors.white24
                                : Colors.black26,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: filtered.map((hobby) {
                            final name = hobby['name'] as String;
                            final icon =
                                hobby['icon'] as String? ?? '✨';
                            final isSelected = _selected.contains(name);
                            return _HobbyChip(
                              name: name,
                              icon: icon,
                              isSelected: isSelected,
                              colors: widget.colors,
                              isDark: widget.isDark,
                              surfaceColor: widget.surfaceColor,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (isSelected) {
                                    _selected.remove(name);
                                  } else {
                                    _selected.add(name);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Reusable Hobby Chip
// ═════════════════════════════════════════════════════════════════════════════

class _HobbyChip extends StatelessWidget {
  final String name;
  final String icon;
  final bool isSelected;
  final AppColorScheme colors;
  final bool isDark;
  final Color surfaceColor;
  final VoidCallback onTap;

  const _HobbyChip({
    required this.name,
    required this.icon,
    required this.isSelected,
    required this.colors,
    required this.isDark,
    required this.surfaceColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.white : colors.primary)
                    : (isDark ? Colors.white60 : Colors.black54),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

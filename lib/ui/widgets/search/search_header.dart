import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme_provider.dart';

class SearchHeader extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final String searchQuery;
  final bool isSearching;
  final String selectedTag;
  final int activeFilterCount;
  final List<String> myHobbyNames;
  final String? primaryHobbyName;
  final List<String> extraFilterHobbies;
  final AppColorScheme colors;
  final bool isDark;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<String> onTagSelected;
  final VoidCallback onFilterTap;

  static const List<String> _quickTags = ['All', 'Trending'];

  const SearchHeader({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchQuery,
    required this.isSearching,
    required this.selectedTag,
    required this.activeFilterCount,
    required this.myHobbyNames,
    required this.primaryHobbyName,
    required this.extraFilterHobbies,
    required this.colors,
    required this.isDark,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onTagSelected,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.75)
            : Colors.white.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: colors.primary.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Search Row ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onChanged: onSearchChanged,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search people...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? Colors.white38 : Colors.black38,
                            size: 22,
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: onSearchCleared,
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                    size: 20,
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onFilterTap,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: activeFilterCount > 0
                                ? colors.primary
                                : (isDark ? Colors.white54 : Colors.black45),
                            size: 24,
                          ),
                          if (activeFilterCount > 0)
                            Positioned(
                              top: 9,
                              right: 9,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Tags Row (hidden while searching) ──────────────────────
              if (!isSearching) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Static quick tags
                      ..._quickTags.map((tag) {
                        final isSelected = tag == selectedTag;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onTagSelected(tag);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.primary
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.white),
                                borderRadius: BorderRadius.circular(99),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.08,
                                              ),
                                      ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: colors.primary.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : (isDark
                                            ? Colors.white70
                                            : Colors.black54),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      // User's own hobby pills (primary first)
                      ...[
                        if (primaryHobbyName != null) primaryHobbyName!,
                        ...myHobbyNames.where((h) => h != primaryHobbyName),
                      ].map((hobby) {
                        final isPrimary = hobby == primaryHobbyName;
                        final isSelected = selectedTag == hobby;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onTagSelected(hobby);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.primary
                                    : (isDark
                                          ? colors.primary.withValues(
                                              alpha: 0.15,
                                            )
                                          : colors.primary.withValues(
                                              alpha: 0.1,
                                            )),
                                borderRadius: BorderRadius.circular(99),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: colors.primary.withValues(
                                          alpha: 0.35,
                                        ),
                                        width: 1,
                                      ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: colors.primary.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isPrimary) ...[
                                    Icon(
                                      Icons.star_rounded,
                                      size: 13,
                                      color: isSelected
                                          ? Colors.white
                                          : colors.primary,
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(
                                    hobby,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.9,
                                                  )
                                                : colors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      // Extra filter hobbies (not already in myHobbyNames)
                      ...extraFilterHobbies
                          .where((h) => !myHobbyNames.contains(h))
                          .map((hobby) {
                            final isSelected = selectedTag == hobby;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  onTagSelected(hobby);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primary
                                        : (isDark
                                              ? colors.primary.withValues(
                                                  alpha: 0.15,
                                                )
                                              : colors.primary.withValues(
                                                  alpha: 0.1,
                                                )),
                                    borderRadius: BorderRadius.circular(99),
                                    border: isSelected
                                        ? null
                                        : Border.all(
                                            color: colors.primary.withValues(
                                              alpha: 0.35,
                                            ),
                                            width: 1,
                                          ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: colors.primary.withValues(
                                                alpha: 0.25,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    hobby,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.9,
                                                  )
                                                : colors.primary),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

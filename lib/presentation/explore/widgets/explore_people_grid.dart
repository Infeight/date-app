import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/map_user_model.dart';
import '../../common/widgets/widgets.dart';
import 'explore_avatar.dart';

/// Everyone at once — the "All" view, reached from either "All" tile or from
/// the header search.
///
/// A horizontal strip is fine for picking somebody you can already see and
/// hopeless for finding somebody specific. This is the other half: the whole
/// set laid out to be scanned, with a search field for when even that is too
/// many. Picking here selects and closes, landing back on the map focused on
/// that person.
///
/// Presented as a full sheet rather than a route so the map underneath is never
/// torn down and rebuilt — reloading vector tiles to show a list of faces would
/// be an expensive way to answer a cheap question.
class ExplorePeopleGrid extends StatefulWidget {
  const ExplorePeopleGrid({
    super.key,
    required this.people,
    required this.selectedId,
    required this.onSelect,
    required this.onShowAll,
    required this.onClose,
  });

  final List<MapUser> people;
  final String? selectedId;
  final ValueChanged<MapUser> onSelect;

  /// The "All" tile: put everybody back on the map and close.
  final VoidCallback onShowAll;

  final VoidCallback onClose;

  @override
  State<ExplorePeopleGrid> createState() => _ExplorePeopleGridState();
}

class _ExplorePeopleGridState extends State<ExplorePeopleGrid> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Hidden while searching: "All" is about the map, and a tile that ignores
  /// the query sitting among results that respect it just reads as a bug.
  bool get _showsAllTile => _query.trim().isEmpty;

  List<MapUser> get _visible {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.people;
    return widget.people
        .where((p) => p.displayName.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final people = _visible;

    return Container(
      // Exactly the height a profile opens at — [kSheetHeightFraction], not a
      // number of its own.
      //
      // It used to size itself to its contents, so the sheet was a different
      // height for four people than for forty; with four it was a strip at the
      // bottom of the screen that read as a toast rather than a destination.
      // A sheet people open to browse should be the same object every time,
      // and the same object as the other sheet they open to browse.
      height: MediaQuery.sizeOf(context).height * kSheetHeightFraction,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _header(),
            _searchField(),
            Flexible(
              child: people.isEmpty
                  ? _noMatches()
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        // Extent rather than a fixed count: five across on a
                        // phone, more on a tablet, without a breakpoint table.
                        maxCrossAxisExtent: 88,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.78,
                      ),
                      // "All" leads the grid, exactly as it leads the strip —
                      // it is the way to put everybody back on the map, and
                      // it has to be reachable from here too or the grid
                      // becomes a one-way door into a focused map.
                      itemCount: people.length + (_showsAllTile ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_showsAllTile && index == 0) {
                          return _AllTile(
                            active: widget.selectedId == null,
                            onTap: widget.onShowAll,
                          );
                        }
                        final person =
                            people[_showsAllTile ? index - 1 : index];
                        return _GridTile(
                          person: person,
                          selected: person.id == widget.selectedId,
                          onTap: () => widget.onSelect(person),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    // The count is of everybody, not of what survived the search — "3 of 52"
    // is the useful reading while filtering.
    final total = widget.people.length;
    final shown = _visible.length;
    final title = _query.trim().isEmpty
        ? 'All people ($total)'
        : '$shown of $total';

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 2),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back to the map',
            excludeSemantics: true,
            child: IconButton(
              onPressed: widget.onClose,
              icon: Icon(Icons.chevron_left, color: AppColors.textDark),
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: AppTextStyles.title.copyWith(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: TextField(
        controller: _search,
        onChanged: (value) => setState(() => _query = value),
        textInputAction: TextInputAction.search,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search by name',
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textGrey),
          prefixIcon:
              Icon(Icons.search, size: 20, color: AppColors.iconMuted),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                  icon: Icon(Icons.close,
                      size: 18, color: AppColors.iconMuted),
                ),
          filled: true,
          fillColor: AppColors.card,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.inputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _noMatches() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 34, color: AppColors.iconMuted),
            const SizedBox(height: 12),
            Text(
              'Nobody here by that name',
              style: AppTextStyles.bodyStrong,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Only the people currently on your map can be searched.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

/// The grid's counterpart to the strip's "All": everybody back on the map.
class _AllTile extends StatelessWidget {
  const _AllTile({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: 'Show everyone on the map',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: active
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppMapColors.markerStart,
                          AppMapColors.markerEnd,
                        ],
                      )
                    : null,
                color: active ? null : AppColors.card,
                border: active
                    ? null
                    : Border.all(color: AppColors.inputBorder, width: 1.4),
              ),
              child: Icon(
                Icons.groups_outlined,
                size: 24,
                color: active ? AppColors.onImage : AppColors.primary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'All',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                height: 1.2,
                color: active ? AppColors.primary : AppColors.textDark,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontVariations: [FontVariation('wght', active ? 700 : 500)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final MapUser person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Show ${person.displayName} on the map',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExploreAvatar(
              name: person.displayName,
              photoUrl: person.primaryPhotoUrl,
              size: 58,
              selected: selected,
              isOnline: person.isOnline,
            ),
            const SizedBox(height: 5),
            Text(
              person.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                height: 1.2,
                color: selected ? AppColors.primary : AppColors.textDark,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontVariations: [FontVariation('wght', selected ? 700 : 500)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

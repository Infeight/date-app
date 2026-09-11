import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/message_model.dart';
import '../../../providers/location_sharing_provider.dart';
import '../../common/widgets/widgets.dart';

/// Pick which friends can see me on the map.
///
/// Pops with the chosen ids, or with null if the screen is backed out of —
/// so leaving without tapping Done changes nothing, and there is no
/// half-applied state to reason about. The caller writes; this screen only
/// decides.
class LocationAudienceScreen extends ConsumerStatefulWidget {
  const LocationAudienceScreen({super.key, required this.initialSelection});

  final List<String> initialSelection;

  @override
  ConsumerState<LocationAudienceScreen> createState() =>
      _LocationAudienceScreenState();
}

class _LocationAudienceScreenState
    extends ConsumerState<LocationAudienceScreen> {
  /// Seeded from what is already saved and only ever changed by a tap.
  ///
  /// Deliberately **not** recomputed from the visible list. The friends list
  /// is one page of the inbox, so somebody with a long one has friends this
  /// screen never draws — and rebuilding the selection from what happens to be
  /// on screen would quietly revoke everybody past the page boundary the first
  /// time Done was tapped.
  late final Set<String> _selected = {...widget.initialSelection};

  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  List<ChatOtherUser> _matching(List<ChatOtherUser> friends) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return friends;
    return [
      for (final friend in friends)
        if ((friend.displayName ?? '').toLowerCase().contains(query)) friend,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sharingFriendsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Selected friends',
          style: AppTextStyles.title.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (_, _) => const _Message(
            title: "Couldn't load your friends",
            body: 'Go back and try again in a moment.',
          ),
          data: (friends) => friends.isEmpty
              ? const _Message(
                  title: 'No friends yet',
                  body: 'A friend is someone you have got talking to. Reply to '
                      'an opener, or send one, and they will show up here.',
                )
              : _list(friends),
        ),
      ),
      bottomNavigationBar: async.valueOrNull?.isEmpty ?? true
          ? null
          : _DoneBar(
              count: _selected.length,
              onDone: () => Navigator.pop(context, _selected.toList()),
            ),
    );
  }

  Widget _list(List<ChatOtherUser> friends) {
    final matching = _matching(friends);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Search friends',
              hintStyle: AppTextStyles.bodyMuted,
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: AppColors.iconMuted,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.iconMuted,
                      ),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                borderSide:
                    BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: matching.isEmpty
              ? const _Message(
                  title: 'Nobody by that name',
                  body: 'Only people you are vibing with can be picked.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: matching.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final friend = matching[index];
                    return _FriendRow(
                      friend: friend,
                      colorIndex: index,
                      selected: _selected.contains(friend.id),
                      onTap: () => _toggle(friend.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.colorIndex,
    required this.selected,
    required this.onTap,
  });

  final ChatOtherUser friend;
  final int colorIndex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = friend.displayName ?? 'Someone';

    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$name, can see your location' : name,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryTint : AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.inputBorder,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: friend.primaryPhotoUrl == null
                        ? avatarGradient(colorIndex)
                        : null,
                    image: friend.primaryPhotoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(friend.primaryPhotoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: friend.primaryPhotoUrl == null
                      ? Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: AppTextStyles.avatarInitial(17),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: 15,
                            color: selected
                                ? AppColors.primaryInk
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                      if (friend.isVerified) ...[
                        const SizedBox(width: 6),
                        const VerificationTick(size: 14),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _Check(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.inputBorder,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 14, color: AppColors.onAccent)
          : null,
    );
  }
}

/// The footer. Its label carries the count, so the consequence of leaving is
/// legible without scrolling back through the list to recount ticks.
class _DoneBar extends StatelessWidget {
  const _DoneBar({required this.count, required this.onDone});

  final int count;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.inputBorder)),
      ),
      child: SafeArea(
        top: false,
        // The Column is load-bearing — do not unwrap it.
        //
        // [RadiusButton] ends in a Container with an alignment, and a Container
        // with an alignment expands to fill *bounded* constraints. Every other
        // button in the app sits in a Column or a ListView, where the incoming
        // height is unbounded and it quietly shrink-wraps instead. A Scaffold
        // hands its `bottomNavigationBar` a maxHeight of the entire screen, so
        // straight in here the button grew to fill it and covered the friends
        // list behind a 2000 px slab of accent blue. Column(min) restores the
        // unbounded height the button is built for.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadiusButton(
              // Zero is a legitimate answer — it means nobody, and the setting
              // screen says so plainly rather than this button refusing to
              // save.
              label: count == 0 ? 'Save (nobody)' : 'Save ($count)',
              onPressed: onDone,
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 24),
      child: Column(
        children: [
          RadarMark(size: 76, color: AppColors.iconMuted),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

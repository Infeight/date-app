import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/selection_limits.dart';
import '../../../core/constants/tag_categories.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/tag_model.dart';
import '../../../providers/profile_provider.dart';
import '../../auth/widgets/onboarding_widgets.dart';
import '../../common/widgets/widgets.dart';

/// Post-onboarding profile edits. Both sheets write through
/// `PATCH /users/me/profile`, which is the only editable surface after the
/// funnel — onboarding endpoints are for the funnel itself.

/// Edit the bio. Returns true when saved.
Future<bool> showEditBioSheet(BuildContext context, String initial) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditBioSheet(initial: initial),
  );
  return saved ?? false;
}

/// Edit the "My vibe" personality tags. Returns true when saved.
Future<bool> showEditVibesSheet(
  BuildContext context,
  List<String> initial,
) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditVibesSheet(initial: initial),
  );
  return saved ?? false;
}

/// Rounded sheet chrome shared by both editors.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _EditBioSheet extends ConsumerStatefulWidget {
  const _EditBioSheet({required this.initial});

  final String initial;

  @override
  ConsumerState<_EditBioSheet> createState() => _EditBioSheetState();
}

class _EditBioSheetState extends ConsumerState<_EditBioSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(meProvider.notifier)
          .updateProfile(bio: _controller.text.trim());
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Edit bio',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            maxLength: 150,
            maxLines: 5,
            autofocus: true,
            style: TextStyle(fontSize: 14, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'Say something worth replying to...',
              hintStyle: TextStyle(color: AppColors.textGrey),
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OnboardingButton(
            label: 'Save',
            isLoading: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _EditVibesSheet extends ConsumerStatefulWidget {
  const _EditVibesSheet({required this.initial});

  final List<String> initial;

  @override
  ConsumerState<_EditVibesSheet> createState() => _EditVibesSheetState();
}

class _EditVibesSheetState extends ConsumerState<_EditVibesSheet> {
  // Trimmed to the cap: a profile that picked more before the limit existed
  // keeps its first few rather than opening this sheet unable to save.
  late Set<String> _selected = {
    ...widget.initial.take(SelectionLimits.vibes),
  };
  bool _isSaving = false;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(meProvider.notifier)
          .updateProfile(personalityTags: _selected.toList());
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsByCategoryProvider);

    return _SheetShell(
      title: 'My vibe',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pick the qualities that describe you. '
                  '${selectionHint(SelectionLimits.vibes)}.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SelectionCounter(
                count: _selected.length,
                max: SelectionLimits.vibes,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: SingleChildScrollView(
              child: tags.when(
                loading: () => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (err, _) => Text(
                  "Couldn't load the options. Please try again.",
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
                data: (grouped) => LimitedTagChipGroup(
                  tags: grouped[TagCategories.personality] ?? const <Tag>[],
                  selected: _selected,
                  max: SelectionLimits.vibes,
                  onChanged: (next) => setState(() => _selected = next),
                  onLimitReached: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          selectionLimitMessage(
                            'vibes',
                            SelectionLimits.vibes,
                          ),
                        ),
                      ),
                    ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          OnboardingButton(
            label: 'Save',
            isLoading: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

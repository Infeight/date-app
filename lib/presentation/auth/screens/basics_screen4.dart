import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/media_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../widgets/onboarding_widgets.dart';
import 'basics_screen5.dart';

/// One picked-but-not-yet-uploaded image. Bytes are read up front so the same
/// code path works on web and mobile.
class _PickedPhoto {
  _PickedPhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Step 8 · "Show yourself" — photo upload.
///
/// Uploads go direct to object storage via a presigned URL, which can be
/// unreachable from the device depending on how storage is deployed. That must
/// never trap the user in onboarding, so a failed upload is reported and the
/// step is still completed via `PATCH /onboarding/photo` — photos can be added
/// later from the profile screen.
class BasicsScreen4 extends ConsumerStatefulWidget {
  const BasicsScreen4({super.key});

  /// Stable key per upload slot, so the grid's alignment can be asserted in
  /// tests rather than eyeballed.
  static Key photoSlotKey(int index) => ValueKey('photo-slot-$index');

  @override
  ConsumerState<BasicsScreen4> createState() => _BasicsScreen4State();
}

class _BasicsScreen4State extends ConsumerState<BasicsScreen4> {
  static const int _slots = 5;

  final List<_PickedPhoto?> _photos = List.filled(_slots, null);
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  bool get _hasAnyPhoto => _photos.any((p) => p != null);

  /// Only the MIME types the API accepts; anything else is sent as JPEG, which
  /// is what image_picker produces once `imageQuality` re-encodes.
  String _contentTypeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickPhoto(int index) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photos[index] = _PickedPhoto(
          bytes: bytes,
          contentType: _contentTypeFor(file.name),
        );
      });
    } catch (_) {
      if (mounted) {
        _showSnack('Could not open the gallery. Please try again.');
      }
    }
  }

  void _removePhoto(int index) => setState(() => _photos[index] = null);

  Future<void> _onContinue() async {
    setState(() => _isLoading = true);
    try {
      final media = ref.read(mediaRepositoryProvider);
      final picked = _photos.whereType<_PickedPhoto>().toList();

      var uploaded = 0;
      // Rejections are counted apart from failures. Both mean "the photo isn't
      // up", but only one of them is worth retrying, and telling somebody to
      // try again on a photo moderation has already refused sends them round a
      // loop that cannot end.
      var rejected = 0;
      String? firstFailure;
      String? rejectionMessage;
      String? stepError;
      for (final photo in picked) {
        final result = await media.uploadPhoto(
          bytes: photo.bytes,
          contentType: photo.contentType,
          type: MediaKind.publicPhoto,
        );
        if (result.succeeded) {
          uploaded++;
        } else if (result.wasRejected) {
          rejected++;
          rejectionMessage ??= result.failureReason;
        } else {
          firstFailure ??= result.failureReason;
        }
      }

      // A successful upload already completes step 8 server-side; this call is
      // idempotent and is the only thing that finishes the step when every
      // upload failed or nothing was added. Never block on it — an older
      // backend without this route must not strand the user on this screen.
      try {
        final me = await ref
            .read(onboardingRepositoryProvider)
            .completePhotoStep(skipped: uploaded == 0);
        ref.read(meProvider.notifier).setMe(me);
      } on AppException catch (e) {
        stepError = e.message;
      }
      ref.invalidate(myMediaProvider);

      if (!mounted) return;
      if (stepError != null && uploaded == 0) {
        _showSnack("Couldn't save this step: $stepError");
      } else if (rejected > 0 && uploaded == 0) {
        // Everything the user picked was refused. Say so in the server's own
        // words — "try again later" would be actively misleading here.
        _showSnack(rejectionMessage ??
            "Those photos don't meet our content guidelines. "
                'You can add different ones from your profile.');
      } else if (rejected > 0) {
        _showSnack(
          'Added $uploaded of ${picked.length}. '
          "${rejected == 1 ? 'One photo' : '$rejected photos'} didn't meet "
          'our content guidelines.',
        );
      } else if (picked.isNotEmpty && uploaded == 0) {
        _showSnack(
          "Photos couldn't be uploaded right now — you can add them later "
          'from your profile.',
        );
      } else if (firstFailure != null) {
        _showSnack('Uploaded $uploaded of ${picked.length} photos.');
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BasicsScreen5()),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            OnboardingHeader(
              step: 8,
              label: 'IDENTITY',
              trailing: _isLoading
                  ? null
                  : GestureDetector(
                      onTap: _onContinue,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Show yourself',
                      style: AppTextStyles.display,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Upload up to 5 photos. You can always add more later.',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),

                    const SizedBox(height: 24),

                    _photoGrid(),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.primary.withValues(alpha:0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 16, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Keep photos clear and respectful — no nudity.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 16, color: AppColors.textGrey),
                        const SizedBox(width: 6),
                        // Unconstrained text in a Row overflows once the system
                        // font scale goes up; let it take the remaining width
                        // instead.
                        Expanded(
                          child: Text(
                            'Tips for a better match',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    _tipCard(
                      icon: Icons.wb_sunny_outlined,
                      title: 'Natural Lighting',
                      subtitle:
                          'Daylight softens features and creates a more authentic presence.',
                    ),
                    const SizedBox(height: 10),
                    _tipCard(
                      icon: Icons.remove_red_eye_outlined,
                      title: 'Eyes Visible',
                      subtitle:
                          'Avoid heavy sunglasses. Direct eye contact increases verification speed.',
                    ),

                    const SizedBox(height: 32),

                    OnboardingButton(
                      label: _hasAnyPhoto ? 'Continue' : 'Continue without photos',
                      isLoading: _isLoading,
                      onPressed: _onContinue,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The five upload slots on one 3-column grid: the primary spans 2×2, the
  /// next two stack beside it, and the last two sit underneath.
  ///
  /// Every size is derived from the measured width, so the column edges line up
  /// down the whole grid and the tiles keep their shape on any screen. The
  /// previous version mixed flex ratios (5:4 on top, 1:1 below) with hardcoded
  /// heights (220 / 105 / 100), so nothing aligned and the tiles distorted when
  /// the screen got narrower.
  Widget _photoGrid() {
    const gap = 10.0;
    // Portrait cells, a touch taller than they are wide.
    const cellAspect = 1.25;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - gap * 2) / 3;
        final cellHeight = cellWidth * cellAspect;
        // The primary covers two cells plus the gap between them, on both axes.
        final primarySide = cellWidth * 2 + gap;
        final primaryHeight = cellHeight * 2 + gap;

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: primarySide,
                  height: primaryHeight,
                  child: _photoTile(index: 0, isPrimary: true),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: cellWidth,
                  height: primaryHeight,
                  child: Column(
                    // Stretch, or the tiles collapse to their icon's intrinsic
                    // width — a Column centres children by default and passes
                    // loose horizontal constraints.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: cellHeight,
                        child: _photoTile(index: 1),
                      ),
                      const SizedBox(height: gap),
                      SizedBox(
                        height: cellHeight,
                        child: _photoTile(index: 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: gap),
            Row(
              children: [
                SizedBox(
                  width: cellWidth,
                  height: cellHeight,
                  child: _photoTile(index: 3),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: cellWidth,
                  height: cellHeight,
                  child: _photoTile(index: 4),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _photoTile({required int index, bool isPrimary = false}) {
    final photo = _photos[index];

    return GestureDetector(
      key: BasicsScreen4.photoSlotKey(index),
      onTap: () => photo != null ? _removePhoto(index) : _pickPhoto(index),
      child: Container(
        // Sized by the grid cell, never by a hardcoded height.
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: photo != null ? AppColors.primary : AppColors.inputBorder,
            width: photo != null ? 1.5 : 1,
          ),
        ),
        child: photo == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isPrimary) ...[
                    Icon(Icons.add_a_photo_outlined,
                        size: 28, color: AppColors.textGrey),
                    const SizedBox(height: 8),
                    Text(
                      'Primary Photo',
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                  ] else
                    Icon(Icons.add,
                        size: 22, color: AppColors.primary.withValues(alpha:0.6)),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(
                      photo.bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.primary.withValues(alpha:0.12),
                        child: Icon(Icons.broken_image_outlined,
                            color: AppColors.textGrey),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _removePhoto(index),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha:0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 14, color: AppColors.onImage),
                      ),
                    ),
                  ),
                  if (index == 0)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha:0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Primary',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.onImage,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _tipCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

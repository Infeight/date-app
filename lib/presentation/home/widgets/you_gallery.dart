import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/media_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';

class YouGallery extends ConsumerStatefulWidget {
  const YouGallery({super.key, required this.primaryPhotoId});
  final String? primaryPhotoId;

  @override
  ConsumerState<YouGallery> createState() => _YouGalleryState();
}

class _YouGalleryState extends ConsumerState<YouGallery> {
  bool _isUploading = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// My public photos, profile photo first so it reads as the main one.
  List<MediaAsset> _publicPhotos(List<MediaAsset>? media) {
    final photos =
        (media ?? const <MediaAsset>[]).where((m) => m.isPublicPhoto).toList();
    photos.sort((a, b) {
      if (a.id == widget.primaryPhotoId) return -1;
      if (b.id == widget.primaryPhotoId) return 1;
      return 0;
    });
    return photos;
  }

  /// Pick and upload one gallery photo. Upload failures surface as a message
  /// rather than an exception — object storage may be unreachable.
  Future<void> addPhoto() async {
    if (_isUploading) return;

    // The server rejects the 6th photo, so say so here rather than letting the
    // upload run and fail — and point at the way out.
    final current = _publicPhotos(ref.read(myMediaProvider).valueOrNull).length;
    if (current >= kMaxPublicPhotos) {
      _snack('You can have $kMaxPublicPhotos photos. '
          'Tap one to delete it, then add a new one.');
      return;
    }

    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      final contentType = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';

      setState(() => _isUploading = true);
      final result = await ref.read(mediaRepositoryProvider).uploadPhoto(
            bytes: bytes,
            contentType: contentType,
            type: MediaKind.publicPhoto,
          );

      if (!mounted) return;
      if (result.succeeded) {
        ref.invalidate(myMediaProvider);
        _snack('Photo added');
      } else if (result.wasRejected) {
        // Moderation refused it. Say what the server said and do NOT invite a
        // retry — the same file will be refused again, and the photo is
        // already gone from storage.
        _snack(result.failureReason ??
            "This photo doesn't meet our content guidelines.");
      } else {
        _snack("Photo couldn't be uploaded. Please try again.");
      }
    } on AppException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = _publicPhotos(ref.watch(myMediaProvider).valueOrNull);
    final atCap = photos.length >= kMaxPublicPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The header lives here rather than on the screen so that "Add photo"
        // and the "+" tile are the same call — they were two copies before.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('GALLERY', style: AppTextStyles.label),
            Semantics(
              button: true,
              label: 'Add photo',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: addPhoto,
                child: Text(
                  'Add photo',
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _grid(photos, atCap),
      ],
    );
  }

  Widget _grid(List<MediaAsset> photos, bool atCap) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.8,
      children: [
        for (final photo in photos)
          _photoTile(photo, isPrimary: photo.id == widget.primaryPhotoId),
        if (!atCap) _addTile(),
      ],
    );
  }

  Widget _photoTile(MediaAsset photo, {required bool isPrimary}) {
    return GestureDetector(
      onTap: () => _showPhotoActions(photo, isPrimary: isPrimary),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photo.url,
              fit: BoxFit.cover,
              // Presigned URLs expire, and photos uploaded before storage was
              // configured point at keys that no longer exist. Show a quiet
              // placeholder instead of the browser's broken-image glyph.
              errorBuilder: (_, _, _) => Container(
                color: AppColors.inputBorder,
                child: Center(
                  child: Icon(Icons.broken_image_outlined,
                      size: 22, color: AppColors.textGrey),
                ),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      color: AppColors.inputBorder,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
            ),
            if (isPrimary)
              Positioned(
                left: 6,
                bottom: 6,
                child: _tag('PROFILE', AppColors.primary),
              )
            else if (photo.isPending)
              Positioned(
                left: 6,
                bottom: 6,
                child: _tag('PENDING', Colors.black54),
              ),
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.more_horiz, size: 18, color: AppColors.onImage),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.onImage,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _addTile() {
    return GestureDetector(
      onTap: addPhoto,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Center(
          child: _isUploading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Icon(Icons.add, size: 24, color: AppColors.textGrey),
        ),
      ),
    );
  }

  /// Set-as-profile / delete. Deleting is the way to make room once the gallery
  /// is full, so the sheet is also where the cap gets resolved.
  Future<void> _showPhotoActions(
    MediaAsset photo, {
    required bool isPrimary,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (!isPrimary)
              ListTile(
                leading: Icon(Icons.account_circle_outlined,
                    color: AppColors.textDark),
                title: const Text('Make this my profile photo'),
                subtitle: photo.isApproved
                    ? null
                    : const Text('Available once moderation approves it'),
                enabled: photo.isApproved,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setPrimary(photo);
                },
              )
            else
              ListTile(
                leading: Icon(Icons.check_circle, color: AppColors.primary),
                title: const Text('This is your profile photo'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete photo',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _deletePhoto(photo);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPrimary(MediaAsset photo) async {
    try {
      await ref.read(mediaRepositoryProvider).setPrimary(photo.id);
      // The primary id lives on the user, the badge on the media list.
      await ref.read(meProvider.notifier).refresh();
      ref.invalidate(myMediaProvider);
      _snack('Profile photo updated');
    } on AppException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _deletePhoto(MediaAsset photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Delete photo?'),
        content: Text(
          'This removes it from your profile and from storage. '
          'It cannot be undone.',
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(mediaRepositoryProvider).delete(photo.id);
      ref.invalidate(myMediaProvider);
      // Deleting the profile photo clears the pointer on the user.
      await ref.read(meProvider.notifier).refresh();
      _snack('Photo deleted');
    } on AppException catch (e) {
      _snack(e.message);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../core/utils/utils.dart';
import '../../../data/services/auth_service.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/location_sharing_card.dart';
import '../widgets/profile_edit_panel.dart';
import '../widgets/profile_edit_sheets.dart';
import '../widgets/you_gallery.dart';
import '../widgets/you_header.dart';
import './blocked_accounts_screen.dart';
import './premium_screen.dart';

class YouScreen extends ConsumerStatefulWidget {
  const YouScreen({super.key});

  @override
  ConsumerState<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends ConsumerState<YouScreen> {
  Future<void> _onEditBio(String bio) async {
    final saved = await showEditBioSheet(context, bio);
    if (saved && mounted) _snack('Bio updated');
  }

  Future<void> _onEditVibes(List<String> vibes) async {
    final saved = await showEditVibesSheet(context, vibes);
    if (saved && mounted) _snack('Vibe updated');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _onSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Sign Out', style: TextStyle(color: AppColors.textDark)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign Out', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(pushRegistrarProvider).stop();
      await AuthService().signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  Future<void> _onDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: Text(
          'This will permanently delete your account and all data. This cannot be undone.',
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(pushRegistrarProvider).stop();
      try {
        await ref.read(profileRepositoryProvider).deleteAccount();
      } catch (_) {}
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    if (me == null) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final stats = ref.watch(myProfileStatsProvider).valueOrNull;
    final friends = ref.watch(activeConversationCountProvider);
    final tagLabels = ref.watch(tagLabelsProvider).valueOrNull ?? const {};

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Wordmark(),
          ),

          YouHeader(me: me, avatarUrl: _primaryPhotoUrl(me.primaryPhotoId)),

          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: LocationSharingCard(),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ProfileMetricsRow(
              visits: stats?.profileViews,
              likes: stats?.likesReceived,
              friends: friends,
            ),
          ),

          const SizedBox(height: 26),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: YouGallery(primaryPhotoId: me.primaryPhotoId),
          ),

          const SizedBox(height: 26),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _card(
              label: 'MY VIBE',
              onEdit: () => _onEditVibes(me.profile.personalityTags),
              child: me.profile.personalityTags.isEmpty
                  ? Text('Nothing picked yet.', style: AppTextStyles.caption)
                  : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final vibe in me.profile.personalityTags)
                    TagPill(
                      label: tagLabels[vibe] ?? humanizeSlug(vibe),
                      tone: TagTone.neutral,
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _card(
              label: 'BIO',
              onEdit: () => _onEditBio(me.profile.bio ?? ''),
              child: Text(
                (me.profile.bio ?? '').trim().isEmpty
                    ? 'Say something worth replying to.'
                    : me.profile.bio!,
                style: AppTextStyles.body.copyWith(
                  height: 1.5,
                  color: (me.profile.bio ?? '').trim().isEmpty
                      ? AppColors.textGrey
                      : AppColors.textDark,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ProfileEditPanel(me: me),
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _VerificationCard(isVerified: me.verified),
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _PremiumCard(isPremium: me.premium.isActive),
          ),

          const SizedBox(height: 14),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _DarkModeTile(),
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _menuTile(
              icon: Icons.block_outlined,
              label: 'Blocked accounts',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockedAccountsScreen()),
              ),
            ),
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _menuTile(
              icon: Icons.logout_outlined,
              label: 'Sign Out',
              onTap: _onSignOut,
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: GestureDetector(
              onTap: _onDeleteAccount,
              child: Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          spacerH(80),
        ],
      ),
    );
  }

  String? _primaryPhotoUrl(String? primaryId) {
    if (primaryId == null) return null;
    for (final asset in ref.watch(myMediaProvider).valueOrNull ?? const []) {
      if (asset.id == primaryId) return asset.url;
    }
    return null;
  }

  Widget _card({
    required String label,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.inputBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Semantics(
                button: true,
                label: 'Edit ${label.toLowerCase()}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit_outlined,
                        size: 14, color: AppColors.textGrey),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.textDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}

class _DarkModeTile extends ConsumerWidget {
  const _DarkModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = isDarkMode(context, ref.watch(themeModeProvider));

    return Semantics(
      toggled: dark,
      label: 'Dark mode',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 18,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Dark mode',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch(
              value: dark,
              activeThumbColor: AppColors.primary,
              onChanged: (on) =>
                  ref.read(themeModeProvider.notifier).toggle(dark: on),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (isVerified ? AppColors.ok : Colors.black)
                .withValues(alpha: isVerified ? 0.12 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isVerified
              ? AppColors.ok.withValues(alpha: 0.35)
              : AppColors.inputBorder.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: isVerified
                  ? LinearGradient(
                colors: [
                  AppColors.ok.withValues(alpha: 0.2),
                  AppColors.ok.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: isVerified ? null : AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_outlined,
              size: 20,
              color: isVerified ? AppColors.ok : AppColors.iconMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ACCOUNT VERIFICATION',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 10,
                      letterSpacing: 1,
                    )),
                const SizedBox(height: 3),
                Text(
                  isVerified ? 'Identity Verified' : 'Not verified yet',
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isVerified
                      ? 'Your profile is trusted and visible to others.'
                      : 'Verify to unlock the full experience.',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (isVerified) const VerificationTick(size: 22),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1F63), Color(0xFF1A123B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.premium.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.premium,
                      AppColors.premium.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPremium ? Icons.workspace_premium : Icons.radio_button_checked,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'cozune Premium',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onImage,
                  ),
                ),
              ),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isPremium
                ? 'Unlimited radius, every filter, and no ads.'
                : 'See everyone nearby, filter everything, and drop the ads.',
            style: const TextStyle(
              fontSize: 13.5,
              color: Colors.white60,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onImage,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: Text(
                isPremium ? 'Manage Subscription' : 'See what you get',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.premiumDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
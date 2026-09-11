import 'dart:async';

import 'package:dating_app/core/extensions/padding_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/ads/banner/banner_ad_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/screen_guard.dart';
import '../../../data/models/message_model.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../common/widgets/widgets.dart';
import '../models/profile_seed.dart';
import '../widgets/chat_actions_menu.dart';
import '../widgets/message_limit_paywall.dart';
import './profile_detail_sheet.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String? conversationId;

  final String userId;
  final String userName;
  final int? userAge;
  final String? photoUrl;
  final int colorIndex;

  final ChatOtherUser? otherUser;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.userName,
    this.userAge,
    this.photoUrl,
    this.colorIndex = 0,
    this.otherUser,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen>
    with ScreenGuardMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _sending = false;

  StateController<String?>? _activeClaim;

  String? _convId;

  String get _otherId => widget.userId;

  @override
  void initState() {
    super.initState();
    _convId = widget.conversationId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
  }

  Future<void> _onOpen() async {
    if (_convId == null) {
      final existing = await _findExistingConversation();
      if (!mounted) return;
      if (existing == null) return;
      setState(() => _convId = existing);
    }
    if (!mounted) return;

    final convId = _convId!;

    _activeClaim = ref.read(activeConversationProvider.notifier);
    _activeClaim!.state = convId;

    final chat = ref.read(chatServiceProvider);
    _subs.add(chat.messages.listen((incoming) {
      if (!_isLive(incoming.conversationId)) return;
      ref.read(messagesProvider(convId).notifier).addIncoming(incoming.message);
      ref.read(chatActionsProvider).markRead(convId);
      _scrollToBottom();
    }));
    _subs.add(chat.updates.listen((update) {
      if (!_isLive(update.conversationId)) return;
      ref.read(messagesProvider(convId).notifier).replace(update.message);
    }));
    _subs.add(chat.reads.listen((receipt) {
      if (!_isLive(receipt.conversationId)) return;
      ref.read(messagesProvider(convId).notifier).markMineRead();
    }));
    _subs.add(chat.typing.listen((event) {
      if (!_isLive(event.conversationId)) return;
      setState(() => _isTyping = true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }));

    if (!mounted) return;
    try {
      await ref.read(chatActionsProvider).markRead(convId);
    } catch (_) {}
  }

  Future<String?> _findExistingConversation() async {
    try {
      return await ref.read(chatActionsProvider).conversationIdWith(_otherId);
    } catch (_) {
      return null;
    }
  }

  void _releaseActiveClaim() {
    final claim = _activeClaim;
    _activeClaim = null;
    if (claim == null) return;
    Future<void>(() {
      if (claim.mounted && claim.state == _convId) claim.state = null;
    });
  }

  bool _isLive(String conversationId) =>
      mounted && _convId != null && conversationId == _convId;

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _releaseActiveClaim();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    _messageController.clear();
    setState(() => _sending = true);
    try {
      final convId = _convId;
      if (convId == null) {
        final result =
        await ref.read(chatActionsProvider).open(_otherId, text);
        if (!mounted) return;
        setState(() => _convId = result.conversation.id);
        await _onOpen();
      } else {
        await ref.read(chatActionsProvider).send(convId, text);
      }
      _scrollToBottom();
      if (mounted) {
        showRadiusToast(context, 'Message sent', tone: ToastTone.success);
      }
    } on EntitlementRequiredException catch (gate) {
      _messageController.text = text;
      if (mounted) showMessageLimitPaywall(context, gate: gate);
    } on AppException catch (e) {
      _messageController.text = text;
      if (mounted) {
        showRadiusToast(context, e.message, tone: ToastTone.error);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onInputChanged(String _) {
    final convId = _convId;
    if (convId == null) return;
    ref
        .read(chatServiceProvider)
        .sendTyping(toUserId: _otherId, conversationId: convId);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final convId = _convId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: convId == null
                  ? _EmptyThread(name: widget.userName)
                  : ref.watch(messagesProvider(convId)).when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
                error: (err, _) => Center(
                  child: Text(
                    "Couldn't load messages.\n$err",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ),
                data: (messages) => _buildMessageList(messages),
              ),
            ),
            if (_isTyping) _buildTypingIndicator(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  void _openProfile() {
    showRadiusSheet<void>(
      context: context,
      builder: (_) => ProfileDetailSheet(
        userId: _otherId,
        seed: ProfileSeed(
          name: widget.userName,
          age: widget.userAge,
          photoUrl: widget.photoUrl,
          colorIndex: widget.colorIndex,
        ),
      ),
    );
  }

  Future<void> _openActions() async {
    final convId = _convId;
    if (convId == null) {
      showRadiusToast(context, 'Say something first');
      return;
    }
    final result = await showChatActionsMenu(
      context,
      conversationId: convId,
      userId: _otherId,
      userName: widget.userName,
      isMuted: _isMuted,
    );
    if (!mounted || result == null) return;
    const stayOpen = {
      ChatActionResult.reported,
      ChatActionResult.muted,
      ChatActionResult.unmuted,
    };
    if (!stayOpen.contains(result)) Navigator.pop(context);
  }

  bool get _isMuted {
    final convId = _convId;
    if (convId == null) return false;
    for (final state in const [null, 'vibing', 'new_energy']) {
      final list = ref.read(conversationsProvider(state)).valueOrNull;
      if (list == null) continue;
      for (final c in list) {
        if (c.id == convId) return c.muted;
      }
    }
    return false;
  }

  Widget _buildTopBar() {
    final name = widget.userName;
    final online = ref.watch(presenceProvider)[_otherId] ??
        widget.otherUser?.isOnline ??
        false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back, color: AppColors.textDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              button: true,
              label: "Open $name's profile",
              excludeSemantics: true,
              child: InkWell(
                onTap: _openProfile,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: widget.photoUrl == null
                              ? avatarGradient(widget.colorIndex)
                              : null,
                          image: widget.photoUrl != null
                              ? DecorationImage(
                            image: NetworkImage(widget.photoUrl!),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: widget.photoUrl == null
                            ? Center(
                          child: Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.avatarInitial(17),
                          ),
                        )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.userAge != null
                                  ? '$name, ${widget.userAge}'
                                  : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyStrong.copyWith(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                fontVariations: const [
                                  FontVariation('wght', 700),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            _StatusFlags(
                              online: online,
                              other: widget.otherUser,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _topBarIcon(Icons.more_vert, _openActions),
        ],
      ),
    );
  }

  Widget _topBarIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.textDark),
      ),
    );
  }

  Widget _buildMessageList(List<Message> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'Say hello 👋',
          style: TextStyle(color: AppColors.textGrey),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) return _buildDateHeader('TODAY');
        return _buildMessageBubble(messages[index - 1]);
      },
    );
  }

  Widget _buildDateHeader(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textGrey,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message msg) {
    final isMine = msg.fromMe;
    final deleted = msg.deleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment:
        isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Semantics(
                  button: !deleted,
                  label: deleted ? null : 'Message options',
                  child: GestureDetector(
                    onLongPress: deleted ? null : () => _openMessageActions(msg),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: deleted
                            ? AppColors.background
                            : (isMine ? AppColors.primary : AppColors.card),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMine ? 18 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 18),
                        ),
                        border: isMine && !deleted
                            ? null
                            : Border.all(color: AppColors.inputBorder),
                      ),
                      child: deleted
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.block,
                            size: 13,
                            color: AppColors.textGrey,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              msg.body,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.textGrey,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      )
                          : Text(
                        msg.body,
                        style: TextStyle(
                          fontSize: 14,
                          color: isMine
                              ? AppColors.onAccent
                              : AppColors.textDark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Row(
              mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  _formatTime(msg.sentAt),
                  style: TextStyle(fontSize: 10, color: AppColors.textGrey),
                ),
                if (msg.edited) ...[
                  const SizedBox(width: 4),
                  Text(
                    'edited',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textGrey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (isMine && !deleted) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.read ? Icons.done_all : Icons.check,
                    size: 12,
                    color: msg.read ? Colors.blue : AppColors.textGrey,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _openMessageActions(Message msg) async {
    final isPremium =
        ref.read(meProvider).valueOrNull?.premium.isActive ?? false;

    final action = await showRadiusSheet<_MessageAction>(
      context: context,
      builder: (_) => _MessageActionsSheet(
        canModify: msg.fromMe,
        isPremium: isPremium,
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: msg.body));
        if (mounted) showRadiusToast(context, 'Copied', tone: ToastTone.success);
      case _MessageAction.edit:
        await _editMessage(msg);
      case _MessageAction.delete:
        await _deleteMessage(msg);
      case _MessageAction.upgrade:
        if (mounted) {
          showRadiusToast(
            context,
            'Editing and deleting messages are premium features',
          );
        }
    }
  }

  Future<void> _editMessage(Message msg) async {
    final convId = _convId;
    if (convId == null) return;

    final next = await showRadiusSheet<String>(
      context: context,
      builder: (_) => _EditMessageSheet(original: msg.body),
    );
    final trimmed = next?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == msg.body) return;

    try {
      await ref
          .read(chatActionsProvider)
          .editMessage(convId, msg.id, trimmed);
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    }
  }

  Future<void> _deleteMessage(Message msg) async {
    final convId = _convId;
    if (convId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete this message?',
          style: AppTextStyles.title.copyWith(fontSize: 18),
        ),
        content: Text(
          'It disappears for both of you. ${widget.userName} will see that a '
              'message was deleted, in the place it was.',
          style: AppTextStyles.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyStrong
                  .copyWith(color: AppColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: AppTextStyles.bodyStrong.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await ref.read(chatActionsProvider).deleteMessage(convId, msg.id);
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    }
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Text(
              '${widget.userName} is typing...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textGrey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.inputBorder, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerAdWidget().paddingOnly(bottom: 10.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    onChanged: _onInputChanged,
                    style: TextStyle(fontSize: 14, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Say something nice...',
                      hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        color: AppColors.onAccent, strokeWidth: 2),
                  )
                      : Icon(Icons.send, color: AppColors.onAccent, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

enum _MessageAction { copy, edit, delete, upgrade }

class _MessageActionsSheet extends StatelessWidget {
  const _MessageActionsSheet({
    required this.canModify,
    required this.isPremium,
  });

  final bool canModify;

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return RadiusSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MessageActionRow(
            icon: Icons.copy_outlined,
            label: 'Copy',
            onTap: () => Navigator.pop(context, _MessageAction.copy),
          ),
          if (canModify) ...[
            _MessageActionRow(
              icon: Icons.edit_outlined,
              label: 'Edit',
              locked: !isPremium,
              onTap: () => Navigator.pop(
                context,
                isPremium ? _MessageAction.edit : _MessageAction.upgrade,
              ),
            ),
            _MessageActionRow(
              icon: Icons.delete_outline,
              label: 'Delete',
              danger: true,
              locked: !isPremium,
              onTap: () => Navigator.pop(
                context,
                isPremium ? _MessageAction.delete : _MessageAction.upgrade,
              ),
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _MessageActionRow extends StatelessWidget {
  const _MessageActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.primary : AppColors.textDark;

    return Semantics(
      button: true,
      label: locked ? '$label, premium' : label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, size: 21, color: locked ? AppColors.iconMuted : color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 15,
                      color: locked ? AppColors.iconMuted : color,
                    ),
                  ),
                ),
                if (locked)
                  Icon(
                    Icons.lock_outline,
                    size: 15,
                    color: AppColors.iconMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditMessageSheet extends StatefulWidget {
  const _EditMessageSheet({required this.original});

  final String original;

  @override
  State<_EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends State<_EditMessageSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.original,
  )..selection = TextSelection.collapsed(offset: widget.original.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RadiusSheet(
      title: 'Edit message',
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'They will see that this message was edited.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.inputBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                maxLength: 4000,
                style: AppTextStyles.body,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 14),
            RadiusButton(
              label: 'Save',
              onPressed: () =>
                  Navigator.pop(context, _controller.text.trim()),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadarMark(size: 84, color: AppColors.iconMuted),
            const SizedBox(height: 18),
            Text(
              'You matched with $name',
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Neither of you has said anything yet. Someone has to go first.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFlags extends StatelessWidget {
  const _StatusFlags({required this.online, this.other});

  final bool online;
  final ChatOtherUser? other;

  @override
  Widget build(BuildContext context) {
    if (other?.isDeactivated ?? false) {
      return const _Flag(
        icon: Icons.person_off_outlined,
        label: 'Account deactivated',
        tone: _FlagTone.muted,
      );
    }

    final city = other?.city;
    final activity = online ? 'Active now' : other?.activityLabel;

    return Row(
      children: [
        if (city != null && city.isNotEmpty) ...[
          Flexible(
            child: _Flag(
              icon: Icons.location_on_outlined,
              label: city,
              tone: _FlagTone.muted,
            ),
          ),
          if (activity != null) const SizedBox(width: 10),
        ],
        if (activity != null)
          Flexible(
            child: _Flag(
              icon: Icons.circle,
              label: activity,
              tone: online ? _FlagTone.live : _FlagTone.muted,
            ),
          ),
      ],
    );
  }
}

enum _FlagTone { muted, live }

class _Flag extends StatelessWidget {
  const _Flag({required this.icon, required this.label, required this.tone});

  final IconData icon;
  final String label;
  final _FlagTone tone;

  @override
  Widget build(BuildContext context) {
    final color =
    tone == _FlagTone.live ? AppColors.ok : AppColors.textGrey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: tone == _FlagTone.live ? 7 : 11, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontSize: 11, color: color),
          ),
        ),
      ],
    );
  }
}
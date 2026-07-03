// 論壇文章詳細頁（含留言串）

import 'package:flutter/material.dart';

import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import '../../services/vocpass_auth_service.dart';
import 'forum_report_sheet.dart';
import 'forum_user_posts_screen.dart';
import 'forum_widgets.dart';

class ForumPostDetailScreen extends StatefulWidget {
  final ForumPost post;
  final ForumAdminInfo? schoolAdmin;
  final ForumAdminInfo? vocPassAdmin;

  const ForumPostDetailScreen({
    super.key,
    required this.post,
    this.schoolAdmin,
    this.vocPassAdmin,
  });

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  late ForumPost _post;
  final _messages = <ForumMessage>[];
  final _replyCtrl = TextEditingController();

  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _sending = false;
  bool _replyAnonymous = false;
  String? _error;

  String? get _currentUserID => VocPassAuthService.instance.currentUser?.id;
  bool get _isLoggedIn => VocPassAuthService.instance.isLoggedIn;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadMessages(reset: true);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }
    try {
      final data = await ForumService.instance
          .fetchMessages(postID: _post.likeTargetID, page: reset ? 1 : _page);
      if (!mounted) return;
      setState(() {
        if (reset) _messages.clear();
        _messages.addAll(data.forums);
        _totalPages = data.totalPages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() {
      _loadingMore = true;
      _page += 1;
    });
    await _loadMessages(reset: false);
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _togglePostLike() async {
    if (!_requireLogin()) return;
    final userID = _currentUserID;
    if (userID == null) return;
    final liked = _post.isLikedBy(userID);
    setState(() => _post = _post.copyWithLikes(userID, liked: !liked));
    try {
      await ForumService.instance
          .setPostLike(postID: _post.likeTargetID, liked: !liked);
    } catch (e) {
      if (!mounted) return;
      setState(() => _post = _post.copyWithLikes(userID, liked: liked));
      _showError(e);
    }
  }

  Future<void> _toggleMessageLike(ForumMessage message) async {
    if (!_requireLogin()) return;
    final userID = _currentUserID;
    if (userID == null) return;
    final liked = message.isLikedBy(userID);
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index < 0) return;
    setState(() => _messages[index] = message.copyWithLikes(userID, liked: !liked));
    try {
      await ForumService.instance
          .setMessageLike(messageID: message.id, liked: !liked);
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages[index] = message.copyWithLikes(userID, liked: liked));
      _showError(e);
    }
  }

  Future<void> _sendReply() async {
    final content = _replyCtrl.text.trim();
    if (content.isEmpty) return;
    if (!_requireLogin()) return;
    setState(() => _sending = true);
    try {
      await ForumService.instance.createMessage(
        postID: _post.likeTargetID,
        content: content,
        anonymous: _replyAnonymous,
      );
      _replyCtrl.clear();
      if (mounted) FocusScope.of(context).unfocus();
      await _loadMessages(reset: true);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await _confirm('確定刪除這篇文章？');
    if (!confirmed) return;
    try {
      await ForumService.instance.deletePost(_post.likeTargetID);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteMessage(ForumMessage message) async {
    final confirmed = await _confirm('確定刪除這則留言？');
    if (!confirmed) return;
    try {
      await ForumService.instance.deleteMessage(message.id);
      if (mounted) setState(() => _messages.removeWhere((m) => m.id == message.id));
    } catch (e) {
      _showError(e);
    }
  }

  bool _requireLogin() {
    if (_isLoggedIn) return true;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('請先登入 VocPass 帳號')));
    return false;
  }

  Future<bool> _confirm(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.toString())));
  }

  ForumBadge? _badgeFor(String? userID) => badgeForUser(
        userID: userID,
        schoolAdmin: widget.schoolAdmin,
        vocPassAdmin: widget.vocPassAdmin,
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('文章'),
          actions: [_buildPostMenu()],
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadMessages(reset: true),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 200) {
                      _loadMore();
                    }
                    return false;
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildPostHeader(),
                      const Divider(height: 32),
                      Text('留言 (${_messages.length})',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        )
                      else if (_messages.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('還沒有留言，搶頭香！',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      else
                        ..._messages.map(_buildMessageTile),
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            _buildReplyBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostMenu() {
    final isOwner = _post.user?.id != null && _post.user?.id == _currentUserID;
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'report') {
          showForumReportSheet(context, forumPostID: _post.likeTargetID);
        } else if (value == 'delete') {
          _deletePost();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'report',
          child: ListTile(
            leading: Icon(Icons.flag_outlined),
            title: Text('檢舉文章'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (isOwner)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('刪除文章', style: TextStyle(color: Colors.red)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Widget _buildPostHeader() {
    final user = _post.user;
    final anonymous = _post.anonymous || user == null;
    final badge = anonymous ? null : _badgeFor(user.id);
    final liked = _post.isLikedBy(_currentUserID);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ForumAvatar(
              url: anonymous ? null : user.avatarURL,
              fallbackText: anonymous ? '匿' : user.displayName,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: _authorName(
                          anonymous: anonymous,
                          user: user,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        ForumBadgeChip(badge: badge),
                      ],
                    ],
                  ),
                  Text(forumRelativeTime(_post.created),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            if (_post.pin)
              const Icon(Icons.push_pin, size: 18, color: Colors.orange),
          ],
        ),
        const SizedBox(height: 12),
        Text(_post.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (_post.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _post.tags.map((t) => ForumTagBadge(tag: t)).toList(),
          ),
        ],
        const SizedBox(height: 10),
        SelectableText(_post.content, style: const TextStyle(fontSize: 15, height: 1.4)),
        if (_post.imageURLs.isNotEmpty) ...[
          const SizedBox(height: 12),
          ForumImageGrid(urls: _post.imageURLs),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            _LikeButton(
              liked: liked,
              count: _post.likes.length,
              onTap: _togglePostLike,
            ),
          ],
        ),
      ],
    );
  }

  Widget _authorName({required bool anonymous, ForumUser? user}) {
    if (anonymous || user == null) {
      return const Text('匿名',
          style: TextStyle(fontWeight: FontWeight.w600));
    }
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForumUserPostsScreen(
            user: user,
            schoolAdmin: widget.schoolAdmin,
            vocPassAdmin: widget.vocPassAdmin,
          ),
        ),
      ),
      child: Text(user.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildMessageTile(ForumMessage message) {
    final user = message.user;
    final anonymous = message.anonymous || user == null;
    final badge = anonymous ? null : _badgeFor(user.id);
    final liked = message.isLikedBy(_currentUserID);
    final isOwner = user?.id != null && user?.id == _currentUserID;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ForumAvatar(
            url: anonymous ? null : user.avatarURL,
            fallbackText: anonymous ? '匿' : user.displayName,
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(anonymous ? '匿名' : user.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      ForumBadgeChip(badge: badge),
                    ],
                    const Spacer(),
                    Text(forumRelativeTime(message.created),
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(message.content, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _LikeButton(
                      liked: liked,
                      count: message.likes.length,
                      small: true,
                      onTap: () => _toggleMessageLike(message),
                    ),
                    const SizedBox(width: 8),
                    _IconTextButton(
                      icon: Icons.flag_outlined,
                      onTap: () => showForumReportSheet(context,
                          forumMessageID: message.id),
                    ),
                    if (isOwner)
                      _IconTextButton(
                        icon: Icons.delete_outline,
                        color: Colors.red,
                        onTap: () => _deleteMessage(message),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '匿名',
              icon: Icon(
                _replyAnonymous ? Icons.visibility_off : Icons.visibility,
                color: _replyAnonymous
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              onPressed: () =>
                  setState(() => _replyAnonymous = !_replyAnonymous),
            ),
            Expanded(
              child: TextField(
                controller: _replyCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '寫下你的留言...',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              onPressed: _sending ? null : _sendReply,
            ),
          ],
        ),
      ),
    );
  }

}

class _LikeButton extends StatelessWidget {
  final bool liked;
  final int count;
  final bool small;
  final VoidCallback onTap;

  const _LikeButton({
    required this.liked,
    required this.count,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = liked ? Colors.red : Colors.grey;
    final size = small ? 16.0 : 20.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(liked ? Icons.favorite : Icons.favorite_border,
                size: size, color: color),
            const SizedBox(width: 4),
            Text('$count',
                style: TextStyle(
                    fontSize: small ? 12 : 13, color: color)),
          ],
        ),
      ),
    );
  }
}

class _IconTextButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _IconTextButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(icon, size: 16, color: color ?? Colors.grey),
      ),
    );
  }
}

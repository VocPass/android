// 論壇使用者文章頁

import 'package:flutter/material.dart';

import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import '../../services/vocpass_auth_service.dart';
import 'forum_post_detail_screen.dart';
import 'forum_post_row.dart';
import 'forum_widgets.dart';

class ForumUserPostsScreen extends StatefulWidget {
  final ForumUser user;
  final ForumAdminInfo? schoolAdmin;
  final ForumAdminInfo? vocPassAdmin;

  const ForumUserPostsScreen({
    super.key,
    required this.user,
    this.schoolAdmin,
    this.vocPassAdmin,
  });

  @override
  State<ForumUserPostsScreen> createState() => _ForumUserPostsScreenState();
}

class _ForumUserPostsScreenState extends State<ForumUserPostsScreen> {
  final _posts = <ForumPost>[];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  String? get _currentUserID => VocPassAuthService.instance.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }
    try {
      final data = await ForumService.instance
          .fetchUserPosts(userID: widget.user.id, page: reset ? 1 : _page);
      if (!mounted) return;
      setState(() {
        if (reset) _posts.clear();
        _posts.addAll(data.forums);
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
    await _load(reset: false);
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _toggleLike(ForumPost post) async {
    if (!VocPassAuthService.instance.isLoggedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請先登入 VocPass 帳號')));
      return;
    }
    final userID = _currentUserID;
    if (userID == null) return;
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index < 0) return;
    final liked = post.isLikedBy(userID);
    setState(() => _posts[index] = _toggledLike(post, userID, !liked));
    try {
      await ForumService.instance
          .setPostLike(postID: post.likeTargetID, liked: !liked);
    } catch (e) {
      if (!mounted) return;
      setState(() => _posts[index] = _toggledLike(post, userID, liked));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  ForumBadge? get _userBadge => badgeForUser(
        userID: widget.user.id,
        schoolAdmin: widget.schoolAdmin,
        vocPassAdmin: widget.vocPassAdmin,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.user.displayName)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 40),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: () => _load(reset: true),
                child: const Text('重試')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) _loadMore();
          return false;
        },
        child: ListView.separated(
          itemCount: _posts.length + 2,
          separatorBuilder: (_, i) =>
              i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
          itemBuilder: (context, i) {
            if (i == 0) return _buildHeader();
            if (i == _posts.length + 1) {
              if (_loadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_posts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child:
                      Center(child: Text('這位使用者還沒有發過文', style: TextStyle(color: Colors.grey))),
                );
              }
              return const SizedBox(height: 24);
            }
            final post = _posts[i - 1];
            return ForumPostRow(
              post: post,
              currentUserID: _currentUserID,
              badge: post.anonymous ? null : _userBadge,
              onTap: () => _openPost(post),
              onLike: () => _toggleLike(post),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final badge = _userBadge;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ForumAvatar(
              url: widget.user.avatarURL,
              fallbackText: widget.user.displayName,
              size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user.displayName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                if (widget.user.username.isNotEmpty)
                  Text('@${widget.user.username}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                if (badge != null) ...[
                  const SizedBox(height: 6),
                  ForumBadgeChip(badge: badge),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPost(ForumPost post) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ForumPostDetailScreen(
          post: post,
          schoolAdmin: widget.schoolAdmin,
          vocPassAdmin: widget.vocPassAdmin,
        ),
      ),
    );
    if (result == true) _load(reset: true);
  }

  ForumPost _toggledLike(ForumPost post, String userID, bool liked) {
    final likes = List<String>.from(post.likes);
    if (liked) {
      if (!likes.contains(userID)) likes.add(userID);
    } else {
      likes.remove(userID);
    }
    return ForumPost(
      id: post.id,
      post: post.post,
      school: post.school,
      title: post.title,
      content: post.content,
      anonymous: post.anonymous,
      pin: post.pin,
      tags: post.tags,
      images: post.images,
      likes: likes,
      user: post.user,
      created: post.created,
      updated: post.updated,
    );
  }
}

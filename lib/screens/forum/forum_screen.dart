// 論壇主頁 - 對應 iOS 的 ForumView

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import '../../services/school_config_manager.dart';
import '../../services/vocpass_auth_service.dart';
import 'forum_create_post_screen.dart';
import 'forum_post_detail_screen.dart';
import 'forum_post_row.dart';
import 'forum_user_posts_screen.dart';
import 'forum_verification_sheet.dart';
import 'forum_widgets.dart';

enum ForumScope { currentSchool, all }

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final _posts = <ForumPost>[];
  final _searchCtrl = TextEditingController();

  ForumScope _scope = ForumScope.currentSchool;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _search = '';
  Timer? _searchDebounce;

  ForumAdminInfo? _schoolAdmin;
  ForumAdminInfo? _vocPassAdmin;
  List<ForumTagOption> _tagOptions = const [];

  String? get _currentUserID =>
      VocPassAuthService.instance.currentUser?.id;
  bool get _isLoggedIn => VocPassAuthService.instance.isLoggedIn;

  /// 已驗證的學校名稱（同時登入過學校與 VocPass 帳號）。
  String? get _verifiedSchoolName =>
      VocPassAuthService.instance.currentUser?.verifiedSchool;

  String? get _selectedSchoolName =>
      context.read<SchoolConfigManager>().selectedSchool?.name;

  /// 依範圍決定要查詢的 school 參數。
  String get _requestSchool {
    if (_scope == ForumScope.all) return 'all';
    return _selectedSchoolName ?? 'all';
  }

  /// 在本校範圍下，目前使用者是否為該校版主。
  bool get _isCurrentSchoolModerator {
    final userID = _currentUserID;
    if (userID == null || _scope != ForumScope.currentSchool) return false;
    return _schoolAdmin?.admin.contains(userID) == true;
  }

  bool get _isVocPassAdmin {
    final userID = _currentUserID;
    return userID != null && _vocPassAdmin?.admin.contains(userID) == true;
  }

  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = _isLoggedIn;
    VocPassAuthService.instance.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 沒有選定學校時，預設改為瀏覽全部。
      if (_selectedSchoolName == null) _scope = ForumScope.all;
      _loadAdminAndTags();
      _load(reset: true);
    });
  }

  /// 登入 / 登出狀態改變時，重新載入版主資訊與文章（讓發文權限與按讚狀態更新）。
  void _onAuthChanged() {
    final loggedIn = _isLoggedIn;
    if (loggedIn == _wasLoggedIn) return;
    _wasLoggedIn = loggedIn;
    if (!mounted) return;
    _loadAdminAndTags();
    _load(reset: true);
  }

  @override
  void dispose() {
    VocPassAuthService.instance.removeListener(_onAuthChanged);
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdminAndTags() async {
    final school = _selectedSchoolName;
    final results = await Future.wait([
      if (school != null)
        ForumService.instance.fetchAdminInfo(school)
      else
        Future<ForumAdminInfo?>.value(null),
      ForumService.instance.fetchVocPassAdminInfo(),
      ForumService.instance.fetchTags().catchError((_) => <ForumTagOption>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _schoolAdmin = results[0] as ForumAdminInfo?;
      _vocPassAdmin = results[1] as ForumAdminInfo?;
      _tagOptions = results[2] as List<ForumTagOption>;
    });
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
      final data = await ForumService.instance.fetchPosts(
        school: _requestSchool,
        page: reset ? 1 : _page,
        search: _search,
      );
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

  void _onScopeChanged(ForumScope scope) {
    if (scope == _scope) return;
    setState(() {
      _scope = scope;
      _posts.clear();
    });
    _load(reset: true);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (value == _search) return;
      _search = value;
      _load(reset: true);
    });
  }

  Future<void> _toggleLike(ForumPost post) async {
    if (!_requireLogin()) return;
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

  bool _requireLogin() {
    if (_isLoggedIn) return true;
    _promptLogin();
    return false;
  }

  /// 論壇登入 = VocPass 帳號（非學校帳號）。在外部瀏覽器開啟 OAuth，
  /// 完成後透過 vocpass://callback?token= deep link 回到 App（見 app.dart）。
  Future<void> _promptLogin() async {
    final uri = Uri.parse('${AppConfig.vocPassApiHost}/auth');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('無法開啟登入頁面')));
    }
  }

  Future<void> _openCreatePost() async {
    if (!_requireLogin()) return;
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ForumCreatePostScreen(
          verifiedSchool: _verifiedSchoolName,
          initialSchool: _requestSchool,
          canPinCurrentSchool: _isCurrentSchoolModerator || _isVocPassAdmin,
          canUseAdminTags: _isCurrentSchoolModerator || _isVocPassAdmin,
          tagOptions: _tagOptions,
        ),
      ),
    );
    if (created == true) _load(reset: true);
  }

  void _openVerification() {
    showForumVerificationSheet(context,
        selectedSchoolName: _selectedSchoolName);
  }

  void _openGuidelines() {
    launchUrl(
      Uri.parse('${AppConfig.vocPassApiHost}/community-guidelines'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openPost(ForumPost post) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ForumPostDetailScreen(
          post: post,
          schoolAdmin: _schoolAdmin,
          vocPassAdmin: _vocPassAdmin,
        ),
      ),
    );
    if (result == true) _load(reset: true);
  }

  ForumBadge? _badgeFor(String? userID) => badgeForUser(
        userID: userID,
        schoolAdmin: _schoolAdmin,
        vocPassAdmin: _vocPassAdmin,
      );

  @override
  Widget build(BuildContext context) {
    // 監聽登入狀態變化，登入後 AppBar 與發文權限即時更新。
    final auth = context.watch<VocPassAuthService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('論壇'),
        actions: [
          IconButton(
            tooltip: '社群守則',
            icon: const Icon(Icons.description_outlined),
            onPressed: _openGuidelines,
          ),
          if (auth.isLoggedIn) ...[
            IconButton(
              tooltip: '發文',
              icon: const Icon(Icons.add),
              onPressed: _openCreatePost,
            ),
            if (auth.currentUser != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForumUserPostsScreen(
                        user: ForumUser(
                          id: auth.currentUser!.id,
                          name: auth.currentUser!.name,
                          username: auth.currentUser!.username,
                          avatar: auth.currentUser!.avatar,
                        ),
                        schoolAdmin: _schoolAdmin,
                        vocPassAdmin: _vocPassAdmin,
                      ),
                    ),
                  ),
                  child: ForumAvatar(
                    url: auth.currentUser!.avatarURL,
                    fallbackText: auth.currentUser!.displayName,
                    size: 30,
                  ),
                ),
              ),
          ] else
            IconButton(
              tooltip: '登入 VocPass',
              icon: const Icon(Icons.login),
              onPressed: _promptLogin,
            ),
        ],
      ),
      floatingActionButton: auth.isLoggedIn
          ? FloatingActionButton(
              onPressed: _openCreatePost,
              child: const Icon(Icons.edit),
            )
          : null,
      body: Column(
        children: [
          _buildScopePicker(),
          _buildSearchBar(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildScopePicker() {
    final hasSchool = _selectedSchoolName != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<ForumScope>(
        segments: const [
          ButtonSegment(value: ForumScope.currentSchool, label: Text('本校')),
          ButtonSegment(value: ForumScope.all, label: Text('全部')),
        ],
        selected: {_scope},
        // 未選學校時停用本校切換。
        onSelectionChanged:
            hasSchool ? (s) => _onScopeChanged(s.first) : null,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: '搜尋文章',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                ),
        ),
        onChanged: (v) {
          setState(() {});
          _onSearchChanged(v);
        },
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _posts.isEmpty) {
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
            if (i == 0) return _buildSchoolAdminHeader();
            if (i == _posts.length + 1) return _buildFooter();
            final post = _posts[i - 1];
            return ForumPostRow(
              post: post,
              currentUserID: _currentUserID,
              badge: post.anonymous ? null : _badgeFor(post.user?.id),
              onTap: () => _openPost(post),
              onLike: () => _toggleLike(post),
              onAuthorTap: post.user == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForumUserPostsScreen(
                            user: post.user!,
                            schoolAdmin: _schoolAdmin,
                            vocPassAdmin: _vocPassAdmin,
                          ),
                        ),
                      ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSchoolAdminHeader() {
    if (_scope != ForumScope.currentSchool) return const SizedBox.shrink();
    final school = _selectedSchoolName;
    if (school == null) return const SizedBox.shrink();

    final admin = _schoolAdmin;
    final displayName =
        (admin?.school.isNotEmpty == true) ? admin!.school : school;
    final moderatorCount = admin?.admin.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            _SchoolIcon(url: admin?.iconURL),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _openVerification,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          _verifiedSchoolName == school
                              ? Icons.verified
                              : Icons.verified_outlined,
                          size: 15,
                          color: _verifiedSchoolName == school
                              ? Colors.green
                              : Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('$moderatorCount 位版主',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ApplyButton(school: school),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: Text('目前還沒有文章', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return const SizedBox(height: 80);
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

class _SchoolIcon extends StatelessWidget {
  final String? url;

  const _SchoolIcon({this.url});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.account_balance, color: Colors.blue.shade400),
    );
    if (url == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(url!,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  final String school;

  const _ApplyButton({required this.school});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final uri = Uri.parse('${AppConfig.vocPassApiHost}/apply/admin')
            .replace(queryParameters: {'school': school});
        launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt, size: 14, color: Colors.blue),
            SizedBox(width: 4),
            Text('申請',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue)),
          ],
        ),
      ),
    );
  }
}

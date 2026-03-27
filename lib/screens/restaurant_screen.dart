import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/school_config_manager.dart';
import '../services/vocpass_auth_service.dart';

// MARK: - 餐廳列表

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  List<Restaurant> _restaurants = [];
  bool _isLoading = false;
  String? _evalError;
  String _selectedSchool = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mgr = context.read<SchoolConfigManager>();
      setState(() {
        _selectedSchool = mgr.selectedSchool?.name ??
            (mgr.schools.isNotEmpty ? mgr.schools.first.name : '');
      });
      if (_selectedSchool.isNotEmpty) _loadRestaurants();
    });
  }

  Future<void> _loadRestaurants() async {
    if (_selectedSchool.isEmpty) return;
    setState(() {
      _isLoading = true;
      _evalError = null;
    });
    try {
      final api = context.read<ApiService>();
      final list = await api.fetchRestaurants(_selectedSchool);
      if (!mounted) return;
      setState(() {
        _restaurants = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _evalError = e.toString();
        _isLoading = false;
      });
    }
  }

  void _pickRandom() {
    if (_restaurants.isEmpty) return;
    final picked = _restaurants[Random().nextInt(_restaurants.length)];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickedRestaurantSheet(
        finalRestaurant: picked,
        allRestaurants: _restaurants,
      ),
    );
  }

  void _showSchoolPicker() {
    final mgr = context.read<SchoolConfigManager>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('選擇學校', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...mgr.schools.map((s) => ListTile(
                title: Text(s.name),
                trailing: s.name == _selectedSchool
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedSchool = s.name;
                    _restaurants = [];
                  });
                  _loadRestaurants();
                },
              )),
        ],
      ),
    );
  }

  void _showAddRestaurant() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('新增餐廳', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '餐廳名稱',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: '地址（選填）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  try {
                    final api = context.read<ApiService>();
                    await api.createRestaurant(
                      school: _selectedSchool,
                      name: name,
                      lat: 0,
                      lon: 0,
                      address: addressCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadRestaurants();
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
                child: const Text('新增'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('吃啥？'),
        actions: [
          IconButton(
            onPressed: _selectedSchool.isEmpty ? null : _showAddRestaurant,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadRestaurants,
      child: ListView(
        children: [
          // 學校選擇
          ListTile(
            title: const Text('學校'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_selectedSchool.isEmpty ? '請選擇' : _selectedSchool,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(width: 4),
                const Icon(Icons.unfold_more, size: 16, color: Colors.grey),
              ],
            ),
            onTap: _showSchoolPicker,
          ),
          const Divider(height: 1),

          // 隨機挑選
          if (_restaurants.isNotEmpty) ...[
            ListTile(
              leading: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.casino, color: Colors.white, size: 18),
              ),
              title: const Text('隨機挑一間',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: _pickRandom,
            ),
            const Divider(height: 1),
          ],

          // 餐廳列表
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_evalError != null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(height: 8),
                  Text(_evalError!, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _loadRestaurants,
                    child: const Text('重試'),
                  ),
                ],
              ),
            )
          else if (_restaurants.isEmpty && _selectedSchool.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('目前尚無餐廳資料', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._restaurants.map((r) => _RestaurantTile(
                  restaurant: r,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RestaurantDetailScreen(restaurant: r),
                    ),
                  ),
                  onDelete: r.user == VocPassAuthService.instance.currentUser?.id
                      ? () => _confirmDelete(r)
                      : null,
                )),
        ],
      ),
    );
  }

  void _confirmDelete(Restaurant r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('確定刪除「${r.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<ApiService>().deleteRestaurant(r.id);
                setState(() => _restaurants.removeWhere((e) => e.id == r.id));
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _RestaurantTile({
    required this.restaurant,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _RestaurantIcon(url: restaurant.iconURL, size: 44),
      title: Text(restaurant.name),
      subtitle: restaurant.address != null && restaurant.address!.isNotEmpty
          ? Text(restaurant.address!, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey))
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      onLongPress: onDelete,
    );
  }
}

// MARK: - 餐廳詳細頁

class RestaurantDetailScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  List<RestaurantEvaluation> _evaluations = [];
  List<RestaurantMenu> _menuItems = [];
  bool _isLoading = false;
  bool _isLoadingMenu = false;
  String? _evalError;

  double? get _averageScore {
    if (_evaluations.isEmpty) return null;
    return _evaluations.map((e) => e.score).reduce((a, b) => a + b) /
        _evaluations.length;
  }

  @override
  void initState() {
    super.initState();
    _loadEvaluations();
    _loadMenu();
  }

  Future<void> _loadEvaluations() async {
    setState(() { _isLoading = true; _evalError = null; });
    try {
      final api = context.read<ApiService>();
      final list = await api.fetchRestaurantEvaluations(widget.restaurant.id);
      if (!mounted) return;
      setState(() { _evaluations = list; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _evalError = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoadingMenu = true);
    try {
      final api = context.read<ApiService>();
      final list = await api.fetchRestaurantMenu(widget.restaurant.id);
      if (!mounted) return;
      setState(() { _menuItems = list; _isLoadingMenu = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMenu = false);
    }
  }

  void _openMaps() {
    final map = widget.restaurant.map;
    if (map == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${map.lat},${map.lon}');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showAddEvaluation() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int score = 3;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('新增評價', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: '標題',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: '內容',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('評分'),
                  const Spacer(),
                  ...List.generate(5, (i) => GestureDetector(
                        onTap: () => setSheetState(() => score = i + 1),
                        child: Icon(
                          i < score ? Icons.star : Icons.star_border,
                          color: i < score ? Colors.amber : Colors.grey[400],
                          size: 28,
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
                    try {
                      final api = context.read<ApiService>();
                      await api.createEvaluation(
                        restaurantID: widget.restaurant.id,
                        title: title,
                        description: descCtrl.text.trim(),
                        score: score,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadEvaluations();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('送出'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    return Scaffold(
      appBar: AppBar(
        title: Text(r.name),
        actions: [
          IconButton(
            onPressed: _showAddEvaluation,
            icon: const Icon(Icons.edit_note),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadEvaluations();
          await _loadMenu();
        },
        child: ListView(
          children: [
            // 頂部資訊
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _RestaurantIcon(url: r.iconURL, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                        if (r.address != null && r.address!.isNotEmpty)
                          Text(r.address!,
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        if (_averageScore != null)
                          Row(children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(_averageScore!.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            Text(' (${_evaluations.length} 則評價)',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ])
                        else if (!_isLoading)
                          const Text('暫無評價',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 導航按鈕
            if (r.map != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton.icon(
                  onPressed: _openMaps,
                  icon: const Icon(Icons.map),
                  label: const Text('導航'),
                ),
              ),

            const SizedBox(height: 16),

            // 菜單圖片
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('菜單', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            if (_isLoadingMenu)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ))
            else if (_menuItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('目前尚無菜單圖片', style: TextStyle(color: Colors.grey)),
              )
            else
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _menuItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final item = _menuItems[i];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: item.menuURL != null
                          ? Image.network(item.menuURL!, width: 100, height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 100, height: 100,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image, color: Colors.grey),
                              ))
                          : Container(
                              width: 100, height: 100,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // 評價
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('評價', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ))
            else if (_evalError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(_evalError!, style: const TextStyle(color: Colors.red)),
              )
            else if (_evaluations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('目前尚無評價', style: TextStyle(color: Colors.grey)),
              )
            else
              ..._evaluations.map((ev) => _EvaluationTile(
                    evaluation: ev,
                    onDelete: ev.user == VocPassAuthService.instance.currentUser?.id
                        ? () => _confirmDeleteEvaluation(ev)
                        : null,
                  )),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteEvaluation(RestaurantEvaluation ev) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確定刪除這則評價？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<ApiService>().deleteEvaluation(ev.id);
                setState(() => _evaluations.removeWhere((e) => e.id == ev.id));
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}

class _EvaluationTile extends StatelessWidget {
  final RestaurantEvaluation evaluation;
  final VoidCallback? onDelete;

  const _EvaluationTile({required this.evaluation, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(evaluation.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          _StarRating(score: evaluation.score),
        ],
      ),
      subtitle: evaluation.plainDescription.isNotEmpty
          ? Text(evaluation.plainDescription, maxLines: 2,
              overflow: TextOverflow.ellipsis)
          : null,
      onLongPress: onDelete,
    );
  }
}

class _StarRating extends StatelessWidget {
  final int score;

  const _StarRating({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Icon(
            i < score ? Icons.star : Icons.star_border,
            size: 14,
            color: i < score ? Colors.amber : Colors.grey[400],
          )),
    );
  }
}

class _RestaurantIcon extends StatelessWidget {
  final String? url;
  final double size;

  const _RestaurantIcon({this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.network(url!, width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder()),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: Icon(Icons.restaurant, color: Colors.grey[400], size: size * 0.5),
      );
}

// MARK: - 隨機結果 Sheet

class _PickedRestaurantSheet extends StatefulWidget {
  final Restaurant finalRestaurant;
  final List<Restaurant> allRestaurants;

  const _PickedRestaurantSheet({
    required this.finalRestaurant,
    required this.allRestaurants,
  });

  @override
  State<_PickedRestaurantSheet> createState() => _PickedRestaurantSheetState();
}

class _PickedRestaurantSheetState extends State<_PickedRestaurantSheet> {
  String _displayedName = '';
  bool _isRolling = true;

  @override
  void initState() {
    super.initState();
    _rollAnimation();
  }

  Future<void> _rollAnimation() async {
    final rng = Random();
    if (widget.allRestaurants.length <= 1) {
      setState(() {
        _displayedName = widget.finalRestaurant.name;
        _isRolling = false;
      });
      return;
    }

    // 快速階段
    for (int i = 0; i < 10; i++) {
      if (!mounted) return;
      setState(() {
        _displayedName = widget.allRestaurants[rng.nextInt(widget.allRestaurants.length)].name;
      });
      await Future.delayed(const Duration(milliseconds: 80));
    }

    // 慢速收尾
    for (final delay in [130, 180, 240, 320, 420]) {
      if (!mounted) return;
      setState(() {
        _displayedName = widget.allRestaurants[rng.nextInt(widget.allRestaurants.length)].name;
      });
      await Future.delayed(Duration(milliseconds: delay));
    }

    if (!mounted) return;
    setState(() {
      _displayedName = widget.finalRestaurant.name;
      _isRolling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Spacer(),
          _RestaurantIcon(
            url: _isRolling ? null : widget.finalRestaurant.iconURL,
            size: 100,
          ),
          const SizedBox(height: 16),
          const Text('今天就吃', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _displayedName,
              key: ValueKey(_displayedName),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isRolling
                        ? null
                        : () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RestaurantDetailScreen(
                                    restaurant: widget.finalRestaurant),
                              ),
                            );
                          },
                    child: const Text('查看評價'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isRolling ? null : () => Navigator.pop(context),
                    child: const Text('算了'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

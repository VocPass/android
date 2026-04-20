import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/vocpass_auth_service.dart';
import 'wallpaper_editor_screen.dart';

// ───────────────────────────── Models ─────────────────────────────

class WallpaperTableConfig {
  final List<String> images;
  final double left;
  final double right;
  final double? topInset;
  final double? bottom;

  const WallpaperTableConfig({
    required this.images,
    required this.left,
    required this.right,
    this.topInset,
    this.bottom,
  });

  factory WallpaperTableConfig.fromJson(dynamic json) {
    // New format: { images: [...], left: N, right: N, top_inset: N, bottom: N }
    if (json is Map<String, dynamic>) {
      final imgs = (json['images'] as List?)?.cast<String>() ?? [];
      return WallpaperTableConfig(
        images: imgs,
        left: (json['left'] as num?)?.toDouble() ?? 30,
        right: (json['right'] as num?)?.toDouble() ?? 30,
        topInset: (json['top_inset'] as num?)?.toDouble(),
        bottom: (json['bottom'] as num?)?.toDouble(),
      );
    }
    // Old format: list of strings
    if (json is List) {
      return WallpaperTableConfig(
        images: json.cast<String>(),
        left: 30,
        right: 30,
      );
    }
    return const WallpaperTableConfig(images: [], left: 30, right: 30);
  }
}

class WallpaperImages {
  final List<String> background;
  final List<String> stickers;
  final Map<String, WallpaperTableConfig> table;

  const WallpaperImages({
    required this.background,
    required this.stickers,
    required this.table,
  });

  factory WallpaperImages.fromJson(Map<String, dynamic> json) {
    final bg = (json['background'] as List?)?.cast<String>() ?? [];
    final sk = (json['stickers'] as List?)?.cast<String>() ?? [];
    final tableRaw = json['table'] as Map<String, dynamic>? ?? {};
    final table = tableRaw
        .map((k, v) => MapEntry(k, WallpaperTableConfig.fromJson(v)));
    return WallpaperImages(background: bg, stickers: sk, table: table);
  }
}

class WallpaperTemplate {
  final String name;
  final String author;
  final String? authorUrl;
  final String preview;
  final WallpaperImages images;
  final double top;
  final int stickers;
  final double? fontSize;
  final String? fontColor;
  final double? tableOpacity;

  const WallpaperTemplate({
    required this.name,
    required this.author,
    this.authorUrl,
    required this.preview,
    required this.images,
    required this.top,
    required this.stickers,
    this.fontSize,
    this.fontColor,
    this.tableOpacity,
  });

  factory WallpaperTemplate.fromJson(Map<String, dynamic> json) {
    return WallpaperTemplate(
      name: json['name'] as String? ?? '',
      author: json['author'] as String? ?? '',
      authorUrl: json['author_url'] as String?,
      preview: json['preview'] as String? ?? '',
      images: WallpaperImages.fromJson(
          json['images'] as Map<String, dynamic>? ?? {}),
      top: (json['top'] as num?)?.toDouble() ?? 20,
      stickers: (json['stickers'] as num?)?.toInt() ?? 0,
      fontSize: (json['font_size'] as num?)?.toDouble(),
      fontColor: json['font_color'] as String?,
      tableOpacity: (json['table_opacity'] as num?)?.toDouble(),
    );
  }
}

// ─────────────────────── Template List Screen ───────────────────────

class WallpaperTemplateListScreen extends StatefulWidget {
  const WallpaperTemplateListScreen({super.key});

  @override
  State<WallpaperTemplateListScreen> createState() =>
      _WallpaperTemplateListScreenState();
}

class _WallpaperTemplateListScreenState
    extends State<WallpaperTemplateListScreen> {
  List<WallpaperTemplate> _templates = [];
  Map<String, int> _usageStats = {};
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final base = AppConfig.vocPassApiHost;
      final [templatesRes, statsRes] = await Future.wait([
        http.get(Uri.parse('$base/api/wallpaper/curriculum')),
        http.get(Uri.parse('$base/api/wallpaper/curriculum/status')),
      ]);

      List<WallpaperTemplate> templates;
      final decoded = jsonDecode(templatesRes.body);
      if (decoded is List) {
        templates = decoded
            .cast<Map<String, dynamic>>()
            .map(WallpaperTemplate.fromJson)
            .toList();
      } else if (decoded is Map && decoded['data'] is List) {
        templates = (decoded['data'] as List)
            .cast<Map<String, dynamic>>()
            .map(WallpaperTemplate.fromJson)
            .toList();
      } else {
        templates = [];
      }

      Map<String, int> stats = {};
      try {
        final statDecoded = jsonDecode(statsRes.body);
        final rawStats = statDecoded is Map ? statDecoded['data'] : null;
        if (rawStats is Map) {
          stats = rawStats.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _templates = templates;
          _usageStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vocPassAuth = context.watch<VocPassAuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('課表產生器'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) async {
              final uri = Uri.parse(value);
              // launched by url_launcher already imported via home_page_screen
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'https://github.com/VocPass/wallpaper',
                child: ListTile(
                  leading: Icon(Icons.add_circle_outline),
                  title: Text('新增我的'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'creator-policy',
                child: ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('創作者政策'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(vocPassAuth),
    );
  }

  Widget _buildBody(VocPassAuthService vocPassAuth) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              Text(_loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('重試')),
            ],
          ),
        ),
      );
    }
    if (_templates.isEmpty) {
      return const Center(child: Text('目前無可用模板'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.48,
        ),
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final tpl = _templates[index];
          return _TemplateCard(
            template: tpl,
            useCount: _usageStats[tpl.name] ?? 0,
            onTap: () {
              if (!vocPassAuth.isLoggedIn) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請先登入 VocPass 帳號')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WallpaperEditorScreen(template: tpl),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final WallpaperTemplate template;
  final int useCount;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.useCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview image (9:19.5 ratio)
          AspectRatio(
            aspectRatio: 9.0 / 19.5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: template.preview.isNotEmpty
                  ? Image.network(
                      template.preview,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(
                              color: Colors.grey.shade100,
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child:
                          const Center(child: Icon(Icons.image, color: Colors.grey)),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            template.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'by ${template.author}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              const Icon(Icons.people_outline, size: 12, color: Colors.grey),
              const SizedBox(width: 2),
              Text(
                '$useCount 人使用',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

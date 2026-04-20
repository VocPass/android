import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../services/cache_service.dart';
import '../../services/vocpass_auth_service.dart';
import '../../models/models.dart';
import 'wallpaper_template_list_screen.dart';

// ─────────────────────── Font loader ───────────────────────

class _WallpaperFontLoader {
  static final _WallpaperFontLoader shared = _WallpaperFontLoader._();
  _WallpaperFontLoader._();

  Map<String, String> _list = {};
  final Map<String, String> _loadedFonts = {};

  Future<Map<String, String>> fetchList() async {
    try {
      final res = await http.get(
          Uri.parse('${AppConfig.vocPassApiHost}/api/wallpaper/font'));
      if (res.statusCode != 200) return {};
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      _list = data.map((k, v) => MapEntry(k, v as String));
      return _list;
    } catch (_) {
      return {};
    }
  }

  String? loadedFamily(String displayName) => _loadedFonts[displayName];

  Future<String?> load(String displayName) async {
    if (_loadedFonts.containsKey(displayName)) return _loadedFonts[displayName];
    final urlStr = _list[displayName];
    if (urlStr == null) return null;
    try {
      final res = await http.get(Uri.parse(urlStr));
      if (res.statusCode != 200) return null;
      final loader = FontLoader(displayName);
      loader.addFont(Future.value(ByteData.sublistView(res.bodyBytes)));
      await loader.load();
      _loadedFonts[displayName] = displayName;
      return displayName;
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────── Layer model ───────────────────────────

enum _LayerKind { background, table, sticker }

class _EditorLayer {
  String id;
  _LayerKind kind;
  Uint8List? imageBytes;
  double naturalWidth;
  double naturalHeight;
  List<String> sourceUrls;
  int sourceIndex;
  Offset center;
  Size size;
  double rotation;
  // table-specific
  List<List<String>> subjects;
  int rows;
  double baseFontSize;
  String fontColorHex;
  String fontFamily;
  double tableOpacity;
  double stickerOpacity;
  WallpaperTableConfig? tableConfig;

  _EditorLayer({
    required this.id,
    required this.kind,
    this.imageBytes,
    this.naturalWidth = 1,
    this.naturalHeight = 1,
    required this.sourceUrls,
    this.sourceIndex = 0,
    required this.center,
    required this.size,
    this.rotation = 0,
    this.subjects = const [],
    this.rows = 0,
    this.baseFontSize = 14,
    this.fontColorHex = '#000000',
    this.fontFamily = 'Noto',
    this.tableOpacity = 1.0,
    this.stickerOpacity = 1.0,
    this.tableConfig,
  });

  _EditorLayer clone() => _EditorLayer(
        id: id,
        kind: kind,
        imageBytes: imageBytes,
        naturalWidth: naturalWidth,
        naturalHeight: naturalHeight,
        sourceUrls: List.from(sourceUrls),
        sourceIndex: sourceIndex,
        center: center,
        size: size,
        rotation: rotation,
        subjects: subjects,
        rows: rows,
        baseFontSize: baseFontSize,
        fontColorHex: fontColorHex,
        fontFamily: fontFamily,
        tableOpacity: tableOpacity,
        stickerOpacity: stickerOpacity,
        tableConfig: tableConfig,
      );
}

// ─────────────────── Image cache & helpers ───────────────────────

final _imgCache = <String, Uint8List>{};

Future<Uint8List?> _fetchImage(String url) async {
  if (_imgCache.containsKey(url)) return _imgCache[url];
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      _imgCache[url] = res.bodyBytes;
      return res.bodyBytes;
    }
  } catch (_) {}
  return null;
}

Future<(Uint8List, double, double)> _fetchImageWithSize(String url) async {
  final bytes = await _fetchImage(url);
  if (bytes == null) throw Exception('無法載入圖片: $url');
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final img = frame.image;
  return (bytes, img.width.toDouble(), img.height.toDouble());
}

// ─────────────────────── Timetable helpers ───────────────────────

const _chineseNum = {
  '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7,
  '八': 8, '九': 9, '十': 10, '十一': 11, '十二': 12,
  '十三': 13, '十四': 14, '十五': 15,
};
const _periodNames = [
  '一', '二', '三', '四', '五', '六', '七', '八', '九', '十',
  '十一', '十二', '十三', '十四', '十五',
];
const _weekdays = ['一', '二', '三', '四', '五'];

const _placeholders = [
  '國文', '英文', '數學', '物理', '化學', '生物', '地科',
  '歷史', '地理', '公民', '體育', '音樂', '美術', '資訊',
  '健護', '家政', '生科', '國防', '輔導', '社團', '班會',
];

int _computeMaxPeriod(TimetableData? t) {
  if (t == null) return 8;
  int max = 0;
  void check(String p) {
    final n = _chineseNum[p] ?? int.tryParse(p) ?? 0;
    if (n > max) max = n;
  }
  for (final e in t.entries) check(e.period);
  for (final info in t.curriculum.values) {
    for (final s in info.schedule) check(s.period);
  }
  return max > 0 ? max : 8;
}

String? _pickTableKey(WallpaperTemplate template, int userMax) {
  final available = template.images.table.keys
      .map(int.tryParse)
      .whereType<int>()
      .toList()
    ..sort();
  if (available.isEmpty) return null;
  if (userMax <= available.first) return '${available.first}';
  if (template.images.table.containsKey('$userMax')) return '$userMax';
  if (userMax > available.last) return null;
  return '${available.firstWhere((v) => v >= userMax, orElse: () => available.last)}';
}

List<List<String>> _buildSubjectGrid(TimetableData? t, int rows) {
  final grid = List.generate(rows, (_) => List.filled(5, ''));
  if (t != null) {
    for (int r = 0; r < rows && r < _periodNames.length; r++) {
      final periodKey = _periodNames[r];
      for (int c = 0; c < 5; c++) {
        final wd = _weekdays[c];
        for (final entry in t.curriculum.entries) {
          for (final s in entry.value.schedule) {
            if (s.weekday == wd && s.period == periodKey) {
              grid[r][c] = entry.key;
            }
          }
        }
        if (grid[r][c].isEmpty) {
          for (final e in t.entries) {
            if (e.weekday == wd && e.period == periodKey) {
              grid[r][c] = e.subject;
              break;
            }
          }
        }
      }
    }
  }
  final shuffled = [..._placeholders]..shuffle();
  int idx = 0;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < 5; c++) {
      if (grid[r][c].isEmpty) {
        grid[r][c] = shuffled[idx % shuffled.length];
        idx++;
        if (idx % shuffled.length == 0) shuffled.shuffle();
      }
    }
  }
  return grid;
}

// ─────────────────────────── Canvas sizing ───────────────────────────

Size _computeCanvasSize(Size available) {
  const aspect = 9.0 / 19.5;
  final safeW = math.min(available.width - 16, 500.0);
  final safeH = available.height - 120.0;
  var w = safeW;
  var h = w / aspect;
  if (h > safeH) {
    h = safeH;
    w = h * aspect;
  }
  return Size(w, h);
}

// ─────────────────────────── Editor Screen ───────────────────────────

class WallpaperEditorScreen extends StatefulWidget {
  final WallpaperTemplate template;
  const WallpaperEditorScreen({super.key, required this.template});

  @override
  State<WallpaperEditorScreen> createState() => _WallpaperEditorScreenState();
}

class _WallpaperEditorScreenState extends State<WallpaperEditorScreen> {
  final _boundaryKey = GlobalKey();

  List<_EditorLayer> _layers = [];
  String? _selectedId;
  bool _isLoading = true;
  String? _loadError;
  bool _isSaving = false;
  Size _canvasSize = Size.zero;
  bool _initialized = false;

  // Font
  Map<String, String> _fontList = {};
  bool _isLoadingFont = false;

  // Gesture tracking
  Offset? _panOrigin;
  Offset? _centerOrigin;
  Size? _sizeOrigin;
  double? _rotOrigin;

  // Undo
  final List<List<_EditorLayer>> _undoStack = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final mq = MediaQuery.of(context);
      final bodyH = mq.size.height - mq.padding.top - kToolbarHeight;
      _canvasSize = _computeCanvasSize(Size(mq.size.width, bodyH));
      WidgetsBinding.instance.addPostFrameCallback((_) => _preload());
    }
  }

  // ─────────────── Preload ───────────────

  Future<void> _preload() async {
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final tpl = widget.template;
      final cache = Provider.of<CacheService>(context, listen: false);
      final timetable = cache.getCachedTimetable();
      final userMax = _computeMaxPeriod(timetable);

      final chosenKey = _pickTableKey(tpl, userMax);
      if (chosenKey == null) throw Exception('此模板最多不支援 $userMax 節的課表');
      final tableConfig = tpl.images.table[chosenKey]!;
      if (tableConfig.images.isEmpty) throw Exception('模板缺少課表圖片');

      final bgUrl = tpl.images.background.firstOrNull ?? '';
      final tableUrl = tableConfig.images.first;

      final [(bgBytes, bgW, bgH), (tableBytes, tableW, tableH)] =
          await Future.wait([
        _fetchImageWithSize(bgUrl),
        _fetchImageWithSize(tableUrl),
      ]);

      for (final u in tpl.images.stickers) _fetchImage(u);

      final cw = _canvasSize.width;
      final ch = _canvasSize.height;
      final rows = int.tryParse(chosenKey) ?? userMax;
      final tableDisplayH = cw * (tableH / math.max(1, tableW));
      final tableTop = ch * (tpl.top / 100.0);
      final baseFont = tpl.fontSize ?? () {
        final scale = cw / math.max(1, tableW);
        final leftI = tableConfig.left * scale;
        final rightI = tableConfig.right * scale;
        final usableW = (cw - leftI - rightI).clamp(0.0, double.infinity);
        final cellW = usableW / 5;
        final cellH = tableDisplayH / math.max(rows, 1);
        return math.max(8.0, math.min(cellW, cellH) * 0.32);
      }();
      final subjects = _buildSubjectGrid(timetable, rows);
      final defaultFamily = tpl.fontFamily ?? 'Noto';

      final newLayers = [
        _EditorLayer(
          id: UniqueKey().toString(), kind: _LayerKind.background,
          imageBytes: bgBytes, naturalWidth: bgW, naturalHeight: bgH,
          sourceUrls: tpl.images.background,
          center: Offset(cw / 2, ch / 2),
          size: Size(cw, ch),
        ),
        _EditorLayer(
          id: UniqueKey().toString(), kind: _LayerKind.table,
          imageBytes: tableBytes, naturalWidth: tableW, naturalHeight: tableH,
          sourceUrls: tableConfig.images,
          center: Offset(cw / 2, tableTop + tableDisplayH / 2),
          size: Size(cw, tableDisplayH),
          subjects: subjects, rows: rows, baseFontSize: baseFont,
          fontColorHex: tpl.fontColor ?? '#000000',
          fontFamily: defaultFamily,
          tableOpacity: tpl.tableOpacity ?? 1.0,
          tableConfig: tableConfig,
        ),
      ];

      final rng = math.Random();
      for (int i = 0; i < tpl.stickers; i++) {
        if (tpl.images.stickers.isEmpty) break;
        final url = tpl.images.stickers[rng.nextInt(tpl.images.stickers.length)];
        final bytes = await _fetchImage(url);
        if (bytes == null) continue;
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final img = frame.image;
        const baseW = 80.0;
        final baseH = baseW * img.height / math.max(1, img.width);
        newLayers.add(_EditorLayer(
          id: UniqueKey().toString(), kind: _LayerKind.sticker,
          imageBytes: bytes,
          naturalWidth: img.width.toDouble(), naturalHeight: img.height.toDouble(),
          sourceUrls: tpl.images.stickers,
          center: Offset(
            baseW + rng.nextDouble() * math.max(0, cw - 2 * baseW),
            baseH + rng.nextDouble() * math.max(0, ch - 2 * baseH),
          ),
          size: Size(baseW, baseH),
        ));
      }

      if (mounted) setState(() { _layers = newLayers; _isLoading = false; });

      // Load font list + default font in background
      final fontList = await _WallpaperFontLoader.shared.fetchList();
      if (mounted) setState(() => _fontList = fontList);
      await _WallpaperFontLoader.shared.load(defaultFamily);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString(); _isLoading = false; });
    }
  }

  // ─────────────── Undo ───────────────

  void _pushUndo() {
    _undoStack.add(_layers.map((l) => l.clone()).toList());
    if (_undoStack.length > 30) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _layers = _undoStack.removeLast();
      if (_selectedId != null && !_layers.any((l) => l.id == _selectedId)) {
        _selectedId = null;
      }
    });
  }

  int _idx(String id) => _layers.indexWhere((l) => l.id == id);

  // ─────────────── Gesture ───────────────

  void _onScaleStart(ScaleStartDetails d, String id) {
    final i = _idx(id);
    if (i < 0) return;
    _pushUndo();
    _panOrigin = d.localFocalPoint;
    _centerOrigin = _layers[i].center;
    _sizeOrigin = _layers[i].size;
    _rotOrigin = _layers[i].rotation;
    setState(() => _selectedId = id);
  }

  void _onScaleUpdate(ScaleUpdateDetails d, String id) {
    final i = _idx(id);
    if (i < 0 || _panOrigin == null) return;
    setState(() {
      final l = _layers[i];
      final delta = d.localFocalPoint - _panOrigin!;
      final newCenter = _centerOrigin! + delta;
      final newW = math.max(30.0, _sizeOrigin!.width * d.scale);
      final newH = math.max(30.0, _sizeOrigin!.height * d.scale);
      final newRot = l.kind == _LayerKind.sticker
          ? _rotOrigin! + d.rotation
          : l.rotation;
      _layers[i]
        ..center = newCenter
        ..size = Size(newW, newH)
        ..rotation = newRot;
    });
  }

  void _onScaleEnd(ScaleEndDetails d, String id) {
    _panOrigin = null;
    _centerOrigin = null;
    _sizeOrigin = null;
    _rotOrigin = null;
  }

  // ─────────────── Image ops ───────────────

  Future<void> _addStickerFromGallery() async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法開啟相簿：$e')),
        );
      }
      return;
    }
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final rng = math.Random();
    const baseW = 80.0;
    final baseH = baseW * img.height / math.max(1, img.width);
    setState(() {
      _pushUndo();
      _layers.add(_EditorLayer(
        id: UniqueKey().toString(), kind: _LayerKind.sticker,
        imageBytes: bytes,
        naturalWidth: img.width.toDouble(), naturalHeight: img.height.toDouble(),
        sourceUrls: const [],
        center: Offset(
          baseW + rng.nextDouble() * math.max(0, _canvasSize.width - 2 * baseW),
          baseH + rng.nextDouble() * math.max(0, _canvasSize.height - 2 * baseH),
        ),
        size: Size(baseW, baseH),
      ));
    });
  }

  Future<void> _addStickerFromUrl(String url) async {
    final bytes = await _fetchImage(url);
    if (bytes == null || !mounted) return;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final rng = math.Random();
    const baseW = 80.0;
    final baseH = baseW * img.height / math.max(1, img.width);
    setState(() {
      _pushUndo();
      _layers.add(_EditorLayer(
        id: UniqueKey().toString(), kind: _LayerKind.sticker,
        imageBytes: bytes,
        naturalWidth: img.width.toDouble(), naturalHeight: img.height.toDouble(),
        sourceUrls: widget.template.images.stickers,
        center: Offset(
          baseW + rng.nextDouble() * math.max(0, _canvasSize.width - 2 * baseW),
          baseH + rng.nextDouble() * math.max(0, _canvasSize.height - 2 * baseH),
        ),
        size: Size(baseW, baseH),
      ));
    });
  }

  Future<void> _switchLayerImage(String layerId, String url) async {
    final bytes = await _fetchImage(url);
    if (bytes == null || !mounted) return;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    setState(() {
      final i = _idx(layerId);
      if (i < 0) return;
      _pushUndo();
      final l = _layers[i];
      final newH = l.kind == _LayerKind.background
          ? l.size.height
          : l.size.width * img.height / math.max(1, img.width);
      _layers[i]
        ..imageBytes = bytes
        ..naturalWidth = img.width.toDouble()
        ..naturalHeight = img.height.toDouble()
        ..sourceIndex = l.sourceUrls.indexOf(url).clamp(0, l.sourceUrls.length - 1)
        ..size = Size(l.size.width, newH);
    });
  }

  // ─────────────── Switch period count ───────────────

  Future<void> _switchPeriodCount(String layerId, int newCount) async {
    final tpl = widget.template;
    final key = '$newCount';
    final tableConfig = tpl.images.table[key];
    if (tableConfig == null || tableConfig.images.isEmpty) return;
    final url = tableConfig.images.first;
    final cache = Provider.of<CacheService>(context, listen: false);
    final bytes = await _fetchImage(url);
    if (bytes == null || !mounted) return;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final subjects = _buildSubjectGrid(cache.getCachedTimetable(), newCount);
    setState(() {
      final i = _idx(layerId);
      if (i < 0) return;
      _pushUndo();
      final l = _layers[i];
      final cw = l.size.width;
      final tableDisplayH = cw * img.height / math.max(1, img.width);
      final scale = cw / math.max(1, img.width.toDouble());
      final leftI = tableConfig.left * scale;
      final rightI = tableConfig.right * scale;
      final usableW = (cw - leftI - rightI).clamp(0.0, double.infinity);
      final cellW = usableW / 5;
      final cellH = tableDisplayH / math.max(newCount, 1);
      final baseFont = tpl.fontSize ?? math.max(8.0, math.min(cellW, cellH) * 0.32);
      _layers[i]
        ..imageBytes = bytes
        ..naturalWidth = img.width.toDouble()
        ..naturalHeight = img.height.toDouble()
        ..sourceUrls = tableConfig.images
        ..sourceIndex = 0
        ..size = Size(cw, tableDisplayH)
        ..rows = newCount
        ..subjects = subjects
        ..baseFontSize = baseFont
        ..tableConfig = tableConfig;
    });
  }

  // ─────────────── Save ───────────────

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final pixelRatio = 1242.0 / _canvasSize.width;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('無法匯出圖片');
      await Gal.putImageBytes(byteData.buffer.asUint8List());
      _reportUsage();
      if (mounted) { setState(() => _isSaving = false); _showSavedDialog(); }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
      }
    }
  }

  void _reportUsage() {
    final name = Uri.encodeComponent(widget.template.name);
    final headers = <String, String>{};
    VocPassAuthService.instance.applyAuthHeader(headers);
    http.post(
      Uri.parse('${AppConfig.vocPassApiHost}/api/wallpaper/curriculum/status?wallpaper_name=$name'),
      headers: headers,
    );
  }

  void _showSavedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('儲存完成'),
        content: const Text('儲存完成，去支持一下作者吧'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final url = widget.template.authorUrl;
              if (url != null) {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  // ─────────────── Build ───────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.template.name,
            style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undoStack.isEmpty || _isLoading ? null : _undo,
            color: Colors.white,
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_alt),
            onPressed: _isLoading || _isSaving ? null : _save,
            color: Colors.white,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          if (_isLoading)
            const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text('正在施加魔法⋯', style: TextStyle(color: Colors.white)),
            ])),
          if (!_isLoading && _loadError != null)
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                Text(_loadError!, style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _preload, child: const Text('重試')),
              ]),
            )),
          if (!_isLoading && _loadError == null)
            GestureDetector(
              onTap: () => setState(() => _selectedId = null),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: SizedBox(
                      width: _canvasSize.width,
                      height: _canvasSize.height,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(child: Container(color: Colors.grey.shade300)),
                          ..._layers.map(_buildLayerWidget),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!_isLoading && _loadError == null)
            Positioned(
              left: 12, right: 12,
              bottom: 8 + MediaQuery.of(context).padding.bottom,
              child: _buildToolbar(),
            ),
        ],
      ),
    );
  }

  // ─────────────── Canvas layer widget ───────────────

  Widget _buildLayerWidget(_EditorLayer layer) {
    final isSelected = layer.id == _selectedId;
    return Positioned(
      left: layer.center.dx - layer.size.width / 2,
      top: layer.center.dy - layer.size.height / 2,
      width: layer.size.width,
      height: layer.size.height,
      child: GestureDetector(
        onScaleStart: (d) => _onScaleStart(d, layer.id),
        onScaleUpdate: (d) => _onScaleUpdate(d, layer.id),
        onScaleEnd: (d) => _onScaleEnd(d, layer.id),
        onTap: () => setState(() => _selectedId = layer.id),
        child: Transform.rotate(
          angle: layer.rotation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: _buildLayerContent(layer)),
              if (isSelected)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerContent(_EditorLayer layer) {
    final bytes = layer.imageBytes;
    switch (layer.kind) {
      case _LayerKind.background:
        if (bytes == null) return const SizedBox.expand();
        return Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true);
      case _LayerKind.table:
        return Stack(children: [
          if (bytes != null)
            Positioned.fill(
              child: Opacity(
                opacity: layer.tableOpacity.clamp(0.0, 1.0),
                child: Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
              ),
            ),
          Positioned.fill(child: _buildTextGrid(layer)),
        ]);
      case _LayerKind.sticker:
        if (bytes == null) return const SizedBox.expand();
        return Opacity(
          opacity: layer.stickerOpacity.clamp(0.0, 1.0),
          child: Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
        );
    }
  }

  Widget _buildTextGrid(_EditorLayer layer) {
    if (layer.rows == 0 || layer.subjects.isEmpty) return const SizedBox.expand();
    final tc = layer.tableConfig;
    final scale = layer.size.width / math.max(1, layer.naturalWidth);
    final leftI = (tc?.left ?? 0) * scale;
    final rightI = (tc?.right ?? 0) * scale;
    final topI = (tc?.topInset ?? 0) * scale;
    final botI = (tc?.bottom ?? 0) * scale;
    final usableW = math.max(0.0, layer.size.width - leftI - rightI);
    final usableH = math.max(0.0, layer.size.height - topI - botI);
    final cellW = usableW / 5;
    final cellH = usableH / math.max(1, layer.rows);
    final textColor = _hexToColor(layer.fontColorHex);
    final loadedFamily = _WallpaperFontLoader.shared.loadedFamily(layer.fontFamily);

    return Positioned(
      left: leftI, top: topI, right: rightI, bottom: botI,
      child: Column(
        children: List.generate(layer.rows, (r) {
          final row = r < layer.subjects.length ? layer.subjects[r] : <String>[];
          return SizedBox(
            height: cellH,
            child: Row(
              children: List.generate(5, (c) {
                return SizedBox(
                  width: cellW,
                  child: Center(
                    child: Text(
                      c < row.length ? row[c] : '',
                      style: TextStyle(
                          fontFamily: loadedFamily,
                          fontSize: layer.baseFontSize,
                          color: textColor,
                          height: 1.1),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────── Toolbar ───────────────

  Widget _buildToolbar() {
    final sel = _selectedId != null
        ? _layers.firstWhereOrNull((l) => l.id == _selectedId)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: sel != null
          ? _buildSelectedToolbar(sel)
          : _buildDefaultToolbar(),
    );
  }

  Widget _buildDefaultToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _tbBtn(Icons.add_circle_outline, '新增貼圖', () => _showStickerPicker()),
        const Text('點選圖層即可編輯',
            style: TextStyle(color: Colors.white60, fontSize: 12)),
        _tbBtn(Icons.photo_library_outlined, '從相簿', () => _addStickerFromGallery()),
      ],
    );
  }

  Widget _buildSelectedToolbar(_EditorLayer layer) {
    if (layer.kind == _LayerKind.sticker) {
      final i = _idx(layer.id);
      return Row(
        children: [
          _tbBtn(Icons.photo_library_outlined, '更換', () => _showImagePicker(layer)),
          const SizedBox(width: 8),
          const Icon(Icons.opacity, color: Colors.white, size: 18),
          Expanded(
            child: Slider(
              value: i >= 0 ? _layers[i].stickerOpacity : 1.0,
              min: 0, max: 1, divisions: 20,
              onChanged: (v) => setState(() {
                final idx = _idx(layer.id);
                if (idx >= 0) _layers[idx].stickerOpacity = v;
              }),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${((i >= 0 ? _layers[i].stickerOpacity : 1.0) * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 10),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          _tbBtn(Icons.delete_outline, '刪除', () {
            setState(() {
              _pushUndo();
              _layers.removeWhere((l) => l.id == layer.id);
              _selectedId = null;
            });
          }, color: Colors.redAccent),
          const SizedBox(width: 8),
          _tbBtn(Icons.check, '完成', () => setState(() => _selectedId = null)),
        ],
      );
    }

    // background or table
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _tbBtn(Icons.photo_library_outlined, '更換', () => _showImagePicker(layer)),
        if (layer.kind == _LayerKind.table) ...[
          _tbBtn(Icons.text_fields, '文字', () => _showTextSettings(layer)),
          _tbBtn(Icons.tune, '進階', () => _showAdvancedSettings(layer)),
        ],
        _tbBtn(Icons.check, '完成', () => setState(() => _selectedId = null)),
      ],
    );
  }

  Widget _tbBtn(IconData icon, String label, VoidCallback onTap,
      {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  // ─────────────── Sheets ───────────────

  void _showImagePicker(_EditorLayer layer) {
    if (layer.sourceUrls.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: layer.sourceUrls.length,
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _switchLayerImage(layer.id, layer.sourceUrls[i]);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(fit: StackFit.expand, children: [
                Image.network(layer.sourceUrls[i], fit: BoxFit.cover),
                if (i == layer.sourceIndex)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _showStickerPicker() {
    final stickers = widget.template.images.stickers;
    if (stickers.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('此模板無貼圖')));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: stickers.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () { Navigator.pop(context); _addStickerFromUrl(stickers[i]); },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(stickers[i], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  void _showTextSettings(_EditorLayer layer) {
    final i = _idx(layer.id);
    if (i < 0) return;
    double fontSize = layer.baseFontSize;
    String colorHex = layer.fontColorHex;
    String fontFamily = layer.fontFamily;

    const presetColors = [
      '#000000', '#FFFFFF', '#FF0000', '#FF6600',
      '#FFCC00', '#00AA00', '#0066FF', '#9900CC',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Text('文字設定',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        final idx = _idx(layer.id);
                        if (idx >= 0) {
                          _layers[idx]
                            ..baseFontSize = fontSize
                            ..fontColorHex = colorHex
                            ..fontFamily = fontFamily;
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('完成'),
                  ),
                ]),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 8),
                    const Text('字體大小', style: TextStyle(fontWeight: FontWeight.w500)),
                    Row(children: [
                      Expanded(
                        child: Slider(
                          value: fontSize.clamp(3.0, 24.0),
                          min: 3, max: 24, divisions: 21,
                          onChanged: (v) => setSheet(() => fontSize = v),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text('${fontSize.round()}', textAlign: TextAlign.right),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    const Text('字體顏色', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: [
                        ...presetColors.map((hex) {
                          final selected = colorHex.toUpperCase() == hex.toUpperCase();
                          return GestureDetector(
                            onTap: () => setSheet(() => colorHex = hex),
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: _hexToColor(hex),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected ? Colors.blue : Colors.grey.shade400,
                                  width: selected ? 3 : 1,
                                ),
                              ),
                            ),
                          );
                        }),
                        // 自訂顏色按鈕
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDialog<Color>(
                              context: ctx,
                              builder: (_) => _ColorPickerDialog(
                                initial: _hexToColor(colorHex),
                              ),
                            );
                            if (picked != null) {
                              setSheet(() => colorHex = _colorToHex(picked));
                            }
                          },
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade400),
                              gradient: const SweepGradient(colors: [
                                Colors.red, Colors.yellow, Colors.green,
                                Colors.cyan, Colors.blue, Colors.purple, Colors.red,
                              ]),
                            ),
                            child: const Icon(Icons.add, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(colorHex,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Text('字型', style: TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (_isLoadingFont)
                        const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse('${AppConfig.vocPassApiHost}/font'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('預覽所有字型',
                            style: TextStyle(color: Colors.blue, fontSize: 13)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (_fontList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('字型載入中⋯', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...(_fontList.keys.toList()..sort()).map((name) => InkWell(
                        onTap: _isLoadingFont ? null : () async {
                          setSheet(() => fontFamily = name);
                          if (!mounted) return;
                          setState(() => _isLoadingFont = true);
                          await _WallpaperFontLoader.shared.load(name);
                          if (!mounted) return;
                          setState(() => _isLoadingFont = false);
                          setSheet(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            Text(name),
                            const Spacer(),
                            if (name == fontFamily && _isLoadingFont)
                              const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                            else if (name == fontFamily)
                              const Icon(Icons.check, color: Colors.blue, size: 18),
                          ]),
                        ),
                      )),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdvancedSettings(_EditorLayer layer) {
    final tpl = widget.template;
    final availablePeriods = tpl.images.table.keys
        .map(int.tryParse)
        .whereType<int>()
        .toList()
      ..sort();
    double opacity = layer.tableOpacity;
    int currentPeriods = layer.rows;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('進階設定',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      final i = _idx(layer.id);
                      if (i >= 0) _layers[i].tableOpacity = opacity;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('完成'),
                ),
              ]),
              const SizedBox(height: 16),
              const Text('課表透明度', style: TextStyle(fontWeight: FontWeight.w500)),
              Row(children: [
                Expanded(
                  child: Slider(
                    value: opacity,
                    min: 0, max: 1, divisions: 20,
                    label: '${(opacity * 100).round()}%',
                    onChanged: (v) {
                      setSheet(() => opacity = v);
                      setState(() {
                        final i = _idx(layer.id);
                        if (i >= 0) _layers[i].tableOpacity = v;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text('${(opacity * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12)),
                ),
              ]),
              if (availablePeriods.length > 1) ...[
                const SizedBox(height: 12),
                const Text('節數', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: availablePeriods.map((p) {
                    final sel = p == currentPeriods;
                    return ChoiceChip(
                      label: Text('$p 節'),
                      selected: sel,
                      onSelected: (_) {
                        setSheet(() => currentPeriods = p);
                        Navigator.pop(ctx);
                        _switchPeriodCount(layer.id, p);
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────── Util ───────────────

Color _hexToColor(String hex) {
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length == 8) return Color(int.parse(h, radix: 16));
  return Colors.black;
}

String _colorToHex(Color color) {
  final r = (color.r * 255).round();
  final g = (color.g * 255).round();
  final b = (color.b * 255).round();
  return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
}

extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

// ─────────────── Color picker dialog ───────────────

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _ColorPickerDialog({required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _h, _s, _v;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initial);
    _h = hsv.hue;
    _s = hsv.saturation;
    _v = hsv.value;
  }

  Color get _current => HSVColor.fromAHSV(1, _h, _s, _v).toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自訂顏色'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Preview
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: _current,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(height: 12),
          // Hue
          _sliderRow('色相', _h, 0, 360, (v) => setState(() => _h = v),
              activeColor: HSVColor.fromAHSV(1, _h, 1, 1).toColor()),
          _sliderRow('飽和度', _s, 0, 1, (v) => setState(() => _s = v)),
          _sliderRow('明度', _v, 0, 1, (v) => setState(() => _v = v)),
          const SizedBox(height: 4),
          Text(_colorToHex(_current),
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _current),
          child: const Text('確定'),
        ),
      ],
    );
  }

  Widget _sliderRow(String label, double value, double min, double max,
      ValueChanged<double> onChanged, {Color? activeColor}) {
    return Row(children: [
      SizedBox(width: 48, child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(
        child: SliderTheme(
          data: activeColor != null
              ? SliderTheme.of(context).copyWith(activeTrackColor: activeColor,
                  thumbColor: activeColor)
              : SliderTheme.of(context),
          child: Slider(value: value, min: min, max: max,
              onChanged: onChanged),
        ),
      ),
    ]);
  }
}

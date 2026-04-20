import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../services/cache_service.dart';
import '../../models/models.dart';
import 'wallpaper_template_list_screen.dart';

// ─────────────────────────── Layer model ───────────────────────────

enum _LayerKind { background, table, sticker }

class _EditorLayer {
  String id;
  _LayerKind kind;
  Uint8List? imageBytes;
  // Natural (original) image dimensions — used to scale inset values
  double naturalWidth;
  double naturalHeight;
  List<String> sourceUrls;
  int sourceIndex;
  Offset center; // center in canvas-local coordinates
  Size size;
  double rotation;
  // table-specific
  List<List<String>> subjects;
  int rows;
  double baseFontSize;
  String fontColorHex;
  double tableOpacity;
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
    this.tableOpacity = 1.0,
    this.tableConfig,
  });

  _EditorLayer copyWith({
    Uint8List? imageBytes,
    double? naturalWidth,
    double? naturalHeight,
    Offset? center,
    Size? size,
    double? rotation,
    double? tableOpacity,
  }) {
    return _EditorLayer(
      id: id,
      kind: kind,
      imageBytes: imageBytes ?? this.imageBytes,
      naturalWidth: naturalWidth ?? this.naturalWidth,
      naturalHeight: naturalHeight ?? this.naturalHeight,
      sourceUrls: sourceUrls,
      sourceIndex: sourceIndex,
      center: center ?? this.center,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      subjects: subjects,
      rows: rows,
      baseFontSize: baseFontSize,
      fontColorHex: fontColorHex,
      tableOpacity: tableOpacity ?? this.tableOpacity,
      tableConfig: tableConfig,
    );
  }
}

// ─────────────────────────── Image cache ───────────────────────────

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

// ─────────────────────────── Timetable helpers ───────────────────────────

const _chineseNum = {
  '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7,
  '八': 8, '九': 9, '十': 10, '十一': 11, '十二': 12,
  '十三': 13, '十四': 14, '十五': 15,
};
const _periodNames = [
  '一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二', '十三', '十四', '十五'
];
const _weekdays = ['一', '二', '三', '四', '五'];

const _placeholders = [
  '國文', '英文', '數學', '物理', '化學', '生物', '地科',
  '歷史', '地理', '公民', '體育', '音樂', '美術', '資訊',
  '健護', '家政', '生科', '國防', '輔導', '社團', '班會',
];

int _parseChinesePeriod(String p) {
  return _chineseNum[p] ?? int.tryParse(p) ?? 0;
}

int _computeMaxPeriod(TimetableData? t) {
  if (t == null) return 8;
  int max = 0;
  for (final e in t.entries) {
    final n = _parseChinesePeriod(e.period);
    if (n > max) max = n;
  }
  for (final info in t.curriculum.values) {
    for (final s in info.schedule) {
      final n = _parseChinesePeriod(s.period);
      if (n > max) max = n;
    }
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
        final weekday = _weekdays[c];
        // Check curriculum
        for (final entry in t.curriculum.entries) {
          for (final s in entry.value.schedule) {
            if (s.weekday == weekday && s.period == periodKey) {
              grid[r][c] = entry.key;
            }
          }
        }
        // Check entries if still empty
        if (grid[r][c].isEmpty) {
          for (final e in t.entries) {
            if (e.weekday == weekday && e.period == periodKey) {
              grid[r][c] = e.subject;
              break;
            }
          }
        }
      }
    }
  }

  // Fill empty with placeholder
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

  // Gesture state
  Offset? _panStart;
  Offset? _layerCenterStart;
  double? _scaleStart;
  Size? _layerSizeStart;
  double? _rotationStart;
  double? _layerRotationStart;

  // Undo stack
  final List<List<_EditorLayer>> _undoStack = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading && _canvasSize == Size.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _preload());
    }
  }

  Size _computeCanvasSize(Size screen) {
    const aspect = 9.0 / 19.5;
    final safeW = math.min(screen.width - 16, 500.0);
    final safeH = screen.height - 180.0;
    var w = safeW;
    var h = w / aspect;
    if (h > safeH) {
      h = safeH;
      w = h * aspect;
    }
    return Size(w, h);
  }

  Future<void> _preload() async {
    final screen = MediaQuery.of(context).size;
    final canvas = _computeCanvasSize(screen);

    setState(() {
      _isLoading = true;
      _loadError = null;
      _canvasSize = canvas;
    });

    try {
      final tpl = widget.template;
      final cache = Provider.of<CacheService>(context, listen: false);
      final timetable = cache.getCachedTimetable();
      final userMax = _computeMaxPeriod(timetable);

      // Pick table key
      final chosenKey = _pickTableKey(tpl, userMax);
      if (chosenKey == null) {
        throw Exception('此模板最多不支援 $userMax 節的課表');
      }
      final tableConfig = tpl.images.table[chosenKey]!;
      if (tableConfig.images.isEmpty) throw Exception('模板缺少課表圖片');

      // Load images
      final bgUrl = tpl.images.background.firstOrNull ?? '';
      final tableUrl = tableConfig.images.first;

      final [(bgBytes, bgW, bgH), (tableBytes, tableW, tableH)] =
          await Future.wait([
        _fetchImageWithSize(bgUrl),
        _fetchImageWithSize(tableUrl),
      ]);

      // Pre-warm sticker images in background
      for (final url in tpl.images.stickers) {
        _fetchImage(url);
      }

      final cw = canvas.width;
      final ch = canvas.height;
      final rows = int.tryParse(chosenKey) ?? userMax;

      final baseFont = tpl.fontSize != null
          ? tpl.fontSize!
          : () {
              final scale = cw / tableW;
              final leftI = tableConfig.left * scale;
              final rightI = tableConfig.right * scale;
              final usableW = (cw - leftI - rightI).clamp(0.0, double.infinity);
              final tblDispH = cw * (tableH / tableW);
              final cellW = usableW / 5;
              final cellH = tblDispH / math.max(rows, 1);
              return math.max(8.0, math.min(cellW, cellH) * 0.32);
            }();

      final tableDisplayH = cw * (tableH / tableW);
      final tableTop = ch * (tpl.top / 100.0);
      final tableCenter = Offset(cw / 2, tableTop + tableDisplayH / 2);
      final subjects = _buildSubjectGrid(timetable, rows);

      final newLayers = [
        _EditorLayer(
          id: UniqueKey().toString(),
          kind: _LayerKind.background,
          imageBytes: bgBytes,
          naturalWidth: bgW,
          naturalHeight: bgH,
          sourceUrls: tpl.images.background,
          center: Offset(cw / 2, ch / 2),
          size: Size(cw, ch),
        ),
        _EditorLayer(
          id: UniqueKey().toString(),
          kind: _LayerKind.table,
          imageBytes: tableBytes,
          naturalWidth: tableW,
          naturalHeight: tableH,
          sourceUrls: tableConfig.images,
          center: tableCenter,
          size: Size(cw, tableDisplayH),
          subjects: subjects,
          rows: rows,
          baseFontSize: baseFont,
          fontColorHex: tpl.fontColor ?? '#000000',
          tableOpacity: tpl.tableOpacity ?? 1.0,
          tableConfig: tableConfig,
        ),
      ];

      // Add random stickers
      final rng = math.Random();
      final stickerUrls = tpl.images.stickers;
      if (stickerUrls.isNotEmpty) {
        for (int i = 0; i < tpl.stickers; i++) {
          final url = stickerUrls[rng.nextInt(stickerUrls.length)];
          final stickerBytes = await _fetchImage(url);
          if (stickerBytes != null) {
            const baseW = 80.0;
            final codec = await ui.instantiateImageCodec(stickerBytes);
            final frame = await codec.getNextFrame();
            final img = frame.image;
            final baseH = baseW * img.height / math.max(1, img.width);
            final cx = baseW + rng.nextDouble() * (cw - 2 * baseW);
            final cy = baseH + rng.nextDouble() * (ch - 2 * baseH);
            newLayers.add(_EditorLayer(
              id: UniqueKey().toString(),
              kind: _LayerKind.sticker,
              imageBytes: stickerBytes,
              naturalWidth: img.width.toDouble(),
              naturalHeight: img.height.toDouble(),
              sourceUrls: stickerUrls,
              center: Offset(cx, cy),
              size: Size(baseW, baseH),
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _layers = newLayers;
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

  void _pushUndo() {
    _undoStack.add(_layers.map((l) => _EditorLayer(
          id: l.id,
          kind: l.kind,
          imageBytes: l.imageBytes,
          naturalWidth: l.naturalWidth,
          naturalHeight: l.naturalHeight,
          sourceUrls: l.sourceUrls,
          sourceIndex: l.sourceIndex,
          center: l.center,
          size: l.size,
          rotation: l.rotation,
          subjects: l.subjects,
          rows: l.rows,
          baseFontSize: l.baseFontSize,
          fontColorHex: l.fontColorHex,
          tableOpacity: l.tableOpacity,
          tableConfig: l.tableConfig,
        )).toList());
    if (_undoStack.length > 30) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _layers = _undoStack.removeLast();
      if (_selectedId != null &&
          !_layers.any((l) => l.id == _selectedId)) {
        _selectedId = null;
      }
    });
  }

  int _layerIndex(String id) => _layers.indexWhere((l) => l.id == id);

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      // Render at ~3× for high quality
      final pixelRatio = 1242.0 / _canvasSize.width;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('無法匯出圖片');

      await Gal.putImageBytes(byteData.buffer.asUint8List());
      _reportUsage();

      if (mounted) {
        setState(() => _isSaving = false);
        _showSavedDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗：$e')),
        );
      }
    }
  }

  void _reportUsage() {
    final name = Uri.encodeComponent(widget.template.name);
    final url =
        '${AppConfig.vocPassApiHost}/api/wallpaper/curriculum/status?wallpaper_name=$name';
    http.post(Uri.parse(url));
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
              final authorUrl = widget.template.authorUrl;
              if (authorUrl != null) {
                final uri = Uri.parse(authorUrl);
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

  Future<void> _addStickerFromUrl(String url) async {
    final bytes = await _fetchImage(url);
    if (bytes == null || !mounted) return;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final rng = math.Random();
    const baseW = 80.0;
    final baseH = baseW * img.height / math.max(1, img.width);
    final cx = baseW + rng.nextDouble() * (_canvasSize.width - 2 * baseW);
    final cy = baseH + rng.nextDouble() * (_canvasSize.height - 2 * baseH);
    setState(() {
      _pushUndo();
      _layers.add(_EditorLayer(
        id: UniqueKey().toString(),
        kind: _LayerKind.sticker,
        imageBytes: bytes,
        naturalWidth: img.width.toDouble(),
        naturalHeight: img.height.toDouble(),
        sourceUrls: widget.template.images.stickers,
        center: Offset(cx, cy),
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
      final i = _layerIndex(layerId);
      if (i < 0) return;
      _pushUndo();
      final old = _layers[i];
      final newIdx = old.sourceUrls.indexOf(url);
      final newH = old.kind == _LayerKind.background
          ? old.size.height
          : old.size.width * img.height / math.max(1, img.width);
      _layers[i] = _EditorLayer(
        id: old.id,
        kind: old.kind,
        imageBytes: bytes,
        naturalWidth: img.width.toDouble(),
        naturalHeight: img.height.toDouble(),
        sourceUrls: old.sourceUrls,
        sourceIndex: newIdx >= 0 ? newIdx : old.sourceIndex,
        center: old.center,
        size: Size(old.size.width, newH),
        rotation: old.rotation,
        subjects: old.subjects,
        rows: old.rows,
        baseFontSize: old.baseFontSize,
        fontColorHex: old.fontColorHex,
        tableOpacity: old.tableOpacity,
        tableConfig: old.tableConfig,
      );
    });
  }

  // ────────────────────────── Gestures ──────────────────────────────

  void _onScaleStart(ScaleStartDetails d, String layerId) {
    final i = _layerIndex(layerId);
    if (i < 0) return;
    _pushUndo();
    _panStart = d.localFocalPoint;
    _layerCenterStart = _layers[i].center;
    _scaleStart = 1.0;
    _layerSizeStart = _layers[i].size;
    _rotationStart = 0.0;
    _layerRotationStart = _layers[i].rotation;
    setState(() => _selectedId = layerId);
  }

  void _onScaleUpdate(ScaleUpdateDetails d, String layerId) {
    final i = _layerIndex(layerId);
    if (i < 0) return;
    setState(() {
      final layer = _layers[i];
      // Pan
      final delta = d.localFocalPoint - _panStart!;
      final newCenter = _layerCenterStart! + delta;
      // Scale
      final newW = math.max(30.0, _layerSizeStart!.width * d.scale);
      final newH = math.max(30.0, _layerSizeStart!.height * d.scale);
      // Rotation (stickers only)
      final newRot = layer.kind == _LayerKind.sticker
          ? _layerRotationStart! + d.rotation
          : layer.rotation;

      _layers[i] = _EditorLayer(
        id: layer.id,
        kind: layer.kind,
        imageBytes: layer.imageBytes,
        naturalWidth: layer.naturalWidth,
        naturalHeight: layer.naturalHeight,
        sourceUrls: layer.sourceUrls,
        sourceIndex: layer.sourceIndex,
        center: newCenter,
        size: Size(newW, newH),
        rotation: newRot,
        subjects: layer.subjects,
        rows: layer.rows,
        baseFontSize: layer.baseFontSize,
        fontColorHex: layer.fontColorHex,
        tableOpacity: layer.tableOpacity,
        tableConfig: layer.tableConfig,
      );
    });
  }

  void _onScaleEnd(ScaleEndDetails d, String layerId) {
    _panStart = null;
    _layerCenterStart = null;
    _scaleStart = null;
    _layerSizeStart = null;
    _rotationStart = null;
    _layerRotationStart = null;
  }

  // ────────────────────────── Build ──────────────────────────────

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
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_alt),
            onPressed: _isLoading || _isSaving ? null : _save,
            color: Colors.white,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text('正在施加魔法⋯',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            )
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 48, color: Colors.orange),
                        const SizedBox(height: 12),
                        Text(_loadError!,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _preload, child: const Text('重試')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(child: _buildCanvas()),
                    _buildToolbar(),
                    const SizedBox(height: 12),
                  ],
                ),
    );
  }

  Widget _buildCanvas() {
    return Center(
      child: LayoutBuilder(builder: (context, constraints) {
        final size = _computeCanvasSize(
            Size(constraints.maxWidth, constraints.maxHeight + 200));
        return SizedBox(
          width: size.width,
          height: size.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: RepaintBoundary(
              key: _boundaryKey,
              child: GestureDetector(
                onTap: () => setState(() => _selectedId = null),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Background color
                    Positioned.fill(
                      child: Container(color: Colors.grey.shade300),
                    ),
                    // Layers
                    ..._layers.map((layer) => _buildLayerWidget(layer, size)),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLayerWidget(_EditorLayer layer, Size canvasSize) {
    final isSelected = layer.id == _selectedId;
    final left = layer.center.dx - layer.size.width / 2;
    final top = layer.center.dy - layer.size.height / 2;

    return Positioned(
      left: left,
      top: top,
      width: layer.size.width,
      height: layer.size.height,
      child: Transform.rotate(
        angle: layer.rotation,
        child: GestureDetector(
          onScaleStart: (d) => _onScaleStart(d, layer.id),
          onScaleUpdate: (d) => _onScaleUpdate(d, layer.id),
          onScaleEnd: (d) => _onScaleEnd(d, layer.id),
          onTap: () => setState(() => _selectedId = layer.id),
          child: Stack(
            children: [
              // Layer content
              Positioned.fill(child: _buildLayerContent(layer)),
              // Selection border
              if (isSelected)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.blue,
                          width: 2,
                        ),
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
        if (bytes == null) return const SizedBox();
        return Image.memory(bytes, fit: BoxFit.fill,
            width: layer.size.width, height: layer.size.height);

      case _LayerKind.table:
        return Stack(
          children: [
            if (bytes != null)
              Opacity(
                opacity: layer.tableOpacity,
                child: Image.memory(bytes,
                    fit: BoxFit.fill,
                    width: layer.size.width,
                    height: layer.size.height),
              ),
            Positioned.fill(child: _buildTextGrid(layer)),
          ],
        );

      case _LayerKind.sticker:
        if (bytes == null) return const SizedBox();
        return Image.memory(bytes, fit: BoxFit.fill,
            width: layer.size.width, height: layer.size.height);
    }
  }

  Widget _buildTextGrid(_EditorLayer layer) {
    if (layer.rows == 0 || layer.subjects.isEmpty) return const SizedBox();
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
    final fontSize = layer.baseFontSize;
    final textColor = _hexToColor(layer.fontColorHex);

    return Padding(
      padding: EdgeInsets.only(
          left: leftI, right: rightI, top: topI, bottom: botI),
      child: Column(
        children: List.generate(layer.rows, (r) {
          final row = layer.subjects.length > r ? layer.subjects[r] : [];
          return SizedBox(
            height: cellH,
            child: Row(
              children: List.generate(5, (c) {
                final text = row.length > c ? row[c] : '';
                return SizedBox(
                  width: cellW,
                  height: cellH,
                  child: Center(
                    child: Text(
                      text,
                      style: TextStyle(
                          fontSize: fontSize,
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

  // ────────────────────────── Toolbar ──────────────────────────────

  Widget _buildToolbar() {
    final selected = _selectedId != null
        ? _layers.firstWhere((l) => l.id == _selectedId,
            orElse: () => _layers.first)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(30),
        ),
        child: selected != null
            ? _buildSelectedToolbar(selected)
            : _buildDefaultToolbar(),
      ),
    );
  }

  Widget _buildSelectedToolbar(_EditorLayer layer) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Switch image
        _toolbarButton(Icons.photo_library, '更換', () {
          _showImagePicker(layer);
        }),
        // Table opacity if table layer
        if (layer.kind == _LayerKind.table) ...[
          _toolbarButton(Icons.opacity, '透明度', () {
            _showOpacityDialog(layer);
          }),
        ],
        // Delete sticker
        if (layer.kind == _LayerKind.sticker)
          _toolbarButton(Icons.delete_outline, '刪除', () {
            setState(() {
              _pushUndo();
              _layers.removeWhere((l) => l.id == layer.id);
              _selectedId = null;
            });
          }, color: Colors.redAccent),
        // Deselect
        _toolbarButton(Icons.check, '完成', () {
          setState(() => _selectedId = null);
        }),
      ],
    );
  }

  Widget _buildDefaultToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _toolbarButton(Icons.add_circle_outline, '新增貼圖', () {
          _showStickerPicker();
        }),
        const Text('點選圖層即可編輯',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _toolbarButton(IconData icon, String label, VoidCallback onTap,
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

  void _showImagePicker(_EditorLayer layer) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: layer.sourceUrls.length,
          itemBuilder: (context, i) {
            final url = layer.sourceUrls[i];
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _switchLayerImage(layer.id, url);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(url, fit: BoxFit.cover),
                    if (i == layer.sourceIndex)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.blue, width: 3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
      builder: (_) {
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: stickers.length,
          itemBuilder: (context, i) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _addStickerFromUrl(stickers[i]);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(stickers[i], fit: BoxFit.contain),
              ),
            );
          },
        );
      },
    );
  }

  void _showOpacityDialog(_EditorLayer layer) {
    double currentOpacity = layer.tableOpacity;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('課表透明度'),
          content: Slider(
            value: currentOpacity,
            min: 0,
            max: 1,
            divisions: 20,
            label: '${(currentOpacity * 100).round()}%',
            onChanged: (v) {
              setDlgState(() => currentOpacity = v);
              setState(() {
                final i = _layerIndex(layer.id);
                if (i >= 0) {
                  final old = _layers[i];
                  _layers[i] = _EditorLayer(
                    id: old.id,
                    kind: old.kind,
                    imageBytes: old.imageBytes,
                    naturalWidth: old.naturalWidth,
                    naturalHeight: old.naturalHeight,
                    sourceUrls: old.sourceUrls,
                    sourceIndex: old.sourceIndex,
                    center: old.center,
                    size: old.size,
                    rotation: old.rotation,
                    subjects: old.subjects,
                    rows: old.rows,
                    baseFontSize: old.baseFontSize,
                    fontColorHex: old.fontColorHex,
                    tableOpacity: v,
                    tableConfig: old.tableConfig,
                  );
                }
              });
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成')),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Helpers ───────────────────────────

Color _hexToColor(String hex) {
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length == 8) {
    return Color(int.parse(h, radix: 16));
  }
  return Colors.black;
}

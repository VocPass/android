import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/school_config_manager.dart';
import 'unsupported_screen.dart';

class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({super.key});

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  Map<String, CourseInfo> _curriculum = {};
  Map<String, PeriodTime> _apiPeriodTimes = {};
  bool _isLoading = true;
  String? _error;
  bool _unsupported = false;

  // 手動覆寫
  late Map<String, String> _manualCurriculum;
  late Map<String, CourseExtra> _manualRoomTeacher;
  late Map<String, PeriodTime> _manualPeriodTimes;
  late int _periodsPerDay;

  final _weekdays = const ['一', '二', '三', '四', '五'];
  List<String> get _periods {
    final numericPeriods = const [
      '一', '二', '三', '四', '五', '六', '七', '八', '九', '十',
      '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
      '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
      '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
    ];

    final allDataPeriods = <String>{};
    for (final info in _curriculum.values) {
      for (final s in info.schedule) {
        allDataPeriods.add(s.period);
      }
    }
    for (final key in _manualCurriculum.keys) {
      final parts = key.split('|');
      if (parts.length == 2) allDataPeriods.add(parts[1]);
    }

    // 計算資料中實際最高節次，顯示 max(設定值, 實際節數)
    int maxDataPeriod = 0;
    for (final p in allDataPeriods) {
      final idx = numericPeriods.indexOf(p);
      if (idx >= 0 && idx < numericPeriods.length ~/ 2) {
        maxDataPeriod = maxDataPeriod > idx + 1 ? maxDataPeriod : idx + 1;
      } else {
        final n = int.tryParse(p);
        if (n != null && n > maxDataPeriod) maxDataPeriod = n;
      }
    }
    final displayCount = maxDataPeriod > _periodsPerDay ? maxDataPeriod : _periodsPerDay;

    final result = <String>[];
    if (allDataPeriods.contains('早讀')) result.add('早讀');
    result.addAll(numericPeriods.take(displayCount));
    return result;
  }

  @override
  void initState() {
    super.initState();
    final cache = CacheService.instance;
    _manualCurriculum = Map.from(cache.manualCurriculum);
    _manualRoomTeacher = Map.from(cache.manualRoomTeacher);
    _manualPeriodTimes = Map.from(cache.manualPeriodTimes);
    _periodsPerDay = cache.periodsPerDay;

    final cached = cache.getCachedTimetable();
    if (cached != null) {
      _curriculum = cached.curriculum;
      _apiPeriodTimes = cached.periodTimes;
      _isLoading = false;
    }

    final isGuest = SchoolConfigManager.instance.selectedSchool?.isGuest == true;
    if (isGuest) {
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (_curriculum.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final api = context.read<ApiService>();
      final data = await api.fetchTimetableData(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _curriculum = data.curriculum;
        _apiPeriodTimes = data.periodTimes;
        _isLoading = false;
        _error = null;
        _unsupported = false;
      });
    } on ApiException catch (e) {
      if (e.type == ApiErrorType.featureNotSupported) {
        if (!mounted) return;
        setState(() {
          _unsupported = true;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '課表載入失敗';
        _isLoading = false;
      });
    }
  }

  String _manualKey(String weekday, String period) => '$weekday|$period';

  String _apiSubject(String weekday, String period) {
    for (final entry in _curriculum.entries) {
      for (final s in entry.value.schedule) {
        if (s.weekday == weekday && s.period == period) return entry.key;
      }
    }
    return '';
  }

  CourseExtra _apiExtra(String weekday, String period) {
    for (final info in _curriculum.values) {
      for (final s in info.schedule) {
        if (s.weekday == weekday && s.period == period) {
          return CourseExtra(room: '', teacher: '');
        }
      }
    }
    return CourseExtra(room: '', teacher: '');
  }

  String _getSubject(String weekday, String period) {
    final key = _manualKey(weekday, period);
    if (_manualCurriculum.containsKey(key)) return _manualCurriculum[key]!;
    return _apiSubject(weekday, period);
  }

  CourseExtra _getExtra(String weekday, String period) {
    final key = _manualKey(weekday, period);
    if (_manualRoomTeacher.containsKey(key)) return _manualRoomTeacher[key]!;
    return _apiExtra(weekday, period);
  }

  PeriodTime? _effectivePeriodTime(String period) {
    return _manualPeriodTimes[period] ?? _apiPeriodTimes[period];
  }

  Color _randomColor(String subject) {
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.pink, Colors.cyan, Colors.teal, Colors.indigo,
    ];
    return colors[subject.hashCode.abs() % colors.length];
  }

  void _showCellEditSheet(String weekday, String period) {
    final key = _manualKey(weekday, period);
    final currentSubject = _getSubject(weekday, period);
    final currentExtra = _getExtra(weekday, period);
    final apiSubject = _apiSubject(weekday, period);
    final apiExtra = _apiExtra(weekday, period);
    final hasManual = _manualCurriculum.containsKey(key) ||
        _manualRoomTeacher.containsKey(key);

    final subjectController = TextEditingController(text: currentSubject);
    final roomController = TextEditingController(text: currentExtra.room);
    final teacherController = TextEditingController(text: currentExtra.teacher);

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
            Row(
              children: [
                Text('週$weekday 第$period節',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: '科目名稱',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.door_front_door_outlined, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: '教室（選填）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: teacherController,
                    decoration: const InputDecoration(
                      labelText: '教師（選填）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (apiSubject.isNotEmpty &&
                (apiSubject != subjectController.text ||
                    apiExtra.room != roomController.text ||
                    apiExtra.teacher != teacherController.text)) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  subjectController.text = apiSubject;
                  roomController.text = apiExtra.room;
                  teacherController.text = apiExtra.teacher;
                },
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('還原為課表資料'),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (hasManual)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _manualCurriculum.remove(key);
                          _manualRoomTeacher.remove(key);
                          CacheService.instance.manualCurriculum = _manualCurriculum;
                          CacheService.instance.manualRoomTeacher = _manualRoomTeacher;
                        });
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('清除手動設定'),
                    ),
                  ),
                if (hasManual) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _manualCurriculum[key] = subjectController.text;
                        CacheService.instance.manualCurriculum = _manualCurriculum;
                        final room = roomController.text.trim();
                        final teacher = teacherController.text.trim();
                        if (room.isEmpty && teacher.isEmpty) {
                          _manualRoomTeacher.remove(key);
                        } else {
                          _manualRoomTeacher[key] =
                              CourseExtra(room: room, teacher: teacher);
                        }
                        CacheService.instance.manualRoomTeacher = _manualRoomTeacher;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('儲存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPeriodTimeEditSheet(String period) {
    final apiTime = _apiPeriodTimes[period];
    final manualTime = _manualPeriodTimes[period];
    final source = manualTime ?? apiTime;

    TimeOfDay startTime = _parseTime(source?.startTime) ?? const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = _parseTime(source?.endTime) ?? const TimeOfDay(hour: 8, minute: 50);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('第$period節時間',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('開始'),
                trailing: Text(_formatTime(startTime)),
                onTap: () async {
                  final picked = await showTimePicker(
                      context: ctx, initialTime: startTime);
                  if (picked != null) setSheetState(() => startTime = picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.stop),
                title: const Text('結束'),
                trailing: Text(_formatTime(endTime)),
                onTap: () async {
                  final picked = await showTimePicker(
                      context: ctx, initialTime: endTime);
                  if (picked != null) setSheetState(() => endTime = picked);
                },
              ),
              if (apiTime != null) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () {
                    final s = _parseTime(apiTime.startTime);
                    final e = _parseTime(apiTime.endTime);
                    if (s != null && e != null) {
                      setSheetState(() {
                        startTime = s;
                        endTime = e;
                      });
                    }
                  },
                  icon: const Icon(Icons.undo, size: 16),
                  label: Text(
                    '還原為課表資料：${apiTime.startTime}～${apiTime.endTime}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (manualTime != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _manualPeriodTimes.remove(period);
                            CacheService.instance.manualPeriodTimes =
                                _manualPeriodTimes;
                          });
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        child: const Text('清除手動設定'),
                      ),
                    ),
                  if (manualTime != null) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _manualPeriodTimes[period] = PeriodTime(
                            startTime: _formatTime(startTime),
                            endTime: _formatTime(endTime),
                          );
                          CacheService.instance.manualPeriodTimes =
                              _manualPeriodTimes;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('儲存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TimeOfDay? _parseTime(String? str) {
    if (str == null || str.isEmpty) return null;
    final parts = str.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('課表'),
        actions: [
          if (SchoolConfigManager.instance.selectedSchool?.isGuest != true)
            IconButton(
              onPressed: _isLoading ? null : () => _loadData(forceRefresh: true),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _curriculum.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_unsupported) {
      return Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('此學校尚未支援自動課表，可手動輸入',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          ),
          Expanded(child: _buildGrid()),
        ],
      );
    }
    if (_error != null && _curriculum.isEmpty) {
      return UnsupportedScreen(
        title: '載入失敗',
        message: _error!,
        onRetry: _loadData,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      child: _buildGrid(),
    );
  }

  Widget _buildGrid() {
    final periods = _periods;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_error != null && _curriculum.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => _loadData(forceRefresh: true),
                  child: const Text('重試', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Table(
            border: TableBorder.all(color: Colors.grey[300]!, width: 0.5),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {0: FixedColumnWidth(42)},
            children: [
              // Header
              TableRow(children: [
                _headerCell('節次'),
                ..._weekdays.map((d) => _headerCell('週$d')),
              ]),
              // Rows
              ...periods.map((period) => TableRow(children: [
                    _periodCell(period),
                    ..._weekdays.map((day) => _subjectCell(day, period)),
                  ])),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '點擊格子可手動輸入科目',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
        ),
        Text(
          '有課的節次自動顯示；可至「設定 › 課表」設定最少顯示節數（目前 $_periodsPerDay 節）',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _headerCell(String text) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _periodCell(String period) {
    final pt = _effectivePeriodTime(period);
    final isManual = _manualPeriodTimes.containsKey(period);
    return GestureDetector(
      onTap: () => _showPeriodTimeEditSheet(period),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: isManual
            ? Colors.orange.withValues(alpha: 0.12)
            : Colors.grey[100],
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(period == '早讀' ? '讀' : period,
                style: const TextStyle(fontSize: 12)),
            if (pt != null) ...[
              Text(pt.startTime,
                  style: const TextStyle(fontSize: 7, color: Colors.grey)),
              Text(pt.endTime,
                  style: const TextStyle(fontSize: 7, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _subjectCell(String weekday, String period) {
    final subject = _getSubject(weekday, period);
    final extra = _getExtra(weekday, period);
    final key = _manualKey(weekday, period);
    final isManual = _manualCurriculum.containsKey(key) ||
        _manualRoomTeacher.containsKey(key);
    final meta = [extra.room, extra.teacher]
        .where((s) => s.isNotEmpty)
        .join('・');

    return GestureDetector(
      onTap: () => _showCellEditSheet(weekday, period),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        color: subject.isEmpty
            ? Colors.white
            : _randomColor(subject).withValues(alpha: 0.12),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (subject.isNotEmpty)
                      Text(
                        subject,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 8, color: Colors.grey),
                        maxLines: 2,
                      ),
                  ],
                ),
              ),
            ),
            if (isManual)
              const Positioned(
                top: 2,
                right: 2,
                child: SizedBox(
                  width: 5,
                  height: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

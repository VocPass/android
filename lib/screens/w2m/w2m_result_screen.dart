import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/w2m_models.dart';
import '../../services/vocpass_auth_service.dart';
import '../../services/w2m_service.dart';
import 'w2m_availability_screen.dart';

class W2MResultScreen extends StatefulWidget {
  final String eventID;
  final String? creatorID;

  const W2MResultScreen({super.key, required this.eventID, this.creatorID});

  @override
  State<W2MResultScreen> createState() => _W2MResultScreenState();
}

class _W2MResultScreenState extends State<W2MResultScreen> {
  W2MEvent? _event;
  bool _isLoading = true;
  String? _errorMessage;

  String? _selectedSlot; // slotLabel of tapped cell
  String? _focusedUserID;

  static const double _cellHeight = 26;
  static const double _timeColWidth = 44;
  static const double _headerHeight = 36;

  final _times = w2mDisplayTimes();

  bool get _isCreator {
    final auth = VocPassAuthService.instance;
    if (!auth.isLoggedIn || auth.currentUser == null) return false;
    final creatorId = _event?.creator?.id ?? widget.creatorID;
    return creatorId == auth.currentUser!.id;
  }

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final event = await W2MService.instance.fetchEvent(widget.eventID);
      if (mounted) setState(() => _event = event);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _currentUserSlots() {
    final user = VocPassAuthService.instance.currentUser;
    if (user == null || _event == null) return [];
    return _event!.availability
            .firstWhere((a) => a.user.id == user.id,
                orElse: () => W2MUserAvailability(
                    user: W2MUserInfo(id: '', name: ''), slots: []))
            .slots;
  }

  double _cellWidth(double totalWidth, int dateCount) {
    final natural =
        (totalWidth - _timeColWidth) / dateCount.clamp(1, 999);
    return dateCount <= 5 ? (natural < 52 ? 52 : natural) : 64;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<VocPassAuthService>();
    final event = _event;

    return Scaffold(
      appBar: AppBar(
        title: Text(event?.title ?? '出來玩'),
        actions: [
          if (_isCreator)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditSheet(event!),
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareEvent(),
          ),
        ],
      ),
      body: _buildBody(event, auth),
    );
  }

  Widget _buildBody(W2MEvent? event, VocPassAuthService auth) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (event == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_errorMessage ?? '無法載入活動',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: _loadEvent, child: const Text('重試')),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = _cellWidth(constraints.maxWidth, event.dates.length);
        return Column(
          children: [
            Expanded(child: _buildHeatmap(event, cw)),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              child: _selectedSlot != null
                  ? _buildSlotDetailBar(event, _selectedSlot!)
                  : _focusedUserID != null
                      ? _buildFocusedUserBar(event, _focusedUserID!)
                      : const SizedBox.shrink(),
            ),
            _buildBottomBar(event, auth),
          ],
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────
  // HEATMAP GRID
  // ──────────────────────────────────────────────────────

  Widget _buildHeatmap(W2MEvent event, double cellWidth) {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed time column
          SizedBox(
            width: _timeColWidth,
            child: Column(
              children: [
                SizedBox(height: _headerHeight + 1),
                ..._times.map((time) => SizedBox(
                      width: _timeColWidth,
                      height: _cellHeight,
                      child: time.endsWith(':00')
                          ? Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(right: 4, top: 1),
                                child: Text(time,
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.grey)),
                              ),
                            )
                          : null,
                    )),
              ],
            ),
          ),
          // Scrollable date columns
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: cellWidth * event.dates.length,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header row
                    Container(
                      height: _headerHeight,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Row(
                        children: event.dates
                            .map((date) => SizedBox(
                                  width: cellWidth,
                                  child: Center(
                                    child: Text(
                                      w2mShortDate(date),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const Divider(height: 1),
                    // Heat columns
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: event.dates
                          .map((date) =>
                              _buildHeatColumn(event, date, cellWidth))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatColumn(W2MEvent event, String date, double cellWidth) {
    final focusedSlots = _focusedUserID != null
        ? event.availability
            .firstWhere((a) => a.user.id == _focusedUserID,
                orElse: () => W2MUserAvailability(
                    user: W2MUserInfo(id: '', name: ''), slots: []))
            .slots
            .toSet()
        : null;

    return Container(
      width: cellWidth,
      decoration: BoxDecoration(
        border: Border(
            left: BorderSide(
                color: Colors.grey.withValues(alpha: 0.3), width: 0.5)),
      ),
      child: Column(
        children: _times.map((time) {
          final slotLabel = '$date $time';
          final count = event.slotCount(slotLabel);
          final ratio = count / event.maxCount;
          final isSelected = _selectedSlot == slotLabel;
          final isFocused = focusedSlots?.contains(slotLabel) ?? false;
          final isHour = time.endsWith(':00');

          final bgColor = _cellColor(
            ratio: ratio,
            count: count,
            isSelected: isSelected,
            isFocused: isFocused,
            hasFocusedUser: focusedSlots != null,
          );

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSlot = (_selectedSlot == slotLabel) ? null : slotLabel;
              });
            },
            child: Container(
              width: cellWidth,
              height: _cellHeight,
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  top: isHour
                      ? BorderSide(
                          color: Colors.grey.withValues(alpha: 0.3),
                          width: 0.5)
                      : BorderSide.none,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isSelected)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  if (!isSelected && focusedSlots != null && isFocused)
                    const Icon(Icons.check, size: 9, color: Colors.white),
                  if (!isSelected && focusedSlots == null && count > 0)
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: ratio > 0.45 ? Colors.white : Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _cellColor({
    required double ratio,
    required int count,
    required bool isSelected,
    required bool isFocused,
    required bool hasFocusedUser,
  }) {
    if (isSelected) return Colors.blue.withValues(alpha: 0.15);
    if (hasFocusedUser) {
      return isFocused
          ? HSVColor.fromAHSV(1.0, 216, 0.7, 0.9).toColor()
          : Theme.of(context).colorScheme.surface;
    }
    if (count == 0) return Theme.of(context).colorScheme.surface;
    final saturation = 0.30 + ratio * 0.70;
    final brightness = 1.0 - ratio * 0.35;
    return HSVColor.fromAHSV(1.0, 142, saturation, brightness).toColor();
  }

  // ──────────────────────────────────────────────────────
  // SLOT DETAIL BAR
  // ──────────────────────────────────────────────────────

  Widget _buildSlotDetailBar(W2MEvent event, String slotLabel) {
    final entries = event.usersAvailable(slotLabel);
    final parts = slotLabel.split(' ');
    final dateStr = parts.isNotEmpty ? parts[0] : '';
    final timeStr = parts.length > 1 ? parts[1] : '';

    return Container(
      key: const ValueKey('slot'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('$dateStr $timeStr',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${entries.length} 人有空',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: entries.isEmpty ? Colors.grey : Colors.green)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedSlot = null;
                  _focusedUserID = null;
                }),
                child: const Icon(Icons.cancel, size: 18, color: Colors.grey),
              ),
            ],
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('沒有人有空',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: entries.map((entry) {
                  final isFocused = _focusedUserID == entry.user.id;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _focusedUserID =
                          isFocused ? null : entry.user.id;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(top: 6, right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? Colors.blue
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _avatarCircle(entry.user.avatarURL, 14),
                          const SizedBox(width: 4),
                          Text(
                            entry.user.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isFocused ? Colors.white : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  // FOCUSED USER BAR
  // ──────────────────────────────────────────────────────

  Widget _buildFocusedUserBar(W2MEvent event, String userID) {
    final entry = event.availability.firstWhere((a) => a.user.id == userID,
        orElse: () =>
            W2MUserAvailability(user: W2MUserInfo(id: '', name: ''), slots: []));

    return Container(
      key: const ValueKey('focused'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('正在查看：${entry.user.displayName}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${entry.slots.length} 個時段有空',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showUserDetail(event, entry),
            child: const Text('詳細', style: TextStyle(fontSize: 12)),
          ),
          GestureDetector(
            onTap: () => setState(() => _focusedUserID = null),
            child: const Icon(Icons.cancel, size: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  // BOTTOM ACTION BAR
  // ──────────────────────────────────────────────────────

  Widget _buildBottomBar(W2MEvent event, VocPassAuthService auth) {
    final mySlots = _currentUserSlots();
    final names = event.availability
        .map((a) => a.user.displayName)
        .toList()
      ..sort();

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showParticipants(event),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${event.availability.length} 人已填寫',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                if (event.availability.isNotEmpty)
                  Text(
                    names.take(3).join('、') +
                        (event.availability.length > 3 ? '…' : ''),
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const Spacer(),
          if (auth.isLoggedIn)
            FilledButton(
              onPressed: () => _showAvailability(event, mySlots),
              child: Text(
                mySlots.isEmpty ? '填寫我的時段' : '編輯我的時段',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else
            const Text('登入後可填寫',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  // SHEETS
  // ──────────────────────────────────────────────────────

  void _showAvailability(W2MEvent event, List<String> mySlots) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => W2MAvailabilityScreen(
          eventID: widget.eventID,
          dates: event.dates,
          initialSlots: mySlots,
        ),
      ),
    );
    _loadEvent();
  }

  void _showEditSheet(W2MEvent event) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _W2MEditSheet(event: event),
    );
    _loadEvent();
  }

  void _showParticipants(W2MEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _W2MParticipantsSheet(
        event: event,
        onSelectUser: (entry) {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() => _focusedUserID = entry.user.id);
            }
          });
        },
      ),
    );
  }

  void _showUserDetail(W2MEvent event, W2MUserAvailability entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _W2MUserDetailSheet(entry: entry, event: event),
    );
  }

  void _shareEvent() {
    final url = W2MService.instance.shareURL(widget.eventID);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('分享連結',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(url, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('複製連結'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已複製連結')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────

  Widget _avatarCircle(String? url, double size) {
    if (url != null) {
      return ClipOval(
        child: Image.network(url,
            width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultAvatar(size)),
      );
    }
    return _defaultAvatar(size);
  }

  Widget _defaultAvatar(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person,
            size: size * 0.6, color: Colors.grey.shade600),
      );
}

// ──────────────────────────────────────────────────────
// EDIT EVENT SHEET
// ──────────────────────────────────────────────────────

class _W2MEditSheet extends StatefulWidget {
  final W2MEvent event;
  const _W2MEditSheet({required this.event});

  @override
  State<_W2MEditSheet> createState() => _W2MEditSheetState();
}

class _W2MEditSheetState extends State<_W2MEditSheet> {
  late TextEditingController _titleController;
  late Set<DateTime> _selectedDates;
  bool _isSaving = false;
  String? _errorMessage;
  DateTime _displayMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.event.title);
    _selectedDates = widget.event.dates.map((s) {
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.now();
      }
    }).toSet();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  List<String> get _sortedDateStrings {
    final sorted = _selectedDates.toList()..sort();
    return sorted
        .map((d) =>
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}')
        .toList();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await W2MService.instance.updateEvent(
        id: widget.event.id,
        title: _titleController.text.trim(),
        dates: _sortedDateStrings,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _titleController.text.trim().isNotEmpty &&
        _selectedDates.isNotEmpty &&
        !_isSaving;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (ctx, scrollController) => Scaffold(
        appBar: AppBar(
          title: const Text('編輯活動'),
          leading: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          actions: [
            TextButton(
              onPressed: canSave ? _save : null,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('儲存',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        body: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '活動名稱',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('日期（可多選）',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            )),
                        if (_selectedDates.isNotEmpty)
                          Text('已選 ${_selectedDates.length} 天',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCalendar(),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final year = _displayMonth.year;
    final month = _displayMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    const weekdayLabels = ['日', '一', '二', '三', '四', '五', '六'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _displayMonth =
                  DateTime(_displayMonth.year, _displayMonth.month - 1)),
            ),
            Text('$year 年 $month 月',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _displayMonth =
                  DateTime(_displayMonth.year, _displayMonth.month + 1)),
            ),
          ],
        ),
        Row(
          children: weekdayLabels
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < startWeekday) return const SizedBox();
            final day = index - startWeekday + 1;
            final date = DateTime(year, month, day);
            final isSelected = _selectedDates.any((d) =>
                d.year == date.year &&
                d.month == date.month &&
                d.day == date.day);
            return GestureDetector(
              onTap: () {
                setState(() {
                  final existing = _selectedDates.firstWhere(
                    (d) =>
                        d.year == date.year &&
                        d.month == date.month &&
                        d.day == date.day,
                    orElse: () => DateTime(0),
                  );
                  if (existing.year == 0) {
                    _selectedDates.add(date);
                  } else {
                    _selectedDates.remove(existing);
                  }
                });
              },
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────
// PARTICIPANTS SHEET
// ──────────────────────────────────────────────────────

class _W2MParticipantsSheet extends StatelessWidget {
  final W2MEvent event;
  final void Function(W2MUserAvailability) onSelectUser;

  const _W2MParticipantsSheet(
      {required this.event, required this.onSelectUser});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (ctx, scrollController) => Scaffold(
        appBar: AppBar(
          title: Text('已填寫（${event.availability.length} 人）'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
        body: event.availability.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('還沒有人填寫',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : ListView.builder(
                controller: scrollController,
                itemCount: event.availability.length,
                itemBuilder: (ctx, i) {
                  final entry = event.availability[i];
                  return ListTile(
                    leading: _avatarCircle(entry.user.avatarURL, 36),
                    title: Text(entry.user.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500)),
                    subtitle: Text('${entry.slots.length} 個時段有空',
                        style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.grey),
                    onTap: () => onSelectUser(entry),
                  );
                },
              ),
      ),
    );
  }

  Widget _avatarCircle(String? url, double size) {
    if (url != null) {
      return ClipOval(
        child: Image.network(url,
            width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultAvatar(size)),
      );
    }
    return _defaultAvatar(size);
  }

  Widget _defaultAvatar(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: Colors.grey.shade300, shape: BoxShape.circle),
        child: Icon(Icons.person,
            size: size * 0.6, color: Colors.grey.shade600),
      );
}

// ──────────────────────────────────────────────────────
// USER DETAIL SHEET
// ──────────────────────────────────────────────────────

class _W2MUserDetailSheet extends StatelessWidget {
  final W2MUserAvailability entry;
  final W2MEvent event;

  const _W2MUserDetailSheet({required this.entry, required this.event});

  static const double _cellHeight = 22;
  static const double _timeColWidth = 44;
  static const double _dateColWidth = 56;

  final _times = const [];

  List<String> get _displayTimes => w2mDisplayTimes();

  @override
  Widget build(BuildContext context) {
    final slotSet = entry.slots.toSet();
    final displayTimes = _displayTimes;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (ctx, scrollController) => Scaffold(
        appBar: AppBar(
          title: Text(entry.user.displayName),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
        body: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // User info
            Row(
              children: [
                _avatarCircle(entry.user.avatarURL, 48),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.user.displayName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    Text('${entry.slots.length} 個時段有空',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Time table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.3)),
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: [
                    // Header
                    Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Row(
                        children: [
                          SizedBox(
                              width: _timeColWidth, height: 32),
                          ...event.dates.map((date) => SizedBox(
                                width: _dateColWidth,
                                height: 32,
                                child: Center(
                                  child: Text(
                                    w2mShortDate(date),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Rows
                    ...displayTimes.map((time) {
                      final isHour = time.endsWith(':00');
                      return Container(
                        decoration: isHour
                            ? BoxDecoration(
                                border: Border(
                                    top: BorderSide(
                                        color: Colors.grey
                                            .withValues(alpha: 0.3),
                                        width: 0.5)))
                            : null,
                        child: Row(
                          children: [
                            // Time label
                            SizedBox(
                              width: _timeColWidth,
                              height: _cellHeight,
                              child: isHour
                                  ? Center(
                                      child: Text(time,
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey)),
                                    )
                                  : null,
                            ),
                            // Date cells
                            ...event.dates.map((date) {
                              final label = '$date $time';
                              final available = slotSet.contains(label);
                              return Container(
                                width: _dateColWidth,
                                height: _cellHeight,
                                decoration: BoxDecoration(
                                  color: available
                                      ? HSVColor.fromAHSV(
                                              1.0, 216, 0.7, 0.9)
                                          .toColor()
                                      : null,
                                  border: Border(
                                      left: BorderSide(
                                          color: Colors.grey
                                              .withValues(alpha: 0.3),
                                          width: 0.5)),
                                ),
                                child: available
                                    ? const Icon(Icons.check,
                                        size: 9, color: Colors.white)
                                    : null,
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarCircle(String? url, double size) {
    if (url != null) {
      return ClipOval(
        child: Image.network(url,
            width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultAvatar(size)),
      );
    }
    return _defaultAvatar(size);
  }

  Widget _defaultAvatar(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: Colors.grey.shade300, shape: BoxShape.circle),
        child: Icon(Icons.person,
            size: size * 0.6, color: Colors.grey.shade600),
      );
}

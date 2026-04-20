import 'package:flutter/material.dart';

import '../../services/w2m_service.dart';
import 'w2m_result_screen.dart';

class W2MCreateEventScreen extends StatefulWidget {
  const W2MCreateEventScreen({super.key});

  @override
  State<W2MCreateEventScreen> createState() => _W2MCreateEventScreenState();
}

class _W2MCreateEventScreenState extends State<W2MCreateEventScreen> {
  final _titleController = TextEditingController();
  final Set<DateTime> _selectedDates = {};
  bool _isCreating = false;
  String? _errorMessage;

  // Month displayed in the calendar picker
  DateTime _displayMonth = DateTime(DateTime.now().year, DateTime.now().month);

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

  bool get _canCreate =>
      _titleController.text.trim().isNotEmpty &&
      _selectedDates.isNotEmpty &&
      !_isCreating;

  Future<void> _createEvent() async {
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });
    try {
      final id = await W2MService.instance.createEvent(
        title: _titleController.text.trim(),
        dates: _sortedDateStrings,
      );
      if (!mounted) return;
      // Replace current screen with result screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => W2MResultScreen(eventID: id)),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('建立活動'),
        actions: [
          TextButton(
            onPressed: _canCreate ? _createEvent : null,
            child: _isCreating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('建立',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title input
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '活動名稱',
                  hintText: '例：吃飯約、畢業旅行',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Date picker
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '選擇日期（可多選）',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      if (_selectedDates.isNotEmpty)
                        Text(
                          '已選 ${_selectedDates.length} 天',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),

                  if (_selectedDates.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _sortedDateStrings.take(3).join('、') +
                          (_selectedDates.length > 3 ? '…' : ''),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],

                  const SizedBox(height: 12),
                  _buildCalendar(),
                ],
              ),
            ),
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final year = _displayMonth.year;
    final month = _displayMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // weekday: 1=Mon, 7=Sun; we want Sun=0
    final startWeekday = firstDay.weekday % 7;

    const weekdayLabels = ['日', '一', '二', '三', '四', '五', '六'];

    return Column(
      children: [
        // Month navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                _displayMonth =
                    DateTime(_displayMonth.year, _displayMonth.month - 1);
              }),
            ),
            Text(
              '$year 年 $month 月',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                _displayMonth =
                    DateTime(_displayMonth.year, _displayMonth.month + 1);
              }),
            ),
          ],
        ),

        // Weekday headers
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

        // Day grid
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
            final isSelected = _selectedDates
                .any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
            final isPast = date.isBefore(
                DateTime.now().subtract(const Duration(days: 1)));

            return GestureDetector(
              onTap: isPast
                  ? null
                  : () {
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
                      color: isSelected
                          ? Colors.white
                          : isPast
                              ? Colors.grey.shade400
                              : null,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
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

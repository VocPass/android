import 'package:flutter/material.dart';

import '../../models/w2m_models.dart';
import '../../services/w2m_service.dart';

class W2MAvailabilityScreen extends StatefulWidget {
  final String eventID;
  final List<String> dates;
  final List<String> initialSlots;

  const W2MAvailabilityScreen({
    super.key,
    required this.eventID,
    required this.dates,
    this.initialSlots = const [],
  });

  @override
  State<W2MAvailabilityScreen> createState() => _W2MAvailabilityScreenState();
}

class _W2MAvailabilityScreenState extends State<W2MAvailabilityScreen> {
  late Set<String> _selectedSlots;
  bool _isSaving = false;
  String? _errorMessage;

  static const double _cellHeight = 28;
  static const double _timeColWidth = 44;
  static const double _minCellWidth = 56;

  final _times = w2mDisplayTimes();

  @override
  void initState() {
    super.initState();
    _selectedSlots = Set.from(widget.initialSlots);
  }

  double _cellWidth(double totalWidth) {
    final natural =
        (totalWidth - _timeColWidth) / widget.dates.length.clamp(1, 999);
    return natural < _minCellWidth ? _minCellWidth : natural;
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final sorted = _selectedSlots.toList()..sort();
      await W2MService.instance.submitAvailability(
        eventID: widget.eventID,
        slots: sorted,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇有空時段'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cw = _cellWidth(constraints.maxWidth);
          return Column(
            children: [
              Expanded(child: _buildGrid(cw)),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              _buildBottomBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGrid(double cellWidth) {
    final headerHeight = 36.0;

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed time column
          SizedBox(
            width: _timeColWidth,
            child: Column(
              children: [
                SizedBox(height: headerHeight),
                ..._times.map((time) => SizedBox(
                      width: _timeColWidth,
                      height: _cellHeight,
                      child: time.endsWith(':00')
                          ? Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4, top: 1),
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
          // Horizontally scrollable date columns
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: cellWidth * widget.dates.length,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header row
                    SizedBox(
                      height: headerHeight,
                      child: Row(
                        children: widget.dates
                            .map((date) => Container(
                                  width: cellWidth,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  alignment: Alignment.center,
                                  child: Text(
                                    w2mShortDate(date),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    // Grid rows
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.dates
                          .map((date) =>
                              _buildDateColumn(date, cellWidth))
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

  Widget _buildDateColumn(String date, double cellWidth) {
    return SizedBox(
      width: cellWidth,
      child: Column(
        children: _times.map((time) {
          final label = '$date $time';
          final selected = _selectedSlots.contains(label);
          final isHour = time.endsWith(':00');
          return GestureDetector(
            onTap: () {
              setState(() {
                if (selected) {
                  _selectedSlots.remove(label);
                } else {
                  _selectedSlots.add(label);
                }
              });
            },
            child: Container(
              width: cellWidth,
              height: _cellHeight,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.green.withValues(alpha: 0.7)
                    : Theme.of(context).colorScheme.surface,
                border: Border(
                  left: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                  top: isHour
                      ? BorderSide(
                          color: Colors.grey.withValues(alpha: 0.3),
                          width: 0.5)
                      : BorderSide.none,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
            top: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            '${_selectedSlots.length} 個時段',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('儲存',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

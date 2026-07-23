import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

abstract interface class CalendarEvent {
  String get id;
  DateTimeRange get dates;
  String get title;
  String get description;
}

class Calendar<T extends CalendarEvent> extends StatefulWidget {
  final List<CalendarEvent> events;
  final DateTime? startDate;
  final ValueChanged<DateTimeRange>? onChanged;
  final ValueChanged<CalendarEvent>? onEventSelected;

  const Calendar({
    super.key,
    this.events = const [],
    this.startDate,
    this.onChanged,
    this.onEventSelected,
  });

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState<T extends CalendarEvent> extends State<Calendar<T>> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.startDate ?? DateTime.now();
    // Schedule callback after the first frame to avoid building during layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyDatesChanged());
  }

  void _notifyDatesChanged() {
    final range = DateTimeRange(
      start: DateTime(_currentDate.year, _currentDate.month, 1),
      end: DateTime(_currentDate.year, _currentDate.month + 1, 0, 23, 59, 59),
    );
    widget.onChanged?.call(range);
  }

  // Pre-groups events by date string for O(1) lookup in the grid
  Map<DateTime, List<CalendarEvent>> _getEventMap() {
    final map = <DateTime, List<CalendarEvent>>{};
    for (var event in widget.events) {
      final start = DateTime(
        event.dates.start.year,
        event.dates.start.month,
        event.dates.start.day,
      );
      final end = DateTime(
        event.dates.end.year,
        event.dates.end.month,
        event.dates.end.day,
      );
      for (
        DateTime day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))
      ) {
        final key = DateTime(day.year, day.month, day.day);
        map.putIfAbsent(key, () => []).add(event);
      }
      // Sort events for each day by start time
      for (var day in map.keys) {
        map[day]!.sort((a, b) => a.dates.start.compareTo(b.dates.start));
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(_currentDate.year, _currentDate.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(
      _currentDate.year,
      _currentDate.month,
    );

    // Calendar Generation Logic
    final days = <DateTime>[];
    final firstWeekday = firstDayOfMonth.weekday; // Monday = 1, Sunday = 7

    // Fill previous month's trailing days
    for (int i = 1; i < firstWeekday; i++) {
      days.add(firstDayOfMonth.subtract(Duration(days: firstWeekday - i)));
    }

    // Current month days
    for (int i = 0; i < daysInMonth; i++) {
      days.add(DateTime(_currentDate.year, _currentDate.month, i + 1));
    }

    // Fill next month's leading days to complete the 7-column grid
    while (days.length % 7 != 0) {
      days.add(days.last.add(const Duration(days: 1)));
    }

    final eventMap = _getEventMap();

    return Column(
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        _buildWeekdayLabels(context),
        const SizedBox(height: 8),
        _buildCalendarGrid(context, days, eventMap),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(
              () => _currentDate = DateTime(
                _currentDate.year,
                _currentDate.month - 1,
                1,
              ),
            );
            _notifyDatesChanged();
          },
        ),
        Text(
          DateFormat.yMMMM(locale).format(_currentDate),
          style: theme.textTheme.titleLarge,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(
              () => _currentDate = DateTime(
                _currentDate.year,
                _currentDate.month + 1,
                1,
              ),
            );
            _notifyDatesChanged();
          },
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final weekdayFormat = DateFormat.E(locale);
    return Row(
      children: List.generate(7, (index) {
        // Jan 6 2020 was a Monday
        final weekday = weekdayFormat.format(DateTime(2020, 1, 6 + index));
        return Expanded(
          child: Center(
            child: Text(weekday, style: theme.textTheme.labelLarge),
          ),
        );
      }),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    List<DateTime> days,
    Map<DateTime, List<CalendarEvent>> eventMap,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final isToday = DateUtils.isSameDay(day, DateTime.now());
        final isCurrentMonth = day.month == _currentDate.month;
        final List<CalendarEvent> dayEvents = [
          ...(eventMap[DateTime(day.year, day.month, day.day)] ??
              const <CalendarEvent>[]),
        ];
        final theme = Theme.of(context);
        final dateColor = isCurrentMonth
            ? (isToday
                ? theme.colorScheme.onPrimaryContainer
                : theme.textTheme.bodyLarge?.color)
            : theme.disabledColor;

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CalendarDay(
                  date: day,
                  events: dayEvents,
                  onEventSelected: widget.onEventSelected,
                ),
              ),
            );
          },
          child: Column(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Text(
                  '${day.day}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: dateColor,
                    fontWeight: isToday ? FontWeight.bold : null,
                  ),
                ),
              ),
              if (dayEvents.isNotEmpty)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cellWidth = constraints.maxWidth;

                      final overlappingEvents = <CalendarEvent>[];

                      for (var event in dayEvents) {
                        if (event.dates.start.isBefore(day.add(const Duration(days: 1))) &&
                            event.dates.end.isAfter(day)) {
                          overlappingEvents.add(event);
                        }
                      }

                      return Column(
                        spacing: 2,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var event in dayEvents) 
                            _buildEventTile(
                              context: context,
                              day: day,
                              event: event,
                              cellWidth: cellWidth,
                            ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventTile({
    required BuildContext context,
    required DateTime day,
    required CalendarEvent event,
    required double cellWidth,
  }) {
    final theme = Theme.of(context);
    final dayIndex =
        DateTime(day.year, day.month, day.day)
            .difference(
              DateTime(
                event.dates.start.year,
                event.dates.start.month,
                event.dates.start.day,
              ),
            )
            .inDays;
    final shift = dayIndex * cellWidth;
    final isFirstDay = DateUtils.isSameDay(event.dates.start, day);
    final isLastDay = DateUtils.isSameDay(event.dates.end, day);
    final isSingleDay = isFirstDay && isLastDay;

    return Tooltip(
      message: '${event.title}\n${event.description}',
      preferBelow: false,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: isSingleDay
              ? BorderRadius.circular(8)
              : isFirstDay
                  ? const BorderRadius.horizontal(left: Radius.circular(8))
                  : isLastDay
                      ? const BorderRadius.horizontal(right: Radius.circular(8))
                      : null,
        ),
        child: Transform.translate(
          offset: Offset(-shift, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              event.title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                height: 1,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarDay extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent>? onEventSelected;

  const CalendarDay({
    super.key,
    required this.date,
    required this.events,
    this.onEventSelected,
  });

  static const double hourHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final sortedEvents = List.of(events)
      ..sort((a, b) => a.dates.start.compareTo(b.dates.start));

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat.yMMMMd(locale).format(date))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHourGrid(context),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildEventGrid(context),
                        for (var event in sortedEvents)
                          _buildEventTile(context, event),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHourGrid(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: List.generate(24, (hour) {
        return SizedBox(
          height: hourHeight,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                TimeOfDay(hour: hour, minute: 0).format(context),
                textAlign: TextAlign.right,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.hintColor,
                  height: 1, 
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEventGrid(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: List.generate(24, (hour) {
        return SizedBox(
          height: hourHeight,
          child: Align(
            alignment: Alignment.topLeft,
            child: Divider(height: 1, color: theme.dividerColor),
          ),
        );
      }),
    );
  }

  Widget _buildEventTile(BuildContext context, CalendarEvent event) {
    final theme = Theme.of(context);
    // If the event starts before the current date, it spans from midnight
    final isStartDay = DateUtils.isSameDay(event.dates.start, date);
    final startHourDecimal = isStartDay
        ? event.dates.start.hour + (event.dates.start.minute / 60.0)
        : 0.0;

    // If the event ends after the current date, it spans until midnight
    final isEndDay = DateUtils.isSameDay(event.dates.end, date);
    final endHourDecimal = isEndDay
        ? event.dates.end.hour + (event.dates.end.minute / 60.0)
        : 24.0;

    final top = startHourDecimal * hourHeight;

    final height =
        ((endHourDecimal - startHourDecimal).clamp(0.5, 24.0)) * hourHeight;

    return Positioned(
      top: top,
      child: InkWell(
        onTap: () {
          onEventSelected?.call(event);
        },
        child: Container(
          height: height,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: isStartDay
                ? BorderRadius.vertical(top: Radius.circular(8))
                : isEndDay
                    ? BorderRadius.vertical(bottom: Radius.circular(8))
                    : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                event.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

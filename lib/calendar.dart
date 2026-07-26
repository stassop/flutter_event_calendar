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
  final DateTime startDate;
  final int startYear;
  final int endYear;
  final ValueChanged<DateTimeRange>? onChanged;
  final ValueChanged<CalendarEvent>? onTapEvent;

  Calendar({
    super.key,
    this.events = const [],
    this.startYear = 1900,
    this.endYear = 2100,
    DateTime? startDate,
    this.onChanged,
    this.onTapEvent,
  }) : assert(startYear <= endYear, 'startYear must be less than or equal to endYear'),
        startDate = startDate ?? DateTime.now();

  List<int> get years => List.generate(
        endYear - startYear + 1,
        (index) => startYear + index,
      );

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState<T extends CalendarEvent> extends State<Calendar<T>> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.startDate;
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
  Map<DateTime, List<CalendarEvent?>> _getEventLaneMap() {
    // Sort events chronologically by start date
    final sortedEvents = List<CalendarEvent>.from(widget.events)
      ..sort((a, b) => a.dates.start.compareTo(b.dates.start));

    final map = <DateTime, List<CalendarEvent?>>{};
    if (sortedEvents.isEmpty) return map;

    // Trackers for the current overlapping group (cluster) of events
    DateTime? clusterEndDay;
    final clusterDays = <DateTime>{};
    int maxLaneInCluster = 0;
    final laneEnds = <DateTime>[]; // Tracks when each lane becomes free

    // Helper to pad all days in the current cluster to have the same number of lanes
    void padCluster() {
      for (final day in clusterDays) {
        final dayLanes = map[day]!;
        // Fill missing lanes at the end with nulls
        while (dayLanes.length <= maxLaneInCluster) {
          dayLanes.add(null);
        }
      }
    }

    for (final event in sortedEvents) {
      // Strip out the time to compare just the dates
      final startDay = DateTime(
        event.dates.start.year,
        event.dates.start.month,
        event.dates.start.day,
      );
      final endDay = DateTime(
        event.dates.end.year,
        event.dates.end.month,
        event.dates.end.day,
      );

      // If this event starts after the current cluster ends, finalize the old cluster
      if (clusterEndDay != null && startDay.isAfter(clusterEndDay)) {
        padCluster();
        clusterDays.clear();
        laneEnds.clear(); // Reset lanes for the new, disconnected cluster
        maxLaneInCluster = 0;
      }

      // Extend the cluster's max end date if this event reaches further
      if (clusterEndDay == null || endDay.isAfter(clusterEndDay)) {
        clusterEndDay = endDay;
      }

      // Find the first available lane (where the event starts after the lane is free)
      int laneIndex = laneEnds.indexWhere(
        (endTime) => !event.dates.start.isBefore(endTime),
      );

      if (laneIndex == -1) {
        // No free lanes found, open a new one
        laneEnds.add(event.dates.end);
        laneIndex = laneEnds.length - 1;
      } else {
        // Re-use the existing lane and update its new end time
        laneEnds[laneIndex] = event.dates.end;
      }

      // Track the maximum lane used in this cluster
      if (laneIndex > maxLaneInCluster) {
        maxLaneInCluster = laneIndex;
      }

      // Add the event to the map for every day it spans
      for (
        DateTime day = startDay;
        !day.isAfter(endDay);
        day = day.add(const Duration(days: 1))
      ) {
        clusterDays.add(day); // Track the day so we can pad it later
        
        final dayLanes = map.putIfAbsent(day, () => <CalendarEvent?>[]);

        // Ensure the list is long enough to place the event in its lane
        while (dayLanes.length <= laneIndex) {
          dayLanes.add(null);
        }

        dayLanes[laneIndex] = event;
      }
    }

    // Pad the final cluster after the loop finishes
    padCluster();

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

    final eventLaneMap = _getEventLaneMap();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildWeekdayLabels(context),
          const SizedBox(height: 8),
          _buildCalendarGrid(context, days, eventLaneMap),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    final headerTextStyle = theme.textTheme.titleLarge;
    final compactDropdownDecoration = const InputDecorationTheme(
      isDense: true,
      contentPadding: EdgeInsets.zero,
      border: InputBorder.none,
    );

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
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: DropdownMenu<int>(
                  // Omitted expandedInsets to let width fit content automatically
                  textStyle: headerTextStyle,
                  inputDecorationTheme: compactDropdownDecoration,
                  initialSelection: _currentDate.month,
                  onSelected: (month) {
                    if (month != null) {
                      setState(
                        () => _currentDate = DateTime(_currentDate.year, month, 1),
                      );
                      _notifyDatesChanged();
                    }
                  },
                  dropdownMenuEntries: List.generate(
                    12,
                    (index) => DropdownMenuEntry(
                      value: index + 1,
                      label: DateFormat.MMM(
                        locale,
                      ).format(DateTime(_currentDate.year, index + 1)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: DropdownMenu<int>(
                  // Omitted expandedInsets to let width fit content automatically
                  textStyle: headerTextStyle,
                  inputDecorationTheme: compactDropdownDecoration,
                  initialSelection: _currentDate.year,
                  onSelected: (year) {
                    if (year != null) {
                      setState(
                        () => _currentDate = DateTime(year, _currentDate.month, 1),
                      );
                      _notifyDatesChanged();
                    }
                  },
                  dropdownMenuEntries: widget.years.map((year) {
                    return DropdownMenuEntry<int>(
                      value: year,
                      label: year.toString(),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
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
    Map<DateTime, List<CalendarEvent?>> eventMap,
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
        final dayEvents = [
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
                builder: (_) { 
                  final events = dayEvents.whereType<CalendarEvent>().toList();
                  return CalendarDay(
                    date: day,
                    events: events,
                    onTapEvent: widget.onTapEvent,
                  ); 
                },
              ),
            );
          },
          child: Column(
            children: [
              Center(
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
                      final dayHeight = constraints.maxHeight;
                      final eventWidth = constraints.maxWidth;
                      // Event height is determined by the number of lanes, plus spacing
                      final eventHeight = (dayHeight - (dayEvents.length - 1) * 2) / dayEvents.length;

                      return Column(
                        spacing: 2,
                        children: [
                          for (var event in dayEvents)
                            if (event != null)
                              _buildEventTile(
                                context: context,
                                day: day,
                                event: event,
                                eventWidth: eventWidth,
                                eventHeight: eventHeight,
                              )
                            else
                              SizedBox(height: eventHeight),
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
    required double eventWidth,
    required double eventHeight,
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
    final textOffset = dayIndex * eventWidth;
    final isFirstDay = DateUtils.isSameDay(event.dates.start, day);
    final isLastDay = DateUtils.isSameDay(event.dates.end, day);
    final isSingleDay = isFirstDay && isLastDay;
    // Calculate a font size based on the height. 
    // Example: Takes up 80% of the container's height, clamped between 10 and 16.
    final double dynamicFontSize = (eventHeight * 0.8).clamp(8.0, 16.0);

    return Tooltip(
      decoration: BoxDecoration(
        color: theme.colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: '${event.title}\n',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onInverseSurface,
            ),
          ),
          TextSpan(
            text: '${DateFormat.yMMMd().format(event.dates.start)} - '
              '${DateFormat.yMMMd().format(event.dates.end)}\n',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onInverseSurface,
            ),
          ),
          TextSpan(
            text: event.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onInverseSurface,
            ),
          ),
        ],
      ),
      preferBelow: false,
      child: Container(
        clipBehavior: Clip.hardEdge,
        height: eventHeight,
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
          offset: Offset(-textOffset, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              event.title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontSize: dynamicFontSize,
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
  final ValueChanged<CalendarEvent>? onTapEvent;

  const CalendarDay({
    super.key,
    required this.date,
    required this.events,
    this.onTapEvent,
  });

  static const double hourHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final sortedEvents = List.of(events)
      ..sort((a, b) => a.dates.start.compareTo(b.dates.start));

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat.yMMMd(locale).format(date))),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final dayWidth = constraints.maxWidth;
                        // Event width based on day's events plus spacing
                        final eventWidth = (dayWidth - (events.length - 1) * 2) / events.length;

                        return Stack(
                          children: [
                            _buildEventGrid(context),
                            for (var event in sortedEvents)
                              // Left offset for each event based on its index in the sorted list
                              _buildEventTile(
                                context: context,
                                event: event,
                                eventWidth: eventWidth,
                                index: sortedEvents.indexOf(event),
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
        ),
      ),
    );
  }

  Widget _buildHourGrid(BuildContext context) {
    final theme = Theme.of(context);

    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(date, now);
    // Past day check calculated once for efficiency
    final isPastDay = date.isBefore(DateTime(now.year, now.month, now.day));

    return Column(
      children: List.generate(24, (hour) {
        // Evaluate current and past state for THIS specific hour
        final isCurrentHour = isToday && hour == now.hour;
        final isPastHour = isPastDay || (isToday && hour < now.hour);

        final hourColor = isCurrentHour
            ? theme.colorScheme.onPrimaryContainer
            : isPastHour
                ? theme.disabledColor
                : theme.textTheme.bodyLarge?.color;

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
                  fontWeight: isCurrentHour ? FontWeight.bold : null,
                  color: hourColor,
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

  Widget _buildEventTile({
    required BuildContext context, 
    required CalendarEvent event,
    required double eventWidth,
    required int index,
  }) {
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

    final isSingleDay = isStartDay && isEndDay;

    final top = startHourDecimal * hourHeight;
    final left = index * (eventWidth + 2); // 2 pixels spacing between events

    final height = ((endHourDecimal - startHourDecimal).clamp(0.5, 24.0)) * hourHeight;

    final formattedDateTime = '${DateFormat.MMMd().add_j().format(event.dates.start)} - '
        '${DateFormat.MMMd().add_j().format(event.dates.end)}';

    return Positioned(
      top: top,
      left: left,
      child: InkWell(
        onTap: () {
          onTapEvent?.call(event);
        },
        child: Container(
          height: height,
          width: eventWidth,
          clipBehavior: Clip.hardEdge,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: isSingleDay
                ? BorderRadius.circular(8)
                : isStartDay
                    ? const BorderRadius.vertical(top: Radius.circular(8))
                    : isEndDay
                        ? const BorderRadius.vertical(bottom: Radius.circular(8))
                        : null,
          ),
          child: OverflowBox(
            alignment: Alignment.topLeft, // Fixes top-clipping by anchoring content to the top
            maxHeight: double.infinity,   // Prevents RenderFlex overflow errors on small heights
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formattedDateTime,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
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
      ),
    );
  }
}

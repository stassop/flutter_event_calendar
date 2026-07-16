import 'package:flutter/material.dart'; 
import 'package:flutter_event_calendar/calendar.dart';

class Event implements CalendarEvent, Comparable<Event> {
  @override
  final String id;

  @override
  final DateTimeRange dates;

  @override
  final String title;

  @override
  final String description;

  // Added 'const' here
  const Event({
    required this.id,
    required this.dates,
    required this.title,
    required this.description,
  });

  /// Returns a new immutable Event with the provided field overrides.
  Event copyWith({
    String? id,
    DateTimeRange? dates,
    String? title,
    String? description,
  }) {
    return Event(
      id: id ?? this.id,
      dates: dates ?? this.dates,
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }

  @override
  int compareTo(Event other) {
    final startComparison = dates.start.compareTo(other.dates.start);
    if (startComparison != 0) return startComparison;

    final endComparison = dates.end.compareTo(other.dates.end);
    if (endComparison != 0) return endComparison;

    final titleComparison = title.compareTo(other.title);
    if (titleComparison != 0) return titleComparison;

    return id.compareTo(other.id);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Event &&
            other.id == id &&
            other.title == title &&
            other.description == description &&
            other.dates == dates; // Simplified: relies on DateTimeRange's internal ==
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        dates, // Simplified: relies on DateTimeRange's internal hashCode
      );
}
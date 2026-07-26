import 'package:flutter/material.dart';

import 'package:flutter_event_calendar/calendar.dart';

import 'package:flutter_event_calendar/event.dart';

final now = DateTime.now();
// Strip time to get today's date at 00:00:00 (prevents time drift issues)
final today = DateTime(now.year, now.month, now.day);

final events = [
  // 1. ANCHOR EVENT (Starts Day 0, ends Day 8)
  Event(
    id: 'b8b3f23a-7a57-4f4a-939e-2936791d2146',
    title: 'The Odyssey Project: 8-Day Transatlantic Writers Retreat',
    description: 'An epic eight-day maritime voyage dedicated to advanced world-building workshops '
        'and speculative fiction panels across the Atlantic.',
    dates: DateTimeRange(
      start: DateTime(today.year, today.month, today.day, 10, 0),   // Day 0: 10:00 AM
      end: DateTime(today.year, today.month, today.day + 8, 10, 0),  // Day 8: 10:00 AM
    ),
  ),

  // 2. MID-WEEK CONFERENCE (Starts Day 1, ends Day 4 — overlaps with Event 1)
  Event(
    id: '4c8e76bb-162e-4b68-80e2-632b7bb8a8cf',
    title: 'Global Eco-Tourism & Hospitality Summit',
    description: 'A comprehensive 3-day deep dive into the future of boutique hotels, '
        'zero-waste kitchens, and modern guest psychology.',
    dates: DateTimeRange(
      start: DateTime(today.year, today.month, today.day - 3, 9, 0),  // Day 1: 9:00 AM
      end: DateTime(today.year, today.month, today.day, 23, 0), // Day 4: 11:00 PM
    ),
  ),

  // 3. OVERNIGHT SHOWCASE (Starts Day 2, ends Day 3 — overlaps with Events 1 & 2)
  Event(
    id: '7d35a2ef-9184-4860-bc04-811c750e26d8',
    title: 'Neon Horizon: Ambient Synthwave Midnight Showcase',
    description: 'An underground electronic music event featuring live modular synthesis and '
        'laser mapping, stretching deep into the morning.',
    dates: DateTimeRange(
      start: DateTime(today.year, today.month, today.day + 2, 20, 0), // Day 2: 8:00 PM
      end: DateTime(today.year, today.month, today.day + 3, 2, 0),   // Day 3: 2:00 AM
    ),
  ),
];

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Generate the color scheme first so we can reference it
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
    );

    return MaterialApp(
      title: 'Flutter Event Calendar',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        
        // 2. Globally style all AppBars in your application here
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary, // Auto-styles the title text & icons
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// 3. Move your layout to a separate widget to keep things organized
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Event Calendar'), // Zero inline styles needed!
      ),
      body: SafeArea(
        child: Calendar(
          events: events,
          onChanged: (dateRange) {
            // Handle date range changes here
            print('Selected date range: ${dateRange.start} to ${dateRange.end}');
          },
          onTapEvent: (event) {
            // Handle event selection here
            print('Selected event: ${event.title}');
          },
        ),
      ),
    );
  }
}


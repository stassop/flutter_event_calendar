import 'package:flutter/material.dart';

import 'package:flutter_event_calendar/calendar.dart';

import 'package:flutter_event_calendar/event.dart';

final now = DateTime.now();

final events = [
  // 1. THE SHORT OVERNIGHT MUSIC CONCERT (8 PM to 2 AM next day)
  Event(
    id: '7d35a2ef-9184-4860-bc04-811c750e26d8',
    title: 'Neon Horizon: Ambient Synthwave Midnight Showcase',
    description: 'An underground electronic music event featuring live modular synthesis and '
        'laser mapping, stretching deep into the morning.',
    dates: DateTimeRange(
      start: DateTime(2026, 7, 20, 20, 0), // July 20, 8:00 PM (20:00)
      end: DateTime(2026, 7, 21, 2, 0),   // July 21, 2:00 AM (Next day)
    ),
  ),

  // 2. THE 3-DAY HOSPITALITY CONFERENCE (9 AM first day to 23 PM last day)
  Event(
    id: '4c8e76bb-162e-4b68-80e2-632b7bb8a8cf',
    title: 'Global Eco-Tourism & Hospitality Summit 2026',
    description: 'A comprehensive 3-day deep dive into the future of boutique hotels, '
        'zero-waste kitchens, and modern guest psychology.',
    dates: DateTimeRange(
      start: DateTime(2026, 7, 20, 9, 0),  // Day 1: July 20, 9:00 AM
      end: DateTime(2026, 7, 22, 23, 0),  // Day 3: July 22, 11:00 PM (23:00)
    ),
  ),

  // 3. THE 8-DAY ANCHOR EVENT (Figure to last exactly 8 days)
  Event(
    id: 'b8b3f23a-7a57-4f4a-939e-2936791d2146',
    title: 'The Odyssey Project: 8-Day Transatlantic Writers Retreat',
    description: 'An epic eight-day maritime voyage dedicated to advanced world-building workshops '
        'and speculative fiction panels across the Atlantic.',
    dates: DateTimeRange(
      start: DateTime(2026, 7, 20, 10, 0), // Day 1: July 20, 10:00 AM
      end: DateTime(2026, 7, 28, 10, 0),  // Day 9: July 28, 10:00 AM (Exactly 8 days)
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
          onEventSelected: (event) {
            // Handle event selection here
            print('Selected event: ${event.title}');
          },
        ),
      ),
    );
  }
}


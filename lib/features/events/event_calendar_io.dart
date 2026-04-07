import 'package:add_2_calendar/add_2_calendar.dart';

import 'event_calendar_common.dart';

/// Android / iOS / desktop: native calendar sheet when available, else Google.
Future<bool> addEventToDeviceOrGoogleCalendar({
  required String title,
  required String description,
  required String location,
  required DateTime start,
  DateTime? end,
}) async {
  final endAt = end != null && end.isAfter(start)
      ? end
      : start.add(const Duration(hours: 2));

  try {
    final ok = await Add2Calendar.addEvent2Cal(
      Event(
        title: title,
        description: description,
        location: location,
        startDate: start,
        endDate: endAt,
      ),
    );
    if (ok) return true;
  } catch (_) {
    // Plugin missing (e.g. desktop) or user cancelled
  }

  return launchGoogleCalendarTemplate(
    title: title,
    description: description,
    location: location,
    start: start,
    end: endAt,
  );
}

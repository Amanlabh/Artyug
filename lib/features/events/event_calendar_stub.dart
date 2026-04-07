import 'event_calendar_common.dart';

/// Web / wasm: Google Calendar only (add_2_calendar uses dart:io).
Future<bool> addEventToDeviceOrGoogleCalendar({
  required String title,
  required String description,
  required String location,
  required DateTime start,
  DateTime? end,
}) {
  final endAt = end != null && end.isAfter(start)
      ? end
      : start.add(const Duration(hours: 2));
  return launchGoogleCalendarTemplate(
    title: title,
    description: description,
    location: location,
    start: start,
    end: endAt,
  );
}

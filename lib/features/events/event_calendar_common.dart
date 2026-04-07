import 'package:url_launcher/url_launcher.dart';

String googleCalUtc(DateTime dt) {
  final u = dt.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

Future<bool> launchGoogleCalendarTemplate({
  required String title,
  required String description,
  required String location,
  required DateTime start,
  required DateTime end,
}) async {
  final dates = '${googleCalUtc(start)}/${googleCalUtc(end)}';
  final uri = Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'details': description,
    'location': location,
    'dates': dates,
  });
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

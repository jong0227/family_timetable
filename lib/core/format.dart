import '../domain/models.dart';

/// 화면에 보이는 날짜·시각 글자. 같은 시각을 화면마다 다르게 쓰지 않도록 여기 모은다.

/// "10월 23일 (금) 14:05"
String formatDateTime(DateTime t) =>
    '${t.month}월 ${t.day}일 (${weekdayLabel(t.weekday)}) ${t.hour}:${t.minute.toString().padLeft(2, '0')}';

/// 오늘이면 "오늘 14:05", 어제면 "어제 14:05", 아니면 [formatDateTime].
String formatRelative(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final hm = '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  if (day == today) return '오늘 $hm';
  if (day == today.subtract(const Duration(days: 1))) return '어제 $hm';
  return formatDateTime(t);
}

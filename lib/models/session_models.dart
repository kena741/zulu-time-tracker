/// One row from `public.sessions`.
class CloudSessionRow {
  CloudSessionRow({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.isActive,
  });

  /// Session UUID (matches `sessions.id` and `session_slots_10m.session_id`).
  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool isActive;
}

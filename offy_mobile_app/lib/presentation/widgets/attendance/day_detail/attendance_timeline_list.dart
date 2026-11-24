import 'package:flutter/material.dart';
import '../../../../data/models/attendance_log_response_model.dart';
import 'attendance_timeline_item.dart';

class AttendanceTimelineList extends StatelessWidget {
  final List<AttendanceTimelineSessionModel> sessions;

  const AttendanceTimelineList({
    super.key,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(sessions.length, (index) {
        final session = sessions[index];
        final isLast = index == sessions.length - 1;

        return AttendanceTimelineItem(
          session: session,
          isLast: isLast,
        );
      }),
    );
  }
}

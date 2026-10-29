class TimeOffLogMessageEntity {
  final String message;
  final String timestamp;
  final bool isOutgoing;
  final String userName;
  final String avatarUrl;

  const TimeOffLogMessageEntity({
    required this.message,
    required this.timestamp,
    required this.isOutgoing,
    this.userName = '',
    this.avatarUrl = '',
  });
}

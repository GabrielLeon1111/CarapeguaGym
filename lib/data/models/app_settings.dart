class AppSettings {
  final int notifyBeforeDueDays;
  final bool notifyOnDueDay;
  final int notifyOverdueDays;
  final bool notifyDailySummary;
  final bool notifyWeeklySummary;

  AppSettings({required this.notifyBeforeDueDays, required this.notifyOnDueDay, required this.notifyOverdueDays, required this.notifyDailySummary, required this.notifyWeeklySummary});

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    notifyBeforeDueDays: json['notify_before_due_days'] as int,
    notifyOnDueDay: json['notify_on_due_day'] as bool,
    notifyOverdueDays: json['notify_overdue_days'] as int,
    notifyDailySummary: json['notify_daily_summary'] as bool,
    notifyWeeklySummary: json['notify_weekly_summary'] as bool,
  );

  Map<String, dynamic> toUpdateJson() => {
    'notify_before_due_days': notifyBeforeDueDays,
    'notify_on_due_day': notifyOnDueDay,
    'notify_overdue_days': notifyOverdueDays,
    'notify_daily_summary': notifyDailySummary,
    'notify_weekly_summary': notifyWeeklySummary,
  };

  AppSettings copyWith({int? notifyBeforeDueDays, bool? notifyOnDueDay, int? notifyOverdueDays, bool? notifyDailySummary, bool? notifyWeeklySummary}) => AppSettings(
    notifyBeforeDueDays: notifyBeforeDueDays ?? this.notifyBeforeDueDays,
    notifyOnDueDay: notifyOnDueDay ?? this.notifyOnDueDay,
    notifyOverdueDays: notifyOverdueDays ?? this.notifyOverdueDays,
    notifyDailySummary: notifyDailySummary ?? this.notifyDailySummary,
    notifyWeeklySummary: notifyWeeklySummary ?? this.notifyWeeklySummary,
  );
}

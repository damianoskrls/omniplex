class UserGoal {
  UserGoal({required this.targetSessions, required this.period});

  final int targetSessions;
  final String period;

  factory UserGoal.fromJson(Map<String, dynamic> json) => UserGoal(
        targetSessions: json['target_sessions'] as int? ?? 6,
        period: json['period'] as String? ?? 'monthly',
      );
}

class UserStats {
  UserStats({
    required this.loyaltyPoints,
    required this.sessionsThisMonth,
    required this.goal,
    required this.goalProgressPct,
    required this.goalMet,
  });

  final int loyaltyPoints;
  final int sessionsThisMonth;
  final UserGoal goal;
  final int goalProgressPct;
  final bool goalMet;

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        loyaltyPoints: json['loyalty_points'] as int? ?? 0,
        sessionsThisMonth: json['sessions_this_month'] as int? ?? 0,
        goal: UserGoal.fromJson(json['goal'] as Map<String, dynamic>? ?? {}),
        goalProgressPct: json['goal_progress_pct'] as int? ?? 0,
        goalMet: json['goal_met'] as bool? ?? false,
      );
}

class PaymentRecord {
  PaymentRecord({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.paidAmountCents,
    required this.balanceCents,
    required this.status,
    this.paymentDate,
    this.dueDate,
    this.notes,
    this.method,
  });

  final String id;
  final String? description;
  final int amountCents;
  final int paidAmountCents;
  final int balanceCents;
  final String status;
  final DateTime? paymentDate;
  final DateTime? dueDate;
  final String? notes;
  final String? method;

  String get statusLabel {
    const labels = {
      'paid': 'Πληρωμένο',
      'partial': 'Μερική πληρωμή',
      'pending': 'Εκκρεμές',
      'overdue': 'Ληξιπρόθεσμο',
    };
    return labels[status] ?? status;
  }

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: json['id'] as String,
        description: json['description'] as String?,
        amountCents: json['amount_cents'] as int? ?? 0,
        paidAmountCents: json['paid_amount_cents'] as int? ?? 0,
        balanceCents: json['balance_cents'] as int? ?? 0,
        status: json['status'] as String? ?? 'pending',
        paymentDate: json['payment_date'] != null
            ? DateTime.tryParse(json['payment_date'] as String)
            : null,
        dueDate: json['due_date'] != null
            ? DateTime.tryParse(json['due_date'] as String)
            : null,
        notes: json['notes'] as String?,
        method: json['method'] as String?,
      );
}

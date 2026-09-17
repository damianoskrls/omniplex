class Booking {
  Booking({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.staffName,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.durationMins,
    this.staffId,
    this.locationId,
    this.preparationTips = const [],
    this.postWorkoutTips = const [],
    this.scheduleLabel,
    this.scheduleRoom,
    this.roomId,
    this.roomPhotoUrl,
    this.roomShortInfo,
    this.feedbackRating,
    this.feedbackNote,
    this.attendanceConfirmed = false,
    this.serviceCategory,
  });

  final String id;
  final String serviceId;
  final String serviceName;
  final String staffName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final int? durationMins;
  final String? staffId;
  final String? locationId;
  final List<String> preparationTips;
  final List<String> postWorkoutTips;
  final String? scheduleLabel;
  final String? scheduleRoom;
  final String? roomId;
  final String? roomPhotoUrl;
  final String? roomShortInfo;
  final int? feedbackRating;
  final String? feedbackNote;
  final bool attendanceConfirmed;
  final String? serviceCategory;

  bool get isNutritionConsultation => serviceCategory == 'nutrition_consultation';

  bool get isUpcoming =>
      (status == 'confirmed' || status == 'pending') && startsAt.isAfter(DateTime.now());

  bool get isCompleted => status == 'completed';

  bool get isInProgress =>
      !isNutritionConsultation &&
      !startsAt.isAfter(DateTime.now()) &&
      endsAt.isAfter(DateTime.now()) &&
      status != 'cancelled' &&
      status != 'no_show';

  bool get needsCheckIn =>
      !isNutritionConsultation &&
      endsAt.isBefore(DateTime.now()) &&
      status != 'cancelled' &&
      status != 'no_show' &&
      !attendanceConfirmed;

  bool get isActiveInList {
    if (status == 'cancelled' || status == 'no_show' || isCompleted) return false;
    // pending bookings whose slot has already passed are no longer relevant
    if (status == 'pending' && startsAt.isBefore(DateTime.now())) return false;
    return true;
  }

  static List<String> _tipsFromJson(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).toList();
  }

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        serviceId: json['service_id'] as String,
        serviceName: json['service_name'] as String,
        staffName: json['staff_name'] as String? ?? '',
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
        status: json['status'] as String,
        durationMins: json['duration_mins'] as int?,
        staffId: json['staff_id'] as String?,
        locationId: json['location_id'] as String?,
        preparationTips: _tipsFromJson(json['preparation_tips']),
        postWorkoutTips: _tipsFromJson(json['post_workout_tips']),
        scheduleLabel: json['schedule_label'] as String?,
        scheduleRoom: json['schedule_room'] as String? ?? json['room_name'] as String?,
        roomId: json['room_id'] as String?,
        roomPhotoUrl: json['room_photo_url'] as String?,
        roomShortInfo: json['room_short_info'] as String?,
        feedbackRating: json['feedback_rating'] as int?,
        feedbackNote: json['feedback_note'] as String?,
        attendanceConfirmed: json['attendance_confirmed'] == 1 ||
            json['attendance_confirmed'] == true,
        serviceCategory: json['service_category'] as String?,
      );
}

class WaitlistEntry {
  WaitlistEntry({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.position,
    this.staffName,
    this.scheduleLabel,
  });

  final String id;
  final String serviceId;
  final String serviceName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final int position;
  final String? staffName;
  final String? scheduleLabel;

  bool get isOffered => status == 'offered';

  String get displayName => scheduleLabel?.isNotEmpty == true ? scheduleLabel! : serviceName;

  String get statusLabel => isOffered ? 'Θέση διαθέσιμη' : 'Σε αναμονή';

  factory WaitlistEntry.fromJson(Map<String, dynamic> json) => WaitlistEntry(
        id: json['id'] as String,
        serviceId: json['service_id'] as String,
        serviceName: json['service_name'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
        status: json['status'] as String? ?? 'waiting',
        position: json['position'] as int? ?? 1,
        staffName: json['staff_name'] as String?,
        scheduleLabel: json['schedule_label'] as String?,
      );
}

class TimeSlot {
  TimeSlot({
    required this.time,
    this.availableStaff = const [],
    this.availableCount,
    this.bookedCount,
    this.capacity,
    this.remainingSpots,
    this.isFull = false,
    this.waitlistAvailable = false,
    this.waitlistCount,
    this.label,
    this.roomId,
    this.roomName,
    this.roomPhotoUrl,
    this.roomShortInfo,
    this.subtitle,
    this.imageUrl,
    this.iconKey,
    this.preparationTips = const [],
    this.userHasBooking = false,
    this.userConflictService,
    this.userSameService = false,
  });

  final String time;
  final List<StaffMember> availableStaff;
  final int? availableCount;
  final int? bookedCount;
  final int? capacity;
  final int? remainingSpots;
  final bool isFull;
  final bool waitlistAvailable;
  final int? waitlistCount;
  final String? label;
  final String? roomId;
  final String? roomName;
  final String? roomPhotoUrl;
  final String? roomShortInfo;
  final String? subtitle;
  final String? imageUrl;
  final String? iconKey;
  final List<String> preparationTips;
  final bool userHasBooking;
  final String? userConflictService;
  final bool userSameService;

  bool get isBookable => !isFull && !userHasBooking && availableStaff.isNotEmpty;

  String? get userConflictLabel {
    if (!userHasBooking) return null;
    if (userSameService) return 'Έχεις ήδη κράτηση — πάτα για λεπτομέρειες';
    if (userConflictService != null && userConflictService!.isNotEmpty) {
      return 'Σύγκρουση με $userConflictService — πάτα για λεπτομέρειες';
    }
    return 'Μη διαθέσιμο — πάτα για λεπτομέρειες';
  }

  String? get userConflictTitle {
    if (!userHasBooking) return null;
    if (userSameService) return 'Έχεις ήδη κράτηση';
    return 'Σύγκρουση ώρας';
  }

  String userConflictDetail(String currentServiceName) {
    if (userSameService) {
      return 'Έχεις ήδη κράτηση για «$currentServiceName» στις $time.\n\n'
          'Δεν μπορείς να κλείσεις την ίδια υπηρεσία δύο φορές την ίδια ώρα. Επίλεξε άλλη ώρα.';
    }
    if (userConflictService != null && userConflictService!.isNotEmpty) {
      return 'Έχεις ήδη κράτηση για «$userConflictService» στις $time.\n\n'
          'Δεν μπορείς να κλείσεις «$currentServiceName» την ίδια ώρα. Επίλεξε άλλη ώρα.';
    }
    return 'Έχεις ήδη κράτηση στις $time.\n\nΕπίλεξε άλλη ώρα για να συνεχίσεις.';
  }

  String? get capacityLabel {
    if (capacity == null) return null;
    final booked = bookedCount ?? 0;
    final cap = capacity!;
    if (isFull) return 'Πλήρες ($booked/$cap)';
    return '$booked/$cap θέσεις';
  }

  String displayTitle(String mode) {
    if (mode == 'class' && label != null && label!.isNotEmpty) return label!;
    if (mode == 'room' && roomName != null && roomName!.isNotEmpty) return roomName!;
    if (label != null && label!.isNotEmpty) return label!;
    return time;
  }

  String? displaySubtitle(String mode) {
    if (roomShortInfo != null && roomShortInfo!.isNotEmpty) return roomShortInfo;
    if (mode == 'class') return subtitle ?? (roomName?.isNotEmpty == true ? roomName : null);
    if (mode == 'room') return label?.isNotEmpty == true ? label : subtitle;
    return subtitle ?? (roomName?.isNotEmpty == true ? roomName : null);
  }
}

class StaffMember {
  StaffMember({
    required this.id,
    required this.fullName,
    this.role,
    this.bio,
    this.colorHex,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String? role;
  final String? bio;
  final String? colorHex;
  final String? avatarUrl;

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String?,
        bio: json['bio'] as String?,
        colorHex: json['color_hex'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );
}

class MembershipCredit {
  MembershipCredit({
    required this.id,
    required this.totalSessions,
    required this.usedSessions,
    required this.remaining,
    required this.validFrom,
    required this.validUntil,
    this.serviceName,
    this.serviceDescription,
    this.planName,
    this.billingPeriod,
    this.planPriceCents,
    this.notes,
    this.accessState,
    this.daysInGraceLeft,
    this.serviceCategory,
    this.planType,
    this.nutritionIncludesMealPlan,
    this.nutritionIncludesMeasurements,
    this.nutritionIncludesFoodDiary,
    this.nutritionIncludesConsultations,
    this.nutritionConsultationSessions,
    this.planServices,
    this.lastPaymentDate,
  });

  final String id;
  final int totalSessions;
  final int usedSessions;
  final int remaining;
  final DateTime validFrom;
  final DateTime validUntil;
  final String? serviceName;
  final String? serviceDescription;
  final String? planName;
  final String? billingPeriod;
  final int? planPriceCents;
  final String? notes;
  final String? accessState;
  final int? daysInGraceLeft;
  final String? serviceCategory;
  final String? planType;
  final bool? nutritionIncludesMealPlan;
  final bool? nutritionIncludesMeasurements;
  final bool? nutritionIncludesFoodDiary;
  final bool? nutritionIncludesConsultations;
  final int? nutritionConsultationSessions;
  /// Per-service breakdown for combo plans, e.g. [{service_name, sessions_per_period, is_unlimited, remaining}]
  final List<Map<String, dynamic>>? planServices;
  final String? lastPaymentDate;

  bool get isNutritionProgram =>
      planType == 'nutrition' || serviceCategory == 'nutrition';
  bool get isNutritionConsultation => serviceCategory == 'nutrition_consultation';

  bool get isUnlimited => totalSessions >= 9999;
  bool get inGrace => accessState == 'grace';
  bool get canCancel => accessState != 'cancelled' && accessState != 'trial';

  double get usageProgress =>
      isUnlimited || totalSessions == 0 ? 0 : usedSessions / totalSessions;

  factory MembershipCredit.fromJson(Map<String, dynamic> json) => MembershipCredit(
        id: json['id'] as String,
        totalSessions: json['total_sessions'] as int,
        usedSessions: json['used_sessions'] as int? ?? 0,
        remaining: json['remaining'] as int? ?? 0,
        validFrom: DateTime.parse(json['valid_from'] as String),
        validUntil: DateTime.parse(json['valid_until'] as String),
        serviceName: json['service_name'] as String?,
        serviceDescription: json['service_description'] as String?,
        planName: json['plan_name'] as String?,
        billingPeriod: json['billing_period'] as String?,
        planPriceCents: json['plan_price_cents'] as int?,
        notes: json['notes'] as String?,
        accessState: json['access_state'] as String?,
        daysInGraceLeft: json['days_in_grace_left'] as int?,
        serviceCategory: json['service_category'] as String?,
        planType: json['plan_type'] as String?,
        nutritionIncludesMealPlan: json['nutrition_includes_meal_plan'] == true
            || json['nutrition_includes_meal_plan'] == 1,
        nutritionIncludesMeasurements: json['nutrition_includes_measurements'] == true
            || json['nutrition_includes_measurements'] == 1,
        nutritionIncludesFoodDiary: json['nutrition_includes_food_diary'] == true
            || json['nutrition_includes_food_diary'] == 1,
        nutritionIncludesConsultations: json['nutrition_includes_consultations'] == true
            || json['nutrition_includes_consultations'] == 1,
        nutritionConsultationSessions: json['nutrition_consultation_sessions'] as int?,
        planServices: json['plan_services'] != null
            ? List<Map<String, dynamic>>.from(
                (json['plan_services'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
              )
            : null,
        lastPaymentDate: json['last_payment_date'] as String?,
      );
}

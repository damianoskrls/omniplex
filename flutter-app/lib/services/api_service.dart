import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/tenant_config.dart';
import '../models/booking.dart';
import '../models/fitness_profile.dart';
import '../models/gym_info.dart';
import '../models/opening_hours.dart';
import '../models/service.dart';
import '../models/location.dart';
import '../models/nutrition.dart';
import '../models/user.dart';
import '../models/user_stats.dart';
import '../models/workout_metrics.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.payload});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? payload;

  @override
  String toString() => message;
}

class ApiService {
  ApiService(this.config, {this.token});

  final TenantConfig config;
  String? token;

  String get _base => config.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
  String get bizId => config.businessId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static const _requestTimeout = Duration(seconds: 8);
  static const _uploadTimeout = Duration(seconds: 90);

  Future<http.Response> _withTimeout(Future<http.Response> request) {
    return request.timeout(
      _requestTimeout,
      onTimeout: () => throw ApiException(
        'Ο server δεν απάντησε εγκαίρως ($_base).\n'
        'Έλεγξε ότι τρέχει το admin-api στη θύρα 3001 και ότι iPhone/Mac είναι στο ίδιο δίκτυο.',
      ),
    );
  }

  /// Returns null when registration is pending admin approval (no token issued).
  Future<void> registerRequest({
    required String fullName,
    required String phone,
    required String pin,
    String? email,
    String? locationId,
  }) async {
    final res = await _post(
      '/api/mobile/register',
      {
        'business_id': bizId,
        'full_name': fullName,
        'phone': phone,
        'pin': pin,
        if (email != null) 'email': email,
        if (locationId != null) 'location_id': locationId,
      },
    );
    _decode(res); // throws ApiException on error
  }

  Future<AppUser> login({
    required String phone,
    required String pin,
  }) async {
    final res = await _post(
      '/api/mobile/login',
      {
        'business_id': bizId,
        'phone': phone,
        'pin': pin,
      },
    );
    return _authResponse(res);
  }

  Future<AppUser> me() async {
    final res = await _get('/api/mobile/me');
    final data = _decode(res);
    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  // ── Staff auth ──────────────────────────────────────────────────────────────
  Future<AppUser> staffLogin({required String email, required String password}) async {
    final res = await _post('/api/mobile/staff/login', {'email': email, 'password': password});
    final data = _decode(res) as Map<String, dynamic>;
    token = data['token'] as String;
    return AppUser.fromStaffJson(data['staff'] as Map<String, dynamic>);
  }

  Future<AppUser> staffMe() async {
    final res = await _get('/api/mobile/staff/me');
    final data = _decode(res) as Map<String, dynamic>;
    return AppUser.fromStaffJson(data);
  }

  Future<Map<String, dynamic>> fetchStaffSchedule({String? date}) async {
    final res = await _get('/api/mobile/staff/schedule',
        query: date != null ? {'date': date} : null);
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchStaffWeekSchedule({String? from}) async {
    final res = await _get('/api/mobile/staff/schedule/week',
        query: from != null ? {'from': from} : null);
    return _decode(res) as Map<String, dynamic>;
  }

  Future<void> markAttendance(String bookingId, {required bool confirmed}) async {
    await _patch('/api/mobile/staff/bookings/$bookingId/attendance',
        {'confirmed': confirmed});
  }

  Future<Map<String, dynamic>> fetchStaffLeaves() async {
    final res = await _get('/api/mobile/staff/leaves');
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addStaffLeave({
    required String dateFrom, required String dateTo, String? reason,
  }) async {
    final res = await _post('/api/mobile/staff/leaves', {
      'date_from': dateFrom, 'date_to': dateTo,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return _decode(res) as Map<String, dynamic>;
  }

  Future<void> deleteStaffLeave(String leaveId) async {
    final res = await _withTimeout(http.delete(
      Uri.parse('$_base/api/mobile/staff/leaves/$leaveId'),
      headers: _headers,
    ));
    _decode(res);
  }

  Future<List<FitnessGoalOption>> fetchFitnessGoals() async {
    final res = await _get('/api/mobile/fitness-goals');
    final data = _decode(res) as List;
    return data.map((e) => FitnessGoalOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AppUser> updateMyFitnessProfile({
    double? weightKg,
    double? targetWeightKg,
    String? fitnessGoal,
  }) async {
    final body = <String, dynamic>{};
    if (weightKg != null) body['weight_kg'] = weightKg;
    if (targetWeightKg != null) body['target_weight_kg'] = targetWeightKg;
    if (fitnessGoal != null) body['fitness_goal'] = fitnessGoal;

    final res = await _patch('/api/mobile/me/fitness', body);
    return AppUser.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<bool> fetchNutritionAccess() async {
    final res = await _get('/api/mobile/nutrition/access');
    final data = _decode(res) as Map<String, dynamic>;
    final access = data['has_access'];
    return access == true || access == 1;
  }

  Future<({
    bool canBook,
    BookService? service,
    Map<String, dynamic> credits,
    Map<String, dynamic>? pendingBooking,
    Map<String, dynamic>? upcomingBooking,
    List<Map<String, dynamic>> nutritionists,
    bool needsNutritionistChoice,
  })> fetchNutritionConsultation() async {
    final res = await _get('/api/mobile/nutrition/consultation');
    final data = _decode(res) as Map<String, dynamic>;
    final serviceJson = data['service'] as Map<String, dynamic>?;
    return (
      canBook: data['can_book'] == true,
      service: serviceJson != null ? BookService.fromJson(serviceJson) : null,
      credits: (data['credits'] as Map<String, dynamic>?) ?? {},
      pendingBooking: data['pending_booking'] as Map<String, dynamic>?,
      upcomingBooking: data['upcoming_booking'] as Map<String, dynamic>?,
      nutritionists: (data['nutritionists'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      needsNutritionistChoice: data['needs_nutritionist_choice'] == true,
    );
  }

  Future<({List<TimeSlot> slots, String? message})> fetchNutritionConsultationSlots({
    required String date,
    String? nutritionistId,
  }) async {
    final query = <String, String>{'date': date};
    if (nutritionistId != null && nutritionistId.isNotEmpty) {
      query['nutritionist_id'] = nutritionistId;
    }
    final res = await _get('/api/mobile/nutrition/consultation/slots', query: query);
    final data = _decode(res) as Map<String, dynamic>;
    final slots = (data['slots'] as List? ?? []).map((s) {
      final map = s as Map<String, dynamic>;
      final staff = (map['available_staff'] as List? ?? [])
          .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
          .toList();
      return TimeSlot(
        time: map['time'] as String,
        availableStaff: staff,
        isFull: map['is_full'] as bool? ?? false,
      );
    }).toList();
    return (slots: slots, message: data['message'] as String?);
  }

  Future<void> bookNutritionConsultation({
    required String date,
    required String time,
    String? nutritionistId,
  }) async {
    await _post('/api/mobile/nutrition/consultation/book', {
      'date': date,
      'time': time,
      if (nutritionistId != null && nutritionistId.isNotEmpty) 'nutritionist_id': nutritionistId,
    });
  }

  Future<List<FoodLogEntry>> fetchNutritionFoodLogs({String? date}) async {
    final query = date == null ? '' : '?date=$date';
    final res = await _get('/api/mobile/nutrition/food-logs$query');
    final data = _decode(res) as Map<String, dynamic>;
    return (data['logs'] as List? ?? [])
        .map((e) => FoodLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NutritionGoals> fetchNutritionGoals() async {
    final res = await _get('/api/mobile/nutrition/goals');
    return NutritionGoals.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<NutritionToday> fetchNutritionToday() async {
    final res = await _get('/api/mobile/nutrition/today');
    return NutritionToday.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<MealPlanWeek> fetchNutritionMealPlan({String? date, String? weekStart}) async {
    final params = <String>[];
    if (date != null) params.add('date=$date');
    else if (weekStart != null) params.add('week_start=$weekStart');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final res = await _get('/api/mobile/nutrition/meal-plan$query');
    return MealPlanWeek.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<NutritionProgress> fetchNutritionProgress() async {
    final res = await _get('/api/mobile/nutrition/progress');
    return NutritionProgress.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<NutritionProgress> logNutritionMeasurement({
    required double weightKg,
    required String measuredOn,
    String? timeOfDay,
    String? measuredTime,
    double? bodyFatPct,
    double? muscleMassKg,
    double? bmi,
    String? notes,
  }) async {
    final res = await _post('/api/mobile/nutrition/measurements', {
      'weight_kg': weightKg,
      'measured_on': measuredOn,
      if (timeOfDay != null) 'time_of_day': timeOfDay,
      if (measuredTime != null) 'measured_time': measuredTime,
      if (bodyFatPct != null) 'body_fat_pct': bodyFatPct,
      if (muscleMassKg != null) 'muscle_mass_kg': muscleMassKg,
      if (bmi != null) 'bmi': bmi,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    final data = _decode(res) as Map<String, dynamic>;
    return NutritionProgress.fromJson(data['progress'] as Map<String, dynamic>);
  }

  Future<List<MealTypeOption>> fetchMealTypes() async {
    final res = await _get('/api/mobile/nutrition/meal-types');
    final data = _decode(res) as List;
    return data.map((e) => MealTypeOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ShoppingListItem>> fetchNutritionShoppingList({String? date, String? weekStart, bool smart = true}) async {
    final params = <String>[];
    if (date != null) params.add('date=$date');
    else if (weekStart != null) params.add('week_start=$weekStart');
    if (smart) params.add('smart=1');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final res = await _get('/api/mobile/nutrition/shopping-list$query');
    final data = _decode(res) as Map<String, dynamic>;
    return (data['items'] as List? ?? [])
        .map((e) => ShoppingListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FoodLogEntry> logFood({
    required String mealType,
    required String description,
    String? date,
    String? planOptionId,
    String? photoPath,
  }) async {
    if (photoPath != null) {
      final uri = Uri.parse('$_base/api/mobile/nutrition/food-logs');
      final request = http.MultipartRequest('POST', uri);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.fields['meal_type'] = mealType;
      request.fields['description'] = description;
      if (date != null) request.fields['date'] = date;
      if (planOptionId != null) request.fields['plan_option_id'] = planOptionId;
      request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
      final streamed = await request.send().timeout(_requestTimeout);
      final res = await http.Response.fromStream(streamed);
      return FoodLogEntry.fromJson(_decode(res) as Map<String, dynamic>);
    }

    final res = await _post('/api/mobile/nutrition/food-logs', {
      'meal_type': mealType,
      'description': description,
      if (date != null) 'date': date,
      if (planOptionId != null) 'plan_option_id': planOptionId,
    });
    return FoodLogEntry.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<NutritionGoals> updateNutritionGoals({
    double? weightKg,
    double? targetWeightKg,
    double? heightCm,
    double? bodyFatPct,
  }) async {
    final body = <String, dynamic>{};
    if (weightKg != null) body['weight_kg'] = weightKg;
    if (targetWeightKg != null) body['target_weight_kg'] = targetWeightKg;
    if (heightCm != null) body['height_cm'] = heightCm;
    if (bodyFatPct != null) body['body_fat_pct'] = bodyFatPct;
    final res = await _patch('/api/mobile/nutrition/goals', body);
    return NutritionGoals.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<List<BookService>> fetchServices() async {
    final res = await _get('/api/booking/$bizId/services');
    final data = _decode(res) as List;
    return data.map((e) => BookService.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<GymInfo> fetchGymInfo() async {
    final res = await _get('/api/booking/$bizId/gym-info');
    return GymInfo.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<OpeningHoursConfig?> fetchOpeningHours({String? locationId}) async {
    try {
      final res = await _get(
        '/api/booking/$bizId/opening-hours',
        query: locationId != null ? {'location_id': locationId} : null,
      );
      final data = _decode(res) as Map<String, dynamic>;
      final raw = data['opening_hours'];
      if (raw == null) return null;
      final map = raw is Map<String, dynamic>
          ? raw
          : (jsonDecode(raw as String) as Map<String, dynamic>);
      return OpeningHoursConfig.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<({bool multiLocation, List<GymLocation> locations})> fetchLocations({
    String? serviceId,
  }) async {
    final res = await _get(
      '/api/booking/$bizId/locations',
      query: serviceId != null ? {'service_id': serviceId} : null,
    );
    final data = _decode(res) as Map<String, dynamic>;
    final list = (data['locations'] as List? ?? [])
        .map((e) => GymLocation.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      multiLocation: data['multi_location'] as bool? ?? false,
      locations: list,
    );
  }

  Future<({
    List<TimeSlot> slots,
    bool featureWaitlist,
    String? message,
    String? dayStatus,
  })> fetchSlots({
    required String serviceId,
    required String date,
    String? excludeBookingId,
    String? locationId,
  }) async {
    final params = {
      'service_id': serviceId,
      'date': date,
      if (excludeBookingId != null) 'exclude_booking_id': excludeBookingId,
      if (locationId != null) 'location_id': locationId,
    };
    final res = await _get('/api/booking/$bizId/slots', query: params);
    final data = _decode(res) as Map<String, dynamic>;
    final slots = data['slots'] as List? ?? [];
    final parsed = slots.map((s) {
      final map = s as Map<String, dynamic>;
      final staff = (map['available_staff'] as List? ?? [])
          .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
          .toList();
      return TimeSlot(
        time: map['time'] as String,
        availableStaff: staff,
        availableCount: map['available_count'] as int?,
        bookedCount: map['booked_count'] as int?,
        capacity: map['capacity'] as int?,
        remainingSpots: map['remaining_spots'] as int?,
        isFull: map['is_full'] as bool? ?? false,
        waitlistAvailable: map['waitlist_available'] as bool? ?? false,
        waitlistCount: map['waitlist_count'] as int?,
        label: map['label'] as String?,
        roomId: map['room_id'] as String?,
        roomName: map['room_name'] as String?,
        roomPhotoUrl: map['room_photo_url'] as String?,
        roomShortInfo: map['room_short_info'] as String?,
        subtitle: map['subtitle'] as String?,
        imageUrl: map['image_url'] as String?,
        iconKey: map['icon_key'] as String?,
        preparationTips: (map['preparation_tips'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        userHasBooking: map['user_has_booking'] as bool? ?? false,
        userConflictService: map['user_conflict_service'] as String?,
        userSameService: map['user_same_service'] as bool? ?? false,
      );
    }).toList();
    return (
      slots: parsed,
      featureWaitlist: data['feature_waitlist'] as bool? ?? false,
      message: data['message'] as String?,
      dayStatus: data['day_status'] as String?,
    );
  }

  Future<Map<String, dynamic>> createBooking({
    required String serviceId,
    required String date,
    required String time,
    String? staffId,
    String? locationId,
    bool useCredit = true,
    bool cancelConflicting = false,
  }) async {
    final res = await _post('/api/booking/$bizId/create', {
      'service_id': serviceId,
      'date': date,
      'time': time,
      if (staffId != null) 'staff_id': staffId,
      if (locationId != null) 'location_id': locationId,
      'use_credit': useCredit,
      if (cancelConflicting) 'cancel_conflicting': true,
    });
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createBulkBookings({
    required String serviceId,
    required List<Map<String, String>> slots,
    String? staffId,
    String? locationId,
    bool useCredit = true,
  }) async {
    final res = await _post('/api/booking/$bizId/create-bulk', {
      'service_id': serviceId,
      'slots': slots,
      if (staffId != null) 'staff_id': staffId,
      if (locationId != null) 'location_id': locationId,
      'use_credit': useCredit,
    });
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Booking> fetchBookingDetail(String bookingId) async {
    final res = await _get('/api/booking/$bizId/my-bookings/$bookingId');
    return Booking.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> completeWorkout({
    required String bookingId,
    required bool attended,
    int? rating,
    String? note,
    Map<String, dynamic>? healthWorkout,
  }) async {
    final res = await _post('/api/booking/$bizId/my-bookings/$bookingId/complete', {
      'attended': attended,
      if (rating != null) 'rating': rating,
      if (note != null) 'note': note,
      if (healthWorkout != null) 'health_workout': healthWorkout,
    });
    return _decode(res) as Map<String, dynamic>;
  }

  Future<UserStats> fetchMyStats() async {
    final res = await _get('/api/booking/$bizId/my-stats');
    return UserStats.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<WorkoutMetricsData> fetchWorkoutMetrics({int days = 30}) async {
    final res = await _get('/api/booking/$bizId/my-workout-metrics?days=$days');
    return WorkoutMetricsData.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<UserStats> updateMyGoal(int targetSessions, {String period = 'monthly'}) async {
    final res = await _put('/api/booking/$bizId/my-goal', {
      'target_sessions': targetSessions,
      'period': period,
    });
    return UserStats.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<({List<PaymentRecord> payments, int totalBalanceCents})> fetchMyPayments() async {
    final res = await _get('/api/booking/$bizId/my-payments');
    final data = _decode(res) as Map<String, dynamic>;
    final list = (data['payments'] as List? ?? [])
        .map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      payments: list,
      totalBalanceCents: data['total_balance_cents'] as int? ?? 0,
    );
  }

  Future<({List<Map<String, dynamic>> notifications, int unreadCount})> fetchNotifications() async {
    final res = await _get('/api/mobile/notifications');
    final data = _decode(res) as Map<String, dynamic>;
    return (
      notifications: (data['notifications'] as List? ?? []).cast<Map<String, dynamic>>(),
      unreadCount: data['unread_count'] as int? ?? 0,
    );
  }

  Future<void> markNotificationRead(String id) async {
    await _patch('/api/mobile/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _patch('/api/mobile/notifications/read-all');
  }

  Future<List<Map<String, dynamic>>> fetchMessageThreads() async {
    final res = await _get('/api/booking/$bizId/messages/threads');
    final data = _decode(res) as Map<String, dynamic>;
    return (data['threads'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchMessagePeers() async {
    final res = await _get('/api/booking/$bizId/messages/peers');
    final data = _decode(res) as Map<String, dynamic>;
    return (data['peers'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchMessageThread(String threadId) async {
    final res = await _get('/api/booking/$bizId/messages/threads/$threadId');
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> openMessageThread(Map<String, dynamic> peer) async {
    final res = await _post('/api/booking/$bizId/messages/threads', peer);
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMessageToThread(
    String threadId,
    String body, {
    String? attachmentUrl,
    String? messageType,
    List<int>? imageBytes,
  }) async {
    final payload = <String, dynamic>{
      'body': body,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (messageType != null) 'message_type': messageType,
      if (imageBytes != null && imageBytes.isNotEmpty) 'image_base64': base64Encode(imageBytes),
    };
    final hasImage = imageBytes != null && imageBytes.isNotEmpty;
    final res = hasImage
        ? await _postWithTimeout(
            '/api/booking/$bizId/messages/threads/$threadId/messages',
            payload,
            timeout: _uploadTimeout,
          )
        : await _post('/api/booking/$bizId/messages/threads/$threadId/messages', payload);
    return _decode(res) as Map<String, dynamic>;
  }

  Future<String> uploadMessageImage(String threadId, String filePath) async {
    final uri = Uri.parse('$_base/api/booking/$bizId/messages/threads/$threadId/upload');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      filePath,
      contentType: http.MediaType('image', 'jpeg'),
    ));
    final streamed = await request.send().timeout(
      _uploadTimeout,
      onTimeout: () => throw ApiException(
        'Η αποστολή εικόνας διήρκεσε πολύ. Δοκίμασε ξανά με καλύτερο Wi‑Fi.',
      ),
    );
    final res = await http.Response.fromStream(streamed);
    final data = _decode(res) as Map<String, dynamic>;
    final url = data['attachment_url'] as String?;
    if (url == null || url.isEmpty) {
      throw ApiException('Αποτυχία αποστολής εικόνας');
    }
    return url;
  }

  Future<void> markMessageThreadRead(String threadId) async {
    await _post('/api/booking/$bizId/messages/threads/$threadId/read', {});
  }

  Future<Map<String, dynamic>> fetchMessages() async {
    final res = await _get('/api/booking/$bizId/messages');
    return _decode(res) as Map<String, dynamic>;
  }

  Future<int> fetchMessageUnreadCount() async {
    final res = await _get('/api/booking/$bizId/messages/unread-count');
    final data = _decode(res) as Map<String, dynamic>;
    return data['unread_count'] as int? ?? 0;
  }

  Future<Map<String, dynamic>> sendMessage(String body) async {
    final res = await _post('/api/booking/$bizId/messages', {'body': body});
    return _decode(res) as Map<String, dynamic>;
  }

  Future<void> markMessagesRead() async {
    await _post('/api/booking/$bizId/messages/read', {});
  }

  Future<void> registerDeviceToken(String fcmToken, {String platform = 'unknown'}) async {
    await _post('/api/mobile/device-token', {
      'fcm_token': fcmToken,
      'platform': platform,
    });
  }

  Future<void> unregisterDeviceToken(String fcmToken) async {
    try {
      await _withTimeout(http.delete(
        Uri.parse('$_base/api/mobile/device-token'),
        headers: _headers,
        body: jsonEncode({'fcm_token': fcmToken}),
      ));
    } catch (_) {
      // Best-effort: don't block gym switch on network failure
    }
  }

  // ── Marketplace ───────────────────────────────────────────────────────────
  /// Resolves a relative image path to an absolute URL using _base.
  String? resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '$_base$url';
  }

  Map<String, dynamic> _resolveProductImages(Map<String, dynamic> p) {
    final resolved = Map<String, dynamic>.from(p);
    resolved['image_url'] = resolveImageUrl(p['image_url'] as String?);
    if (p['images'] is List) {
      resolved['images'] = (p['images'] as List)
          .map((u) => resolveImageUrl(u as String?))
          .where((u) => u != null)
          .toList();
    }
    return resolved;
  }

  Future<List<Map<String, dynamic>>> fetchMarketplaceProducts({String? category}) async {
    final res = await _get('/api/marketplace/$bizId/products',
        query: category != null ? {'category': category} : null);
    final data = _decode(res) as Map<String, dynamic>;
    return (data['products'] as List)
        .cast<Map<String, dynamic>>()
        .map(_resolveProductImages)
        .toList();
  }

  Future<Map<String, dynamic>> fetchMarketplaceProduct(String productId) async {
    final res = await _get('/api/marketplace/$bizId/products/$productId');
    return _resolveProductImages(_decode(res) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> placeMarketplaceOrder(
      List<Map<String, dynamic>> items, {
        String? notes,
        String? paymentMethod,
        String? customerName,
        String? customerPhone,
        String? shippingAddress,
        String? deliveryMethod,
      }) async {
    final res = await _post('/api/marketplace/$bizId/orders', {
      'items': items,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (customerName != null && customerName.isNotEmpty) 'customer_name': customerName,
      if (customerPhone != null && customerPhone.isNotEmpty) 'customer_phone': customerPhone,
      if (shippingAddress != null && shippingAddress.isNotEmpty) 'shipping_address': shippingAddress,
      if (deliveryMethod != null) 'delivery_method': deliveryMethod,
    });
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchMarketplaceSettings() async {
    final res = await _get('/api/marketplace/$bizId/mobile-settings');
    return _decode(res) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchMyMarketplaceOrders() async {
    final res = await _get('/api/marketplace/$bizId/my-orders');
    final data = _decode(res) as Map<String, dynamic>;
    return (data['orders'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchPaymentOptions() async {
    final res = await _get('/api/payments-online/$bizId/options');
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> declareBankTransfer(String paymentId) async {
    final res = await _post('/api/payments-online/$bizId/bank-transfer', {'payment_id': paymentId});
    return _decode(res) as Map<String, dynamic>;
  }

  Future<List<Booking>> fetchMyBookings() async {
    final res = await _get('/api/booking/$bizId/my-bookings');
    final data = _decode(res) as List;
    return data.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> cancelBooking(String bookingId) async {
    final res = await _patch('/api/booking/$bizId/my-bookings/$bookingId/cancel');
    _decode(res);
  }

  Future<Map<String, dynamic>> rescheduleBooking({
    required String bookingId,
    required String date,
    required String time,
    String? staffId,
  }) async {
    final res = await _patch('/api/booking/$bizId/my-bookings/$bookingId', {
      'date': date,
      'time': time,
      if (staffId != null) 'staff_id': staffId,
    });
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinWaitlist({
    required String serviceId,
    required String date,
    required String time,
    String? staffId,
    String? locationId,
  }) async {
    final res = await _post('/api/booking/$bizId/waitlist', {
      'service_id': serviceId,
      'date': date,
      'time': time,
      if (staffId != null) 'staff_id': staffId,
      if (locationId != null) 'location_id': locationId,
    });
    return _decode(res) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchMyWaitlist() async {
    final res = await _get('/api/booking/$bizId/my-waitlist');
    final data = _decode(res) as List;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> leaveWaitlist(String waitlistId) async {
    final res = await http.delete(
      Uri.parse('$_base/api/booking/$bizId/waitlist/$waitlistId'),
      headers: _headers,
    );
    _decode(res);
  }

  Future<List<MembershipCredit>> fetchMyCredits() async {
    final res = await _get('/api/booking/$bizId/my-credits');
    final data = _decode(res) as List;
    return data.map((e) => MembershipCredit.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> cancelMembership(String membershipId, {String? reason}) async {
    final res = await _patch(
      '/api/booking/$bizId/my-credits/$membershipId/cancel',
      {'reason': reason},
    );
    _decode(res);
  }

  Future<List<Map<String, dynamic>>> fetchQrCheckinOptions(String scannedBizId) async {
    final res = await _get('/api/booking/$scannedBizId/qr-checkin/options');
    final data = _decode(res) as Map<String, dynamic>;
    return (data['eligible'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> qrCheckIn(String scannedBizId, {required String bookingId}) async {
    final res = await _post('/api/booking/$scannedBizId/qr-checkin', {'bookingId': bookingId});
    return _decode(res) as Map<String, dynamic>;
  }

  AppUser _authResponse(http.Response res) {
    final data = _decode(res) as Map<String, dynamic>;
    token = data['token'] as String;
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<http.Response> _postWithTimeout(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = _requestTimeout,
  }) async {
    try {
      return await http
          .post(
            Uri.parse('$_base$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(
            timeout,
            onTimeout: () => throw ApiException(
              'Η αποστολή διήρκεσε πολύ. Δοκίμασε ξανά με καλύτερο Wi‑Fi.',
            ),
          );
    } on SocketException {
      throw ApiException(
        'Δεν συνδέεται ο server. Βεβαιώσου ότι τρέχει το admin-api στη θύρα 3001.',
      );
    } on HttpException {
      throw ApiException('Σφάλμα δικτύου. Δοκίμασε ξανά.');
    } on FormatException {
      throw ApiException('Μη έγκυρη απάντηση από τον server.');
    }
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    try {
      return await _withTimeout(http.post(
        Uri.parse('$_base$path'),
        headers: _headers,
        body: jsonEncode(body),
      ));
    } on SocketException {
      throw ApiException(
        'Δεν συνδέεται ο server. Βεβαιώσου ότι τρέχει το admin-api στη θύρα 3001.',
      );
    } on HttpException {
      throw ApiException('Σφάλμα δικτύου. Δοκίμασε ξανά.');
    } on FormatException {
      throw ApiException('Μη έγκυρη απάντηση από τον server.');
    }
  }

  Future<http.Response> _get(String path, {Map<String, String>? query}) async {
    try {
      final uri = Uri.parse('$_base$path').replace(queryParameters: query);
      return await _withTimeout(http.get(uri, headers: _headers));
    } on SocketException {
      throw ApiException(
        'Δεν συνδέεται ο server. Βεβαιώσου ότι τρέχει το admin-api στη θύρα 3001.',
      );
    } on HttpException {
      throw ApiException('Σφάλμα δικτύου. Δοκίμασε ξανά.');
    }
  }

  Future<http.Response> _put(String path, Map<String, dynamic> body) async {
    try {
      return await _withTimeout(http.put(
        Uri.parse('$_base$path'),
        headers: _headers,
        body: jsonEncode(body),
      ));
    } on SocketException {
      throw ApiException(
        'Δεν συνδέεται ο server. Βεβαιώσου ότι τρέχει το admin-api στη θύρα 3001.',
      );
    }
  }

  Future<http.Response> _patch(String path, [Map<String, dynamic>? body]) async {
    try {
      return await _withTimeout(http.patch(
        Uri.parse('$_base$path'),
        headers: _headers,
        body: body == null ? null : jsonEncode(body),
      ));
    } on SocketException {
      throw ApiException(
        'Δεν συνδέεται ο server. Βεβαιώσου ότι τρέχει το admin-api στη θύρα 3001.',
      );
    } on HttpException {
      throw ApiException('Σφάλμα δικτύου. Δοκίμασε ξανά.');
    }
  }

  dynamic _decode(http.Response res) {
    dynamic body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      throw ApiException('Μη έγκυρη απάντηση από τον server.');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final message = body is Map ? (body['error'] as String? ?? 'Σφάλμα') : 'Σφάλμα';
    final payload = body is Map ? Map<String, dynamic>.from(body) : null;
    throw ApiException(message, statusCode: res.statusCode, payload: payload);
  }

  // ── Community ────────────────────────────────────────────────────────────────

  Future<String?> uploadCommunityMedia(Uint8List bytes, String filename) async {
    final uri = Uri.parse('$_base/api/community/mobile/$bizId/posts/upload-media');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final isVideo = filename.endsWith('.mp4') || filename.endsWith('.mov');
    final contentType = isVideo ? MediaType('video', 'mp4') : MediaType('image', 'jpeg');
    request.files.add(http.MultipartFile.fromBytes('files', bytes, filename: filename, contentType: contentType));
    final streamed = await request.send().timeout(_uploadTimeout);
    final res = await http.Response.fromStream(streamed);
    final data = _decode(res) as Map;
    final media = data['media'] as List?;
    return (media?.isNotEmpty == true) ? media!.first['url'] as String? : null;
  }

  Future<void> deleteCommunityComment(String postId, String commentId) async {
    final res = await http.delete(
      Uri.parse('$_base/api/community/mobile/$bizId/comments/$commentId'),
      headers: _headers,
    );
    _decode(res);
  }

  Future<List<Map<String, dynamic>>> fetchCommunityMentionables() async {
    final res = await _get('/api/community/mobile/$bizId/mentionables');
    final data = _decode(res) as Map<String, dynamic>;
    return (data['mentionables'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createCommunityPostWithMentions({
    String? body, List<Map<String, dynamic>>? media, List<Map<String, dynamic>>? mentions,
  }) async {
    final res = await _post('/api/community/mobile/$bizId/posts', {
      if (body != null) 'body': body,
      if (media != null && media.isNotEmpty) 'media': media,
      if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
    });
    return Map<String, dynamic>.from(_decode(res) as Map);
  }

  Future<Map<String, dynamic>> addCommunityCommentWithMentions(
    String postId, String body, {List<Map<String, dynamic>>? mentions}
  ) async {
    final res = await _post('/api/community/mobile/$bizId/posts/$postId/comments', {
      'body': body,
      if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
    });
    return Map<String, dynamic>.from(_decode(res) as Map);
  }

  Future<Map<String, dynamic>> getCommunityPosts({String? cursor, int limit = 20}) async {
    final query = <String, String>{'limit': '$limit'};
    if (cursor != null) query['cursor'] = cursor;
    final qs = query.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    final res = await _get('/api/community/mobile/$bizId/posts?$qs');
    return Map<String, dynamic>.from(_decode(res) as Map);
  }

  Future<Map<String, dynamic>> createCommunityPost({String? body, List<Map<String, dynamic>>? media}) async {
    final res = await _post('/api/community/mobile/$bizId/posts', {
      if (body != null) 'body': body,
      if (media != null && media.isNotEmpty) 'media': media,
    });
    return Map<String, dynamic>.from(_decode(res) as Map);
  }

  Future<Map<String, dynamic>> reactCommunityPost(String postId) async {
    final res = await _post('/api/community/mobile/$bizId/posts/$postId/react', {});
    return Map<String, dynamic>.from(_decode(res) as Map);
  }

  Future<Map<String, dynamic>> addCommunityComment(String postId, String body) async {
    final res = await _post('/api/community/mobile/$bizId/posts/$postId/comments', {'body': body});
    return Map<String, dynamic>.from(_decode(res) as Map);
  }

  Future<void> deleteCommunityPost(String postId) async {
    final res = await http.delete(
      Uri.parse('$_base/api/community/mobile/$bizId/posts/$postId'),
      headers: _headers,
    );
    _decode(res);
  }

  Future<Map<String, dynamic>> fetchMyCheckinCode() async {
    final res = await _withTimeout(http.get(
      Uri.parse('$_base/api/checkin/$bizId/my-code'),
      headers: _headers,
    ));
    return Map<String, dynamic>.from(_decode(res) as Map);
  }

  Future<List<Map<String, dynamic>>> fetchMyPrograms(String userId) async {
    final res = await _withTimeout(http.get(
      Uri.parse('$_base/api/client-admin/my-programs'),
      headers: {
        ..._headers,
        'x-business-id': bizId,
        'x-user-id': userId,
      },
    ));
    final data = _decode(res) as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final res = await _post(path, body);
    return Map<String, dynamic>.from(_decode(res) as Map);
  }
}

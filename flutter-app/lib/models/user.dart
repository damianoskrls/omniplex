import 'fitness_profile.dart';

enum UserRole { customer, staff }

class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.businessId,
    this.loyaltyPoints = 0,
    this.fitnessProfile = const FitnessProfile(),
    this.role = UserRole.customer,
    this.staffRole,
    this.avatarUrl,
    this.colorHex,
    this.bio,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String businessId;
  final int loyaltyPoints;
  final FitnessProfile fitnessProfile;
  final UserRole role;
  final String? staffRole;   // e.g. "Trainer", "Καθηγητής Φυσικής Αγωγής"
  final String? avatarUrl;
  final String? colorHex;
  final String? bio;

  bool get isStaff => role == UserRole.staff;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        businessId: json['business_id'] as String,
        loyaltyPoints: json['loyalty_points'] as int? ?? 0,
        fitnessProfile: FitnessProfile.fromUserJson(json),
      );

  factory AppUser.fromStaffJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String? ?? '',
        businessId: json['business_id'] as String,
        role: UserRole.staff,
        staffRole: json['role'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        colorHex: json['color_hex'] as String?,
        bio: json['bio'] as String?,
      );
}

import 'booking.dart';
import 'opening_hours.dart';

class GymRoom {
  GymRoom({
    required this.id,
    required this.name,
    this.shortInfo,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String? shortInfo;
  final String? photoUrl;

  factory GymRoom.fromJson(Map<String, dynamic> json) => GymRoom(
        id: json['id'] as String,
        name: json['name'] as String,
        shortInfo: json['short_info'] as String?,
        photoUrl: json['photo_url'] as String?,
      );
}

class GymLocationDetail {
  GymLocationDetail({
    this.id,
    required this.name,
    this.slug,
    this.address,
    this.city,
    this.phone,
    this.email,
    this.openingHours,
    this.rooms = const [],
  });

  final String? id;
  final String name;
  final String? slug;
  final String? address;
  final String? city;
  final String? phone;
  final String? email;
  final OpeningHoursConfig? openingHours;
  final List<GymRoom> rooms;

  String? get fullAddress {
    final parts = [address, city].where((p) => p != null && p.trim().isNotEmpty).cast<String>();
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  factory GymLocationDetail.fromJson(Map<String, dynamic> json) {
    final rawHours = json['opening_hours'];
    OpeningHoursConfig? hours;
    if (rawHours is Map<String, dynamic>) {
      hours = OpeningHoursConfig.fromJson(rawHours);
    }

    final roomsJson = json['rooms'];
    return GymLocationDetail(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      openingHours: hours,
      rooms: roomsJson is List
          ? roomsJson.map((e) => GymRoom.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
    );
  }
}

class GymStaffProfile {
  GymStaffProfile({
    required this.member,
    this.locationNames = const [],
  });

  final StaffMember member;
  final List<String> locationNames;

  factory GymStaffProfile.fromJson(Map<String, dynamic> json) => GymStaffProfile(
        member: StaffMember.fromJson(json),
        locationNames: (json['location_names'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
}

class GymInfo {
  GymInfo({
    required this.name,
    required this.appName,
    this.slug,
    this.logoUrl,
    this.address,
    this.phone,
    this.email,
    this.ownerName,
    this.ownerPhone,
    this.openingHours,
    this.multiLocation = false,
    this.locations = const [],
    this.trainers = const [],
    this.nutritionists = const [],
  });

  final String name;
  final String appName;
  final String? slug;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final String? email;
  final String? ownerName;
  final String? ownerPhone;
  final OpeningHoursConfig? openingHours;
  final bool multiLocation;
  final List<GymLocationDetail> locations;
  final List<GymStaffProfile> trainers;
  final List<GymStaffProfile> nutritionists;

  factory GymInfo.fromJson(Map<String, dynamic> json) {
    final rawHours = json['opening_hours'];
    OpeningHoursConfig? hours;
    if (rawHours is Map<String, dynamic>) {
      hours = OpeningHoursConfig.fromJson(rawHours);
    }

    List<GymLocationDetail> locations = const [];
    final locJson = json['locations'];
    if (locJson is List) {
      locations = locJson.map((e) => GymLocationDetail.fromJson(e as Map<String, dynamic>)).toList();
    }

    List<GymStaffProfile> parseStaffList(dynamic raw) {
      if (raw is! List) return const [];
      return raw.map((e) => GymStaffProfile.fromJson(e as Map<String, dynamic>)).toList();
    }

    return GymInfo(
      name: json['name'] as String? ?? '',
      appName: json['appName'] as String? ?? json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      logoUrl: json['logoUrl'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      ownerName: json['owner_name'] as String?,
      ownerPhone: json['owner_phone'] as String?,
      openingHours: hours,
      multiLocation: json['multi_location'] == true,
      locations: locations,
      trainers: parseStaffList(json['trainers']),
      nutritionists: parseStaffList(json['nutritionists']),
    );
  }
}

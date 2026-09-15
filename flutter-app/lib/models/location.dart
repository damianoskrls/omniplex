class GymLocation {
  GymLocation({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.phone,
  });

  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? phone;

  String get displayLine {
    final parts = [address, city].where((p) => p != null && p.trim().isNotEmpty).cast<String>().toList();
    return parts.join(', ');
  }

  factory GymLocation.fromJson(Map<String, dynamic> json) => GymLocation(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        city: json['city'] as String?,
        phone: json['phone'] as String?,
      );
}

class BookService {
  BookService({
    required this.id,
    required this.name,
    this.description,
    required this.durationMins,
    required this.priceCents,
    this.category,
    this.creditsRemaining = 0,
    this.creditsValidUntil,
    this.canBook = true,
    this.hasMembership = false,
    this.isUnlimited = false,
    this.hideStaffSelection = false,
    this.imageUrl,
    this.slotLabelMode = 'time_only',
  });

  final String id;
  final String name;
  final String? description;
  final int durationMins;
  final int priceCents;
  final String? category;
  final int creditsRemaining;
  final DateTime? creditsValidUntil;
  final bool canBook;
  final bool hasMembership;
  final bool isUnlimited;
  final bool hideStaffSelection;
  final String? imageUrl;
  final String slotLabelMode;

  factory BookService.fromJson(Map<String, dynamic> json) => BookService(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        durationMins: json['duration_mins'] as int,
        priceCents: json['price_cents'] as int? ?? 0,
        category: json['category'] as String?,
        creditsRemaining: json['credits_remaining'] as int? ?? 0,
        creditsValidUntil: json['credits_valid_until'] != null
            ? DateTime.parse(json['credits_valid_until'] as String)
            : null,
        canBook: json['can_book'] as bool? ?? true,
        hasMembership: json['has_membership'] as bool? ?? false,
        isUnlimited: json['is_unlimited'] as bool? ?? false,
        hideStaffSelection: json['hide_staff_selection'] as bool? ?? false,
        imageUrl: json['image_url'] as String?,
        slotLabelMode: json['slot_label_mode'] as String? ?? 'time_only',
      );
}

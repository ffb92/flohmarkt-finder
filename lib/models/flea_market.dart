/// Datenmodell für Flohmärkte
class FleaMarket {
  final int id;
  final String title;
  final DateTime date;
  final DateTime? dateEnd;
  final String city;
  final String plz;
  final String? street;
  final double? lat;
  final double? lng;
  final String? category;
  final String? organizer;
  final String? description;
  final bool entryFee;
  final String? venueType;
  final String? source;

  FleaMarket({
    required this.id,
    required this.title,
    required this.date,
    this.dateEnd,
    required this.city,
    required this.plz,
    this.street,
    this.lat,
    this.lng,
    this.category,
    this.organizer,
    this.description,
    this.entryFee = false,
    this.venueType,
    this.source,
  });

  factory FleaMarket.fromJson(Map<String, dynamic> json) {
    return FleaMarket(
      id: json['id'],
      title: json['title'] ?? '',
      date: DateTime.parse(json['date']),
      dateEnd: json['date_end'] != null ? DateTime.parse(json['date_end']) : null,
      city: json['city'] ?? '',
      plz: json['plz'] ?? '',
      street: json['street'],
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      category: json['category'],
      organizer: json['organizer'],
      description: json['description'],
      entryFee: json['entry_fee'] ?? false,
      venueType: json['venue_type'],
      source: json['source'],
    );
  }

  String get address => street != null ? '$street, $plz $city' : '$plz $city';

  String get dateFormatted {
    final months = [
      'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'
    ];
    final days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return '${days[date.weekday - 1]}, ${date.day}. ${months[date.month - 1]} ${date.year}';
  }
}

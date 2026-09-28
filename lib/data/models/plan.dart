class Plan {
  final String id;
  final String name;
  final int daysPerWeek;
  final int price;
  final bool active;

  Plan({required this.id, required this.name, required this.daysPerWeek, required this.price, required this.active});

  factory Plan.fromJson(Map<String, dynamic> json) =>
      Plan(id: json['id'] as String, name: json['name'] as String, daysPerWeek: json['days_per_week'] as int, price: (json['price'] as num).toInt(), active: json['active'] as bool);

  Map<String, dynamic> toInsertJson() => {'name': name, 'days_per_week': daysPerWeek, 'price': price, 'active': active};
}

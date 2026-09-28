class Member {
  final String id;
  final String fullName;
  final String? dni;
  final String? phone;
  final String? email;
  final String? imei;
  final String? photoUrl;
  final DateTime joinDate;
  final bool frozen;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Member({
    required this.id,
    required this.fullName,
    this.dni,
    this.phone,
    this.email,
    this.imei,
    this.photoUrl,
    required this.joinDate,
    required this.frozen,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    dni: json['dni'] as String?,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    imei: json['imei'] as String?,
    photoUrl: json['photo_url'] as String?,
    joinDate: DateTime.parse(json['join_date'] as String),
    frozen: json['frozen'] as bool,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    deletedAt: json['deleted_at'] == null ? null : DateTime.parse(json['deleted_at'] as String),
  );

  Map<String, dynamic> toInsertJson() => {
    'full_name': fullName,
    'dni': dni,
    'phone': phone,
    'email': email,
    'imei': imei,
    'photo_url': photoUrl,
    'join_date': joinDate.toIso8601String().substring(0, 10),
    'frozen': frozen,
    'notes': notes,
  };

  Member copyWith({String? fullName, String? dni, String? phone, String? email, String? imei, String? photoUrl, DateTime? joinDate, bool? frozen, String? notes}) => Member(
    id: id,
    fullName: fullName ?? this.fullName,
    dni: dni ?? this.dni,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    imei: imei ?? this.imei,
    photoUrl: photoUrl ?? this.photoUrl,
    joinDate: joinDate ?? this.joinDate,
    frozen: frozen ?? this.frozen,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

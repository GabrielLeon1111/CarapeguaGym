/// Cómo se vende un producto.
/// - servicio: se vende por porción (scoop). Un "pote" trae [servingsPerUnit].
/// - unidad: se vende entero (bebidas, guantes, etc.).
enum StockUnitType {
  servicio,
  unidad;

  static StockUnitType fromDb(String v) => v == 'servicio' ? StockUnitType.servicio : StockUnitType.unidad;
  String get db => this == StockUnitType.servicio ? 'servicio' : 'unidad';
  String get label => this == StockUnitType.servicio ? 'Por servicio (scoop)' : 'Por unidad';
}

class StockProduct {
  final String id;
  final String name;
  final String category;
  final StockUnitType unitType;

  /// Scoops por pote (para 'servicio'); 1 para 'unidad'.
  final int servingsPerUnit;

  /// Precio de venta por unidad base (por servicio o por unidad).
  final int salePrice;
  final int lowStockThreshold;

  /// Stock actual en unidades base (servicios o unidades).
  final int stockQty;

  /// Costo promedio ponderado por unidad base.
  final int avgCost;

  final bool expires;
  final DateTime? expiration;
  final bool active;

  /// Capital invertido en este producto: sube con las compras, no baja al
  /// vender y se resetea a 0 cuando el producto queda sin stock.
  final int investedCapital;

  StockProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.unitType,
    required this.servingsPerUnit,
    required this.salePrice,
    required this.lowStockThreshold,
    required this.stockQty,
    required this.avgCost,
    required this.expires,
    this.expiration,
    required this.active,
    this.investedCapital = 0,
  });

  bool get isService => unitType == StockUnitType.servicio;
  bool get isOutOfStock => stockQty <= 0;
  bool get isLowStock => stockQty > 0 && stockQty <= lowStockThreshold;
  int get stockValue => stockQty * avgCost;
  String get unitLabel => isService ? 'servicios' : 'unidades';
  String get unitLabelSingular => isService ? 'servicio' : 'unidad';

  factory StockProduct.fromJson(Map<String, dynamic> json) => StockProduct(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    unitType: StockUnitType.fromDb(json['unit_type'] as String),
    servingsPerUnit: json['servings_per_unit'] as int,
    salePrice: (json['sale_price_per_serving'] as num).toInt(),
    lowStockThreshold: json['low_stock_threshold'] as int,
    stockQty: (json['stock_qty'] as num).toInt(),
    avgCost: (json['avg_cost'] as num).toInt(),
    expires: json['expires'] as bool,
    expiration: json['expiration'] == null ? null : DateTime.parse(json['expiration'] as String),
    active: json['active'] as bool,
    investedCapital: json['invested_capital'] == null ? 0 : (json['invested_capital'] as num).toInt(),
  );

  /// Solo los campos de definición (el stock y el costo los manejan los movimientos).
  Map<String, dynamic> toDefinitionJson() => {
    'name': name,
    'category': category,
    'unit_type': unitType.db,
    'servings_per_unit': servingsPerUnit,
    'sale_price_per_serving': salePrice,
    'low_stock_threshold': lowStockThreshold,
    'expires': expires,
    'active': active,
  };
}

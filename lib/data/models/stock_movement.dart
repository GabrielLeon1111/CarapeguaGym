import 'payment_method.dart';

enum StockMoveType {
  entrada,
  salida,
  averiado,
  devolucion,
  ajuste;

  static StockMoveType fromDb(String v) => switch (v) {
    'entrada' => StockMoveType.entrada,
    'salida' => StockMoveType.salida,
    'averiado' => StockMoveType.averiado,
    'devolucion' => StockMoveType.devolucion,
    _ => StockMoveType.ajuste,
  };

  String get label => switch (this) {
    StockMoveType.entrada => 'Compra',
    StockMoveType.salida => 'Venta',
    StockMoveType.averiado => 'Averiado',
    StockMoveType.devolucion => 'Devolución',
    StockMoveType.ajuste => 'Ajuste',
  };

  /// true si suma stock (entrada/devolución), false si resta.
  bool get isIncoming => this == StockMoveType.entrada || this == StockMoveType.devolucion;
}

class StockMovement {
  final String id;
  final String productId;
  final String productName;
  final DateTime createdAt;
  final StockMoveType tipo;
  final int qty;
  final int? unitCost;
  final int? salePrice;
  final int? costOfGoods;
  final int stockBefore;
  final int stockAfter;
  final int avgBefore;
  final int avgAfter;
  final DateTime? expiration;
  final String? note;
  final PaymentMethod? paymentMethod;
  final String? memberId;
  final String? customerName;
  final DateTime? voidedAt;

  StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.createdAt,
    required this.tipo,
    required this.qty,
    this.unitCost,
    this.salePrice,
    this.costOfGoods,
    required this.stockBefore,
    required this.stockAfter,
    required this.avgBefore,
    required this.avgAfter,
    this.expiration,
    this.note,
    this.paymentMethod,
    this.memberId,
    this.customerName,
    this.voidedAt,
  });

  bool get isVoided => voidedAt != null;
  int? get total => salePrice == null ? null : qty * salePrice!;
  int? get profit => (salePrice == null || costOfGoods == null) ? null : (qty * salePrice!) - costOfGoods!;
  bool get hasClient => memberId != null || (customerName != null && customerName!.trim().isNotEmpty);

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    final prod = json['stock_products'];
    return StockMovement(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: prod is Map ? (prod['name'] as String? ?? '—') : '—',
      createdAt: DateTime.parse(json['created_at'] as String),
      tipo: StockMoveType.fromDb(json['tipo'] as String),
      qty: json['qty'] as int,
      unitCost: json['unit_cost'] == null ? null : (json['unit_cost'] as num).toInt(),
      salePrice: json['sale_price'] == null ? null : (json['sale_price'] as num).toInt(),
      costOfGoods: json['cost_of_goods'] == null ? null : (json['cost_of_goods'] as num).toInt(),
      stockBefore: json['stock_before'] as int,
      stockAfter: json['stock_after'] as int,
      avgBefore: (json['avg_before'] as num).toInt(),
      avgAfter: (json['avg_after'] as num).toInt(),
      expiration: json['expiration'] == null ? null : DateTime.parse(json['expiration'] as String),
      note: json['note'] as String?,
      paymentMethod: json['payment_method'] == null ? null : PaymentMethod.fromDb(json['payment_method'] as String),
      memberId: json['member_id'] as String?,
      customerName: json['customer_name'] as String?,
      voidedAt: json['voided_at'] == null ? null : DateTime.parse(json['voided_at'] as String),
    );
  }
}

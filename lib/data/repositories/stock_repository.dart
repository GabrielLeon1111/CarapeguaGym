import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../models/payment_method.dart';
import '../models/stock_movement.dart';
import '../models/stock_product.dart';

class StockSalesSummary {
  final String productName;
  final int units;
  final int revenue;
  final int cost;
  final int profit;

  const StockSalesSummary({required this.productName, required this.units, required this.revenue, required this.cost, required this.profit});
}

class StockRepository {
  Future<List<StockProduct>> getProducts({bool activeOnly = false}) async {
    final query = supa.from('stock_products').select();
    final rows = activeOnly ? await query.eq('active', true).order('name') : await query.order('name');
    return (rows as List).map((e) => StockProduct.fromJson(e)).toList();
  }

  Future<StockProduct> createProduct(StockProduct product, {String? opId}) async {
    final json = product.toDefinitionJson();
    if (opId != null) json['op_id'] = opId;
    try {
      final row = await supa.from('stock_products').insert(json).select().single();
      return StockProduct.fromJson(row);
    } on PostgrestException catch (e) {
      // Reintento con la misma clave: el producto ya se había creado. Se
      // devuelve el existente en vez de duplicarlo.
      if (e.code == '23505' && opId != null) {
        final row = await supa.from('stock_products').select().eq('op_id', opId).single();
        return StockProduct.fromJson(row);
      }
      rethrow;
    }
  }

  Future<StockProduct> updateProduct(String id, StockProduct product) async {
    final row = await supa.from('stock_products').update(product.toDefinitionJson()).eq('id', id).select().single();
    return StockProduct.fromJson(row);
  }

  /// Categorías ya usadas (para el selector + opción de crear una nueva).
  Future<List<String>> getCategories() async {
    final rows = await supa.from('stock_products').select('category');
    final set = <String>{for (final r in rows as List) (r['category'] as String).trim()}..removeWhere((e) => e.isEmpty);
    final list = set.toList()..sort();
    return list;
  }

  /// Registra un movimiento (entrada/salida/averiado) de forma atómica en la
  /// base: recalcula stock, costo ponderado y vencimiento. Devuelve un mensaje
  /// de error de la base si lo hubo (por ejemplo, sin stock), o null si salió bien.
  Future<void> recordMovement({
    required String productId,
    required StockMoveType tipo,
    required int qty,
    int? unitCost,
    int? salePrice,
    DateTime? expiration,
    String? note,
    PaymentMethod? paymentMethod,
    String? memberId,
    String? customerName,
    String? opId,
  }) async {
    await supa.rpc(
      'record_stock_movement',
      params: {
        'p_product_id': productId,
        'p_tipo': tipo.name,
        'p_qty': qty,
        'p_unit_cost': unitCost,
        'p_sale_price': salePrice,
        'p_expiration': expiration?.toIso8601String().substring(0, 10),
        'p_note': note,
        'p_payment_method': paymentMethod?.name,
        'p_member_id': memberId,
        'p_customer_name': customerName,
        'p_op_id': opId,
      },
    );
  }

  /// Anula un movimiento (revierte stock y costo en la base).
  Future<void> voidMovement(String id) async {
    await supa.rpc('void_stock_movement', params: {'p_id': id});
  }

  /// Asocia (o cambia) el cliente de un movimiento ya registrado.
  Future<void> associateClient(String id, {String? memberId, String? customerName}) async {
    await supa.from('stock_movements').update({'member_id': memberId, 'customer_name': customerName}).eq('id', id);
  }

  Future<List<StockMovement>> getMovements({DateTime? from, DateTime? to, String? productId}) async {
    var query = supa.from('stock_movements').select('*, stock_products(name)');
    if (from != null) query = query.gte('created_at', from.toIso8601String());
    if (to != null) query = query.lt('created_at', to.toIso8601String());
    if (productId != null) query = query.eq('product_id', productId);
    final rows = await query.order('created_at', ascending: false).limit(300);
    return (rows as List).map((e) => StockMovement.fromJson(e)).toList();
  }

  /// Resumen de ventas del mes en curso (ingresos, ganancia y unidades).
  Future<({int revenue, int profit, int units})> getMonthSummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final rows = await supa.from('stock_movements').select('qty, sale_price, cost_of_goods').eq('tipo', 'salida').isFilter('voided_at', null).gte('created_at', start.toIso8601String());
    var revenue = 0, profit = 0, units = 0;
    for (final r in rows as List) {
      final qty = r['qty'] as int;
      final price = r['sale_price'] == null ? 0 : (r['sale_price'] as num).toInt();
      final cost = r['cost_of_goods'] == null ? 0 : (r['cost_of_goods'] as num).toInt();
      revenue += qty * price;
      profit += qty * price - cost;
      units += qty;
    }
    return (revenue: revenue, profit: profit, units: units);
  }

  Future<List<StockSalesSummary>> getSalesSummary(DateTime from, DateTime to) async {
    final rows = await supa
        .from('stock_movements')
        .select('qty, sale_price, cost_of_goods, stock_products(name)')
        .eq('tipo', 'salida')
        .isFilter('voided_at', null)
        .gte('created_at', from.toIso8601String())
        .lt('created_at', to.toIso8601String());

    final grouped = <String, ({int units, int revenue, int cost})>{};
    for (final row in rows as List) {
      final product = row['stock_products'];
      final name = product is Map ? (product['name'] as String? ?? 'Producto') : 'Producto';
      final qty = (row['qty'] as num).toInt();
      final salePrice = (row['sale_price'] as num?)?.toInt() ?? 0;
      final cost = (row['cost_of_goods'] as num?)?.toInt() ?? 0;
      final current = grouped[name] ?? (units: 0, revenue: 0, cost: 0);
      grouped[name] = (units: current.units + qty, revenue: current.revenue + qty * salePrice, cost: current.cost + cost);
    }

    return grouped.entries
        .map((entry) => StockSalesSummary(productName: entry.key, units: entry.value.units, revenue: entry.value.revenue, cost: entry.value.cost, profit: entry.value.revenue - entry.value.cost))
        .where((summary) => summary.revenue > 0 || summary.units > 0)
        .toList()
      ..sort((a, b) => b.profit.compareTo(a.profit));
  }
}

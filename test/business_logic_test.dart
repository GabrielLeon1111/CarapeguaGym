import 'package:fitness_gym/core/utils/error_messages.dart';
import 'package:fitness_gym/data/models/membership_period.dart';
import 'package:fitness_gym/data/models/payment_method.dart';
import 'package:fitness_gym/core/utils/ids.dart';
import 'package:fitness_gym/data/repositories/stock_repository.dart';
import 'package:fitness_gym/features/charge/charge_validation.dart';
import 'package:fitness_gym/features/dashboard/dashboard_data.dart';
import 'package:fitness_gym/features/stock/stock_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  final today = DateTime(2026, 9, 23);

  ChargeCheck check({
    bool member = true,
    String search = 'Juan Pérez',
    bool frozen = false,
    bool catalog = false,
    bool plan = false,
    int? listPrice,
    int base = 200000,
    bool trainer = false,
    int trainerPrice = 0,
    DateTime? start,
    DateTime? prevEnd,
  }) => checkCharge(
    memberSelected: member,
    searchText: search,
    memberFrozen: frozen,
    catalogMode: catalog,
    planSelected: plan,
    listPrice: listPrice,
    basePrice: base,
    hasTrainer: trainer,
    trainerPrice: trainerPrice,
    startDate: start ?? today,
    previousEndDate: prevEnd,
    today: today,
  );

  group('Cobro: errores que bloquean', () {
    test('cobro correcto pasa sin errores ni advertencias', () {
      final c = check();
      expect(c.ok, isTrue);
      expect(c.warnings, isEmpty);
    });
    test('sin socio y sin texto', () {
      expect(check(member: false, search: '').errors.single, contains('Falta elegir el socio'));
    });
    test('escribió el nombre pero no tocó el resultado', () {
      expect(check(member: false, search: 'Juan').errors.single, contains('no elegiste a nadie'));
    });
    test('modo catálogo sin plan', () {
      expect(check(catalog: true).errors.single, contains('no seleccionaste ningún plan'));
    });
    test('precio vacío o gigante', () {
      expect(check(base: 0).errors.single, contains('mayor a 0'));
      expect(check(base: 999999999).errors.single, contains('ceros de más'));
    });
    test('entrenador activado sin costo', () {
      expect(check(trainer: true, trainerPrice: 0).errors.single, contains('entrenador de piso'));
    });
    test('fecha con año equivocado', () {
      expect(check(start: DateTime(2025, 1, 1)).errors.single, contains('más de un año'));
    });
    test('junta todos los errores a la vez', () {
      expect(check(member: false, catalog: true, base: 0, trainer: true).errors.length, 4);
    });
  });

  group('Cobro: advertencias que piden confirmación', () {
    test('período superpuesto con uno ya pago', () {
      final c = check(prevEnd: DateTime(2026, 10, 5));
      expect(c.ok, isTrue);
      expect(c.warnings.single, contains('YA TIENE PAGO hasta el 05/10/2026'));
    });
    test('precio sospechosamente bajo (faltan ceros)', () {
      expect(check(base: 2000).warnings.single, contains('faltaron ceros'));
    });
    test('más caro que el precio de lista', () {
      expect(check(catalog: true, plan: true, listPrice: 150000, base: 200000).warnings.single, contains('más que el precio de lista'));
    });
    test('socio congelado', () {
      expect(check(frozen: true).warnings.single, contains('CONGELADO'));
    });
    test('fecha lejana', () {
      expect(check(start: DateTime(2026, 7, 1)).warnings.single, contains('hace más de un mes'));
      expect(check(start: DateTime(2026, 12, 1)).warnings.single, contains('dentro de más de un mes'));
    });
  });

  group('Fecha de inicio sugerida', () {
    test('si todavía tiene días pagos, arranca al vencimiento', () {
      expect(suggestedStartDate(DateTime(2026, 10, 5), today), DateTime(2026, 10, 5));
    });
    test('si ya venció o nunca pagó, arranca hoy', () {
      expect(suggestedStartDate(DateTime(2026, 8, 1), today), today);
      expect(suggestedStartDate(null, today), today);
    });
  });

  group('Clave de operación (idempotencia)', () {
    test('genera UUID v4 con formato válido y único', () {
      final a = newOpId();
      final b = newOpId();
      expect(a, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(a, isNot(b));
    });
  });

  group('Dashboard: ganancia por productos', () {
    test('lleva el resumen de ventas de productos y su ganancia', () {
      final data = DashboardData.compute(
        const [],
        DateTime(2026, 9, 23, 12),
        productSales: const [
          StockSalesSummary(productName: 'Whey', units: 3, revenue: 60000, cost: 30000, profit: 30000),
          StockSalesSummary(productName: 'Agua', units: 2, revenue: 16000, cost: 10000, profit: 6000),
        ],
      );
      expect(data.productSales.length, 2);
      final totalProfit = data.productSales.fold<int>(0, (a, s) => a + s.profit);
      final totalRevenue = data.productSales.fold<int>(0, (a, s) => a + s.revenue);
      expect(totalProfit, 36000);
      expect(totalRevenue, 76000);
    });
  });

  group('Inventario: costo promedio ponderado', () {
    test('primera compra fija el promedio', () {
      expect(weightedAverage(stockBefore: 0, avgBefore: 0, qtyAdded: 6, unitCost: 5000), 5000);
    });
    test('segunda compra promedia ponderado (caso pack de aguas)', () {
      // 6 @5000 luego 6 @6000 → (30000+36000)/12 = 5500.
      expect(weightedAverage(stockBefore: 6, avgBefore: 5000, qtyAdded: 6, unitCost: 6000), 5500);
    });
    test('pondera por cantidad, no por partes iguales', () {
      // 10 @1000 + 2 @5000 → (10000+10000)/12 = 1667 (redondeado).
      expect(weightedAverage(stockBefore: 10, avgBefore: 1000, qtyAdded: 2, unitCost: 5000), 1667);
    });
    test('costo por unidad a partir del pack', () {
      expect(perUnitCost(packCost: 30000, unitsPerPack: 6), 5000);
      expect(perUnitCost(packCost: 90000, unitsPerPack: 30), 3000);
      expect(perUnitCost(packCost: 10000, unitsPerPack: 3), 3333);
      expect(perUnitCost(packCost: 10000, unitsPerPack: 0), 0);
    });
  });

  group('Dashboard', () {
    MembershipPeriod p(DateTime created, {int base = 100000, int trainer = 0, String? planId, int? list}) => MembershipPeriod(
      id: 'x',
      memberId: 'm',
      planId: planId,
      daysPerWeek: 3,
      basePrice: base,
      listPrice: list,
      hasTrainer: trainer > 0,
      trainerPrice: trainer,
      totalAmount: base + trainer,
      paymentMethod: PaymentMethod.efectivo,
      startDate: created,
      endDate: created,
      createdAt: created,
    );

    test('"Sin entrenador" = cuotas, no cuotas menos entrenador (antes daba negativo)', () {
      final now = DateTime(2026, 9, 23, 12);
      final data = DashboardData.compute([p(now, base: 50000, trainer: 80000)], now);
      expect(data.trainerTotal, 80000);
      expect(data.nonTrainerTotal, 50000);
      expect(data.monthTotal, 130000);
    });
    test('totales por período y descuentos', () {
      final now = DateTime(2026, 9, 23, 12);
      final data = DashboardData.compute([p(now, planId: 'plan', list: 120000), p(DateTime(2026, 9, 2)), p(DateTime(2026, 8, 15))], now);
      expect(data.todayTotal, 100000);
      expect(data.monthTotal, 200000);
      expect(data.previousMonthTotal, 100000);
      expect(data.discountTotal, 20000);
      expect(data.catalogTotal, 100000);
      expect(data.customTotal, 100000);
      expect(data.monthChangePct, 100);
      expect(data.monthlySeries.length, 12);
    });
  });

  group('Mensajes de error amigables (no filtran detalles técnicos)', () {
    test('credenciales inválidas', () {
      expect(friendlyAuthError(const AuthException('Invalid login credentials', code: 'invalid_credentials')), contains('incorrectos'));
    });
    test('demasiados intentos', () {
      expect(friendlyAuthError(const AuthException('Too many', statusCode: '429')), contains('Demasiados intentos'));
    });
    test('DNI duplicado', () {
      expect(friendlyError(const PostgrestException(message: 'duplicate key value violates unique constraint "members_dni_key"', code: '23505')), contains('DNI'));
    });
    test('sesión expirada', () {
      expect(friendlyError(const PostgrestException(message: 'JWT expired', code: 'PGRST301')), contains('sesión expiró'));
    });
    test('error desconocido no muestra el texto técnico', () {
      final msg = friendlyError(
        const PostgrestException(message: 'relation "public.secret_table" does not exist', code: '42P01'),
        action: 'guardar el plan',
      );
      expect(msg, isNot(contains('secret_table')));
      expect(msg, contains('guardar el plan'));
    });
  });
}

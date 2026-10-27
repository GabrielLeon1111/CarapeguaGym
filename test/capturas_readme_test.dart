// Capturas de pantalla para el README, con datos de ejemplo (nada real).
// No usa Supabase: cada pantalla recibe socios, cobros y productos inventados.
//
//   CAPTURAS_DIR=docs/capturas flutter test test/capturas_readme_test.dart
//
// Sin CAPTURAS_DIR la prueba solo arma las pantallas (sirve para ver que no se rompen).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitness_gym/core/theme/app_theme.dart';
import 'package:fitness_gym/data/models/member_status.dart';
import 'package:fitness_gym/data/models/stock_product.dart';
import 'package:fitness_gym/data/repositories/member_repository.dart';
import 'package:fitness_gym/data/repositories/stock_repository.dart';
import 'package:fitness_gym/features/dashboard/dashboard_data.dart';
import 'package:fitness_gym/features/dashboard/dashboard_screen.dart';
import 'package:fitness_gym/features/members/members_screen.dart';
import 'package:fitness_gym/features/renewals/renewals_screen.dart';
import 'package:fitness_gym/features/stock/inventory_screen.dart';
import 'package:fitness_gym/providers/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final _hoy = DateTime.now();
DateTime _dia(int dias) => DateTime(_hoy.year, _hoy.month, _hoy.day).add(Duration(days: dias));

MemberStatus _socio(String id, String nombre, MemberStatusKind estado, int venceEn, {bool entrenador = false, int monto = 150000}) => MemberStatus(
      memberId: id,
      fullName: nombre,
      phone: '0981 000 000',
      frozen: estado == MemberStatusKind.congelado,
      latestPeriodId: 'per-$id',
      endDate: _dia(venceEn),
      daysPerWeek: 3,
      hasTrainer: entrenador,
      latestAmount: monto,
      daysOverdue: venceEn < 0 ? -venceEn : null,
      status: estado,
    );

final _socios = [
  _socio('s1', 'Ana Giménez', MemberStatusKind.activo, 3),
  _socio('s2', 'Carlos Benítez', MemberStatusKind.activo, 12, entrenador: true, monto: 230000),
  _socio('s3', 'Laura Ortiz', MemberStatusKind.vencido, -2),
  _socio('s4', 'Diego Ramírez', MemberStatusKind.activo, 25),
  _socio('s5', 'Sofía Martínez', MemberStatusKind.activo, 6),
  _socio('s6', 'Mateo Fernández', MemberStatusKind.congelado, 40),
  _socio('s7', 'Valentina Cáceres', MemberStatusKind.vencido, -9),
  _socio('s8', 'Lucas Duarte', MemberStatusKind.activo, 18, entrenador: true, monto: 230000),
];

StockProduct _producto(String id, String nombre, String cat, int precio, int stock, int costo, {bool porcion = false, int min = 5}) => StockProduct(
      id: id,
      name: nombre,
      category: cat,
      unitType: porcion ? StockUnitType.servicio : StockUnitType.unidad,
      servingsPerUnit: porcion ? 30 : 1,
      salePrice: precio,
      lowStockThreshold: min,
      stockQty: stock,
      avgCost: costo,
      expires: false,
      active: true,
      investedCapital: stock * costo,
    );

final _productos = [
  _producto('p1', 'Proteína Whey 2 lb', 'Suplementos', 8000, 54, 4200, porcion: true, min: 15),
  _producto('p2', 'Creatina 300 g', 'Suplementos', 5000, 12, 2600, porcion: true, min: 15),
  _producto('p3', 'Bebida isotónica 500 ml', 'Bebidas', 10000, 24, 6500),
  _producto('p4', 'Agua mineral 500 ml', 'Bebidas', 5000, 3, 2800),
  _producto('p5', 'Guantes de entrenamiento', 'Accesorios', 85000, 4, 52000, min: 2),
  _producto('p6', 'Barra de proteína', 'Snacks', 12000, 0, 7000),
];

class _Socios extends MemberRepository {
  @override
  Future<List<MemberStatus>> getStatuses() async => _socios;
}

class _Stock extends StockRepository {
  @override
  Future<List<StockProduct>> getProducts({bool activeOnly = false}) async => _productos;

  @override
  Future<List<String>> getCategories() async => {for (final p in _productos) p.category}.toList()..sort();

  @override
  Future<({int revenue, int profit, int units})> getMonthSummary() async => (revenue: 1840000, profit: 690000, units: 214);
}

final _panel = DashboardData(
  todayTotal: 610000,
  weekTotal: 2150000,
  monthTotal: 6420000,
  yearTotal: 58300000,
  previousMonthTotal: 5870000,
  catalogTotal: 5180000,
  customTotal: 620000,
  trainerTotal: 840000,
  nonTrainerTotal: 5800000,
  discountTotal: 220000,
  monthlySeries: [for (var i = 11; i >= 0; i--) MonthPoint(DateTime(_hoy.year, _hoy.month - i), 3900000 + ((11 - i) * 230000) + (i % 3) * 180000)],
  productSales: const [
    StockSalesSummary(productName: 'Proteína Whey 2 lb', units: 96, revenue: 768000, cost: 403200, profit: 364800),
    StockSalesSummary(productName: 'Bebida isotónica 500 ml', units: 58, revenue: 580000, cost: 377000, profit: 203000),
    StockSalesSummary(productName: 'Creatina 300 g', units: 60, revenue: 300000, cost: 156000, profit: 144000),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final carpeta = Platform.environment['CAPTURAS_DIR'];

  setUpAll(() async {
    await initializeDateFormatting('es');
    final flutter = Platform.environment['FLUTTER_ROOT'] ?? r'C:\src\flutter';
    final fuentes = '$flutter/bin/cache/artifacts/material_fonts';
    Future<void> cargar(String familia, List<String> archivos) async {
      final f = FontLoader(familia);
      for (final a in archivos) {
        f.addFont(Future.value(ByteData.view(File('$fuentes/$a').readAsBytesSync().buffer)));
      }
      await f.load();
    }

    await cargar('Roboto', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf', 'roboto-light.ttf']);
    await cargar('MaterialIcons', ['materialicons-regular.otf']);
  });

  final clave = GlobalKey();

  Future<void> captura(WidgetTester tester, String nombre, Widget pantalla) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        memberRepositoryProvider.overrideWithValue(_Socios()),
        stockRepositoryProvider.overrideWithValue(_Stock()),
        dashboardDataProvider.overrideWith((ref) async => _panel),
        memberStatusesProvider.overrideWith((ref) async => _socios),
        customMemberIdsProvider.overrideWith((ref) async => {'s2', 's8'}),
      ],
      child: RepaintBoundary(
        key: clave,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: pantalla,
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (carpeta != null) {
      await tester.runAsync(() async {
        final boundary = clave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final imagen = await boundary.toImage(pixelRatio: 2);
        final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
        File('$carpeta/$nombre.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets('inicio', (tester) => captura(tester, 'inicio', const DashboardScreen()));
  testWidgets('socios', (tester) => captura(tester, 'socios', const MembersScreen()));
  testWidgets('renovaciones', (tester) => captura(tester, 'renovaciones', const RenewalsScreen()));
  testWidgets('inventario', (tester) => captura(tester, 'inventario', const InventoryScreen()));
}

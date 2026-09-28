// Pruebas del panel "Pase del día": configurar el precio una vez, cobrar en
// un toque, y que los datos del cliente sean opcionales pero validados.
import 'package:fitness_gym/data/models/daily_pass.dart';
import 'package:fitness_gym/data/models/member.dart';
import 'package:fitness_gym/data/models/payment_method.dart';
import 'package:fitness_gym/data/repositories/daily_pass_repository.dart';
import 'package:fitness_gym/data/repositories/member_repository.dart';
import 'package:fitness_gym/features/charge/daily_pass_tab.dart';
import 'package:fitness_gym/features/charge/daily_rate_store.dart';
import 'package:fitness_gym/providers/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class FakeDailyPassRepository extends DailyPassRepository {
  final List<DailyPass> created = [];

  @override
  Future<DailyPass> create(DailyPass pass) async {
    final saved = DailyPass(
      id: 'id-${created.length}',
      firstName: pass.firstName,
      lastName: pass.lastName,
      phone: pass.phone,
      amount: pass.amount,
      paymentMethod: pass.paymentMethod,
      createdAt: DateTime.now(),
    );
    created.add(saved);
    return saved;
  }

  @override
  Future<List<DailyPass>> getByDateRange(DateTime start, DateTime end) async => created.where((p) => !p.createdAt.isBefore(start) && p.createdAt.isBefore(end)).toList();
}

/// Precio del día en memoria (sin tocar SharedPreferences en los tests).
class FakeRateStore extends DailyRateStore {
  int? rate;
  FakeRateStore([this.rate]);

  @override
  Future<int?> get() async => rate;

  @override
  Future<void> set(int amount) async => rate = amount;
}

class FakeMemberRepository extends MemberRepository {
  @override
  Future<List<Member>> search(String term) async => [];
}

Widget _app(FakeDailyPassRepository repo, FakeRateStore store) => ProviderScope(
  overrides: [dailyPassRepositoryProvider.overrideWithValue(repo), dailyRateStoreProvider.overrideWithValue(store), memberRepositoryProvider.overrideWithValue(FakeMemberRepository())],
  child: const MaterialApp(home: Scaffold(body: DailyPassTab())),
);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  setUp(() {
    final b = TestWidgetsFlutterBinding.ensureInitialized();
    b.platformDispatcher.views.first.physicalSize = const Size(1080, 4200);
    b.platformDispatcher.views.first.devicePixelRatio = 2.0;
  });
  tearDown(() => TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first.resetPhysicalSize());

  group('Modelo DailyPass', () {
    test('nombre mostrado combina nombre y apellido, o "Sin nombre"', () {
      expect(DailyPass(id: '1', firstName: 'Ana', lastName: 'Gómez', amount: 20000, paymentMethod: PaymentMethod.efectivo, createdAt: DateTime.now()).displayName, 'Ana Gómez');
      expect(DailyPass(id: '1', firstName: 'Ana', amount: 20000, paymentMethod: PaymentMethod.efectivo, createdAt: DateTime.now()).displayName, 'Ana');
      expect(DailyPass(id: '1', amount: 20000, paymentMethod: PaymentMethod.efectivo, createdAt: DateTime.now()).displayName, 'Sin nombre');
    });
    test('el JSON de inserción no manda id ni fecha (los pone la base)', () {
      final json = DailyPass(id: 'x', amount: 20000, paymentMethod: PaymentMethod.qr, createdAt: DateTime.now()).toInsertJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
      expect(json['payment_method'], 'qr');
    });
  });

  group('Panel Pase del día', () {
    testWidgets('la primera vez pide configurar el precio', (tester) async {
      await tester.pumpWidget(_app(FakeDailyPassRepository(), FakeRateStore()));
      await tester.pumpAndSettle();
      expect(find.text('Configurá el precio del pase del día'), findsOneWidget);
      expect(find.byKey(const Key('daily_charge')), findsNothing);
    });

    testWidgets('configurar precio inválido avisa y no guarda', (tester) async {
      final store = FakeRateStore();
      await tester.pumpWidget(_app(FakeDailyPassRepository(), store));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('daily_setup_save')));
      expect(find.textContaining('mayor a 0'), findsOneWidget);
      expect(store.rate, isNull);
    });

    testWidgets('configurar precio válido pasa a la pantalla de cobro', (tester) async {
      final store = FakeRateStore();
      await tester.pumpWidget(_app(FakeDailyPassRepository(), store));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('daily_setup_rate')), '20000');
      await _tap(tester, find.byKey(const Key('daily_setup_save')));
      expect(store.rate, 20000);
      expect(find.byKey(const Key('daily_charge')), findsOneWidget);
    });

    testWidgets('cobro en un toque: sin datos de cliente, confirma y guarda', (tester) async {
      final repo = FakeDailyPassRepository();
      await tester.pumpWidget(_app(repo, FakeRateStore(20000)));
      await tester.pumpAndSettle();

      await _tap(tester, find.byKey(const Key('daily_charge')));
      expect(find.text('Confirmar pase del día'), findsOneWidget);
      expect(find.textContaining('sin datos de cliente'), findsOneWidget);
      await _tap(tester, find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));

      expect(repo.created.single.amount, 20000);
      expect(repo.created.single.firstName, isNull);
      expect(repo.created.single.paymentMethod, PaymentMethod.efectivo);
    });

    testWidgets('datos del cliente opcionales: se guardan cuando se cargan', (tester) async {
      final repo = FakeDailyPassRepository();
      await tester.pumpWidget(_app(repo, FakeRateStore(20000)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('client_name')), 'Ana');
      await tester.enterText(find.byKey(const Key('client_phone')), '0981 123456');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('daily_charge')));
      await _tap(tester, find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));

      expect(repo.created.single.firstName, 'Ana');
      expect(repo.created.single.phone, '0981 123456');
    });

    testWidgets('teléfono mal cargado bloquea el cobro con mensaje claro', (tester) async {
      final repo = FakeDailyPassRepository();
      await tester.pumpWidget(_app(repo, FakeRateStore(20000)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('client_phone')), '123');
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('daily_charge')));

      expect(find.textContaining('Al teléfono le faltan números'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('cobra al precio configurado (sin campo de monto)', (tester) async {
      final repo = FakeDailyPassRepository();
      await tester.pumpWidget(_app(repo, FakeRateStore(25000)));
      await tester.pumpAndSettle();
      // Ya no hay campo editable de monto.
      expect(find.byKey(const Key('daily_amount')), findsNothing);
      await _tap(tester, find.byKey(const Key('daily_charge')));
      await _tap(tester, find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      expect(repo.created.single.amount, 25000);
    });

    testWidgets('el resumen del día suma los pases cobrados', (tester) async {
      final repo = FakeDailyPassRepository();
      await tester.pumpWidget(_app(repo, FakeRateStore(20000)));
      await tester.pumpAndSettle();
      expect(find.text('Todavía no cobraste ningún pase hoy.'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('daily_charge')));
      await _tap(tester, find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));

      expect(repo.created.length, 1);
      expect(find.text('Pases de hoy (1)'), findsOneWidget);
    });
  });
}

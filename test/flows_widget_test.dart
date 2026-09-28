// Pruebas de flujo: simulan a una persona sin experiencia usando los paneles
// y cargando datos mal, y verifican que la app le explique qué hizo mal.
import 'package:fitness_gym/data/models/member.dart';
import 'package:fitness_gym/data/models/membership_period.dart';
import 'package:fitness_gym/data/models/payment_method.dart';
import 'package:fitness_gym/data/models/plan.dart';
import 'package:fitness_gym/data/repositories/member_repository.dart';
import 'package:fitness_gym/data/repositories/period_repository.dart';
import 'package:fitness_gym/data/repositories/plan_repository.dart';
import 'package:fitness_gym/features/charge/charge_form_tab.dart';
import 'package:fitness_gym/features/members/member_form_screen.dart';
import 'package:fitness_gym/providers/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Member _member(String id, String name, {String? dni, bool frozen = false}) =>
    Member(id: id, fullName: name, dni: dni, joinDate: DateTime(2026, 1, 1), frozen: frozen, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1));

class FakeMemberRepository extends MemberRepository {
  final List<Member> members;
  final List<Member> created = [];
  FakeMemberRepository(this.members);

  @override
  Future<List<Member>> search(String term) async => members.where((m) => m.fullName.toLowerCase().contains(term.toLowerCase()) || (m.dni ?? '').contains(term)).toList();

  @override
  Future<Member?> findByDni(String dni, {String? excludeId}) async {
    final hits = members.where((m) => m.dni == dni && m.id != excludeId);
    return hits.isEmpty ? null : hits.first;
  }

  @override
  Future<Member> create(Member member) async {
    final m = _member('new-${created.length}', member.fullName, dni: member.dni);
    created.add(m);
    return m;
  }
}

class FakePeriodRepository extends PeriodRepository {
  final Map<String, MembershipPeriod> latest;
  final List<MembershipPeriod> created = [];
  FakePeriodRepository([this.latest = const {}]);

  @override
  Future<MembershipPeriod?> getLatestForMember(String memberId) async => latest[memberId];

  @override
  Future<MembershipPeriod> create(MembershipPeriod period) async {
    created.add(period);
    return period;
  }
}

class FakePlanRepository extends PlanRepository {
  @override
  Future<List<Plan>> getAll({bool activeOnly = false}) async => [Plan(id: 'p1', name: 'Mensual', daysPerWeek: 3, price: 150000, active: true)];
}

Widget _app(Widget child, {required FakeMemberRepository members, FakePeriodRepository? periods}) => ProviderScope(
  overrides: [
    memberRepositoryProvider.overrideWithValue(members),
    periodRepositoryProvider.overrideWithValue(periods ?? FakePeriodRepository()),
    planRepositoryProvider.overrideWithValue(FakePlanRepository()),
  ],
  child: MaterialApp(home: Scaffold(body: child)),
);

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  // Pantalla alta de teléfono para que todo el formulario quede construido.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1080, 4000);
    binding.platformDispatcher.views.first.devicePixelRatio = 2.0;
  });
  tearDown(() => TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first.resetPhysicalSize());

  group('Panel Socios — formulario', () {
    testWidgets('guardar vacío muestra qué falta y no crea nada', (tester) async {
      final repo = FakeMemberRepository([]);
      await tester.pumpWidget(_app(const MemberFormScreen(), members: repo));
      await _tapVisible(tester, find.byKey(const Key('member_save')));

      expect(find.text('Escribí el nombre completo del socio.'), findsOneWidget);
      expect(find.textContaining('Hay datos con errores'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('datos mal cargados: cada campo explica su error', (tester) async {
      final repo = FakeMemberRepository([]);
      await tester.pumpWidget(_app(const MemberFormScreen(), members: repo));
      await tester.enterText(find.byKey(const Key('member_name')), '12345');
      await tester.enterText(find.byKey(const Key('member_dni')), '12');
      await tester.enterText(find.byKey(const Key('member_phone')), '098');
      await tester.enterText(find.byKey(const Key('member_email')), 'juangmail.com');
      await _tapVisible(tester, find.byKey(const Key('member_save')));

      expect(find.textContaining('¿Pusiste el DNI en el lugar equivocado?'), findsOneWidget);
      expect(find.textContaining('El DNI es muy corto'), findsOneWidget);
      expect(find.textContaining('Al teléfono le faltan números'), findsOneWidget);
      expect(find.textContaining('le falta la "@"'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('DNI repetido: avisa quién lo tiene y no duplica', (tester) async {
      final repo = FakeMemberRepository([_member('1', 'Ana Gómez', dni: '4567890')]);
      await tester.pumpWidget(_app(const MemberFormScreen(), members: repo));
      await tester.enterText(find.byKey(const Key('member_name')), 'Ana Gomez');
      await tester.enterText(find.byKey(const Key('member_dni')), '4.567.890');
      await _tapVisible(tester, find.byKey(const Key('member_save')));

      expect(find.textContaining('Ya existe un socio con el DNI 4567890: "Ana Gómez"'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('datos correctos: crea el socio con DNI normalizado', (tester) async {
      final repo = FakeMemberRepository([]);
      await tester.pumpWidget(_app(const MemberFormScreen(), members: repo));
      await tester.enterText(find.byKey(const Key('member_name')), '  Carlos Benítez ');
      await tester.enterText(find.byKey(const Key('member_dni')), '1.234.567');
      await _tapVisible(tester, find.byKey(const Key('member_save')));

      expect(repo.created.single.fullName, 'Carlos Benítez');
      expect(repo.created.single.dni, '1234567');
    });

    testWidgets('si busqué un número en Cobrar, va al DNI y no al nombre', (tester) async {
      await tester.pumpWidget(_app(const MemberFormScreen(prefilledName: '4567890'), members: FakeMemberRepository([])));
      final name = tester.widget<TextFormField>(find.byKey(const Key('member_name')));
      final dni = tester.widget<TextFormField>(find.byKey(const Key('member_dni')));
      expect(name.controller!.text, isEmpty);
      expect(dni.controller!.text, '4567890');
    });
  });

  group('Panel Cobrar', () {
    testWidgets('cobrar sin elegir socio explica qué hacer', (tester) async {
      final periods = FakePeriodRepository();
      await tester.pumpWidget(_app(const ChargeFormTab(), members: FakeMemberRepository([]), periods: periods));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const Key('charge_submit')));

      expect(find.textContaining('Falta elegir el socio'), findsWidgets);
      expect(periods.created, isEmpty);
    });

    testWidgets('escribió el nombre pero no tocó el resultado', (tester) async {
      final periods = FakePeriodRepository();
      await tester.pumpWidget(_app(const ChargeFormTab(), members: FakeMemberRepository([_member('1', 'Juan Pérez')]), periods: periods));
      await tester.enterText(find.byKey(const Key('charge_search')), 'Juan');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const Key('charge_submit')));

      expect(find.textContaining('no elegiste a nadie'), findsWidgets);
      expect(periods.created, isEmpty);
    });

    testWidgets('cambiar el texto después de elegir deselecciona al socio (evita cobrarle a otro)', (tester) async {
      final periods = FakePeriodRepository();
      await tester.pumpWidget(_app(const ChargeFormTab(), members: FakeMemberRepository([_member('1', 'Juan Pérez'), _member('2', 'Juana Díaz')]), periods: periods));
      await tester.enterText(find.byKey(const Key('charge_search')), 'Juan');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juan Pérez'));
      await tester.pumpAndSettle();
      expect(find.text('Socio seleccionado ✓'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('charge_search')), 'Juana');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Socio seleccionado ✓'), findsNothing);
    });

    testWidgets('flujo completo: precarga el último pago, sugiere fecha sin superponer y no guarda si toca "Revisar"', (tester) async {
      final prevEnd = DateTime.now().add(const Duration(days: 5));
      final periods = FakePeriodRepository({
        '1': MembershipPeriod(
          id: 'old',
          memberId: '1',
          daysPerWeek: 3,
          basePrice: 150000,
          hasTrainer: false,
          trainerPrice: 0,
          totalAmount: 150000,
          paymentMethod: PaymentMethod.efectivo,
          startDate: prevEnd.subtract(const Duration(days: 30)),
          endDate: prevEnd,
          createdAt: DateTime.now(),
        ),
      });
      await tester.pumpWidget(_app(const ChargeFormTab(), members: FakeMemberRepository([_member('1', 'Juan Pérez')]), periods: periods));
      await tester.enterText(find.byKey(const Key('charge_search')), 'Juan');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juan Pérez'));
      await tester.pumpAndSettle();

      // Elige el paquete del catálogo (ya no hay modo personalizado).
      await _tapVisible(tester, find.byKey(const Key('charge_plan')));
      await _tapVisible(tester, find.textContaining('Mensual').last);

      // El paquete definió el precio, y la fecha de inicio = vencimiento anterior.
      expect(tester.widget<TextField>(find.byKey(const Key('charge_price'))).controller!.text, '150.000');

      await _tapVisible(tester, find.byKey(const Key('charge_submit')));
      expect(find.text('Confirmar cobro'), findsOneWidget);
      expect(find.textContaining('YA TIENE PAGO'), findsNothing, reason: 'la fecha sugerida no se superpone');

      // Si toca "Revisar" no se guarda nada.
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      expect(periods.created, isEmpty);
    });

    testWidgets('la duración multiplica el precio: 2 meses de 150.000 = 300.000', (tester) async {
      final periods = FakePeriodRepository();
      await tester.pumpWidget(_app(const ChargeFormTab(), members: FakeMemberRepository([_member('1', 'Juan Pérez')]), periods: periods));
      await tester.enterText(find.byKey(const Key('charge_search')), 'Juan');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juan Pérez'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const Key('charge_plan')));
      await _tapVisible(tester, find.textContaining('Mensual').last);
      await tester.enterText(find.byKey(const Key('charge_months')), '2');
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const Key('charge_submit')));
      expect(find.text('Confirmar cobro'), findsOneWidget);
      expect(find.text('Duración: 2 meses'), findsOneWidget);
      // El total del diálogo ya viene multiplicado por los meses.
      expect(find.textContaining('300.000'), findsWidgets);
    });

    testWidgets('entrenador activado sin costo bloquea el cobro', (tester) async {
      final periods = FakePeriodRepository();
      await tester.pumpWidget(_app(const ChargeFormTab(), members: FakeMemberRepository([_member('1', 'Juan Pérez')]), periods: periods));
      await tester.enterText(find.byKey(const Key('charge_search')), 'Juan');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juan Pérez'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const Key('charge_plan')));
      await _tapVisible(tester, find.textContaining('Mensual').last);
      await _tapVisible(tester, find.text('¿Contrata entrenador de piso?'));
      await _tapVisible(tester, find.byKey(const Key('charge_submit')));

      expect(find.textContaining('Activaste "entrenador de piso" pero el costo está vacío'), findsWidgets);
      expect(periods.created, isEmpty);
    });

    testWidgets('cobrar sin elegir paquete avisa que falta el paquete', (tester) async {
      final periods = FakePeriodRepository();
      await tester.pumpWidget(_app(const ChargeFormTab(), members: FakeMemberRepository([_member('1', 'Juan Pérez')]), periods: periods));
      await tester.enterText(find.byKey(const Key('charge_search')), 'Juan');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juan Pérez'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const Key('charge_submit')));

      expect(find.textContaining('no seleccionaste ningún plan'), findsWidgets);
      expect(periods.created, isEmpty);
    });

    testWidgets('paquete preseleccionado (desde Membresías): solo falta el socio', (tester) async {
      final periods = FakePeriodRepository();
      await tester.pumpWidget(
        _app(
          ChargeFormTab(
            preselectedPlan: Plan(id: 'p1', name: 'Mensual', daysPerWeek: 3, price: 150000, active: true),
          ),
          members: FakeMemberRepository([_member('1', 'Juan Pérez')]),
          periods: periods,
        ),
      );
      await tester.pumpAndSettle();

      // El paquete ya viene fijado (no hay selector de plan) y el precio cargado.
      expect(find.byKey(const Key('charge_plan')), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const Key('charge_price'))).controller!.text, '150.000');

      // Sin socio, no deja cobrar.
      await _tapVisible(tester, find.byKey(const Key('charge_submit')));
      expect(find.textContaining('Falta elegir el socio'), findsWidgets);
      expect(periods.created, isEmpty);
    });
  });
}

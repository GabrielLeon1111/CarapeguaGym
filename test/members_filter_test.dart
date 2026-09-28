// Verifica el apartado de socios con membresía personalizada y el campo IMEI.
import 'package:fitness_gym/data/models/member.dart';
import 'package:fitness_gym/data/models/member_status.dart';
import 'package:fitness_gym/data/repositories/member_repository.dart';
import 'package:fitness_gym/data/repositories/period_repository.dart';
import 'package:fitness_gym/features/members/member_form_screen.dart';
import 'package:fitness_gym/features/members/members_screen.dart';
import 'package:fitness_gym/providers/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

MemberStatus _status(String id, String name) => MemberStatus(memberId: id, fullName: name, frozen: false, status: MemberStatusKind.sinPeriodo);

class FakeMemberRepository extends MemberRepository {
  final List<MemberStatus> statuses;
  final List<Member> created = [];
  FakeMemberRepository(this.statuses);

  @override
  Future<List<MemberStatus>> getStatuses() async => statuses;

  @override
  Future<Member?> findByDni(String dni, {String? excludeId}) async => null;

  @override
  Future<Member> create(Member member) async {
    created.add(member);
    return Member(id: 'new', fullName: member.fullName, dni: member.dni, imei: member.imei, joinDate: member.joinDate, frozen: false, createdAt: DateTime.now(), updatedAt: DateTime.now());
  }
}

class FakePeriodRepository extends PeriodRepository {
  final Set<String> customIds;
  FakePeriodRepository(this.customIds);
  @override
  Future<Set<String>> getCustomMemberIds() async => customIds;
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  setUp(() {
    final b = TestWidgetsFlutterBinding.ensureInitialized();
    b.platformDispatcher.views.first.physicalSize = const Size(1080, 3200);
    b.platformDispatcher.views.first.devicePixelRatio = 2.0;
  });
  tearDown(() => TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first.resetPhysicalSize());

  Widget app(FakeMemberRepository members, FakePeriodRepository periods) => ProviderScope(
    overrides: [memberRepositoryProvider.overrideWithValue(members), periodRepositoryProvider.overrideWithValue(periods)],
    child: const MaterialApp(home: MembersScreen()),
  );

  testWidgets('el filtro "Personalizados" muestra solo a quienes tienen período personalizado', (tester) async {
    final members = FakeMemberRepository([_status('1', 'Ana Personalizada'), _status('2', 'Beto Paquete')]);
    final periods = FakePeriodRepository({'1'});
    await tester.pumpWidget(app(members, periods));
    await tester.pumpAndSettle();

    // Por defecto ("Todos") se ven los dos.
    expect(find.text('Ana Personalizada'), findsOneWidget);
    expect(find.text('Beto Paquete'), findsOneWidget);

    await tester.tap(find.text('Personalizados'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Personalizada'), findsOneWidget);
    expect(find.text('Beto Paquete'), findsNothing);
  });

  testWidgets('si no hay personalizados, avisa', (tester) async {
    final members = FakeMemberRepository([_status('1', 'Ana'), _status('2', 'Beto')]);
    await tester.pumpWidget(app(members, FakePeriodRepository({})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personalizados'));
    await tester.pumpAndSettle();
    expect(find.text('No hay socios con membresía personalizada.'), findsOneWidget);
  });

  testWidgets('el formulario acepta IMEI y solo exige el nombre', (tester) async {
    final repo = FakeMemberRepository([]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [memberRepositoryProvider.overrideWithValue(repo), periodRepositoryProvider.overrideWithValue(FakePeriodRepository({}))],
        child: const MaterialApp(home: MemberFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // IMEI inválido (corto) bloquea.
    await tester.enterText(find.byKey(const Key('member_name')), 'Ana Gómez');
    await tester.enterText(find.byKey(const Key('member_imei')), '123');
    await tester.ensureVisible(find.byKey(const Key('member_save')));
    await tester.tap(find.byKey(const Key('member_save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('entre 14 y 17'), findsOneWidget);
    expect(repo.created, isEmpty);

    // IMEI válido (o vacío) permite guardar; cédula/teléfono no son obligatorios.
    await tester.enterText(find.byKey(const Key('member_imei')), '490154203237518');
    await tester.tap(find.byKey(const Key('member_save')));
    await tester.pumpAndSettle();
    expect(repo.created.single.fullName, 'Ana Gómez');
    expect(repo.created.single.imei, '490154203237518');
    expect(repo.created.single.dni, isNull);
    expect(repo.created.single.phone, isNull);
  });
}

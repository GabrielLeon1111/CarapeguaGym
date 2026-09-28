import 'package:fitness_gym/core/utils/thousands_input_formatter.dart';
import 'package:fitness_gym/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('Nombre del socio', () {
    test('acepta nombres normales con tildes y ñ', () {
      expect(Validators.personName('José Núñez'), isNull);
      expect(Validators.personName("María O'Connor-Pérez"), isNull);
    });
    test('rechaza vacío, muy corto, con números o símbolos', () {
      expect(Validators.personName(''), contains('Escribí el nombre'));
      expect(Validators.personName('   '), contains('Escribí el nombre'));
      expect(Validators.personName('Jo'), contains('muy corto'));
      expect(Validators.personName('4567890'), contains('DNI'));
      expect(Validators.personName('Juan <script>'), contains('símbolos'));
      expect(Validators.personName('a' * 101), contains('muy largo'));
    });
  });

  group('DNI', () {
    test('opcional, acepta puntos', () {
      expect(Validators.dni(''), isNull);
      expect(Validators.dni('4.567.890'), isNull);
      expect(Validators.normalizeDni('4.567.890'), '4567890');
      expect(Validators.normalizeDni('  '), isNull);
    });
    test('rechaza letras, cortos o largos', () {
      expect(Validators.dni('45A67'), contains('solo puede tener números'));
      expect(Validators.dni('123'), contains('muy corto'));
      expect(Validators.dni('12345678901'), contains('muy largo'));
    });
  });

  group('Teléfono y WhatsApp', () {
    test('valida teléfonos', () {
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('0981 123 456'), isNull);
      expect(Validators.phone('+595 981 123456'), isNull);
      expect(Validators.phone('0981abc'), contains('solo puede tener números'));
      expect(Validators.phone('123'), contains('faltan números'));
    });
    test('convierte número local paraguayo a formato internacional', () {
      expect(whatsappNumber('0981 123 456'), '595981123456');
      expect(whatsappNumber('+595 981 123456'), '595981123456');
      expect(whatsappNumber('00595981123456'), '595981123456');
      expect(whatsappNumber(''), isNull);
      expect(whatsappNumber('123'), isNull);
    });
  });

  group('IMEI', () {
    test('opcional; válido entre 14 y 17 dígitos', () {
      expect(Validators.imei(''), isNull);
      expect(Validators.imei('  '), isNull);
      expect(Validators.imei('490154203237518'), isNull);
      expect(Validators.imei('35-209900-176148-1'), isNull, reason: 'se ignoran guiones');
    });
    test('rechaza letras o largo incorrecto con mensaje claro', () {
      expect(Validators.imei('12345ABC'), contains('solo puede tener números'));
      expect(Validators.imei('123'), contains('entre 14 y 17'));
      expect(Validators.imei('123456789012345678'), contains('entre 14 y 17'));
    });
  });

  group('Email', () {
    test('válidos e inválidos con mensaje claro', () {
      expect(Validators.email(''), isNull);
      expect(Validators.email('', required: true), isNotNull);
      expect(Validators.email('juan@gmail.com'), isNull);
      expect(Validators.email('juangmail.com'), contains('"@"'));
      expect(Validators.email('juan @gmail.com'), contains('espacios'));
      expect(Validators.email('juan@gmail'), contains('no parece válido'));
    });
  });

  group('Montos y cantidades', () {
    test('monto', () {
      expect(Validators.amount(150000, field: 'el precio'), isNull);
      expect(Validators.amount(0, field: 'el precio'), contains('mayor a 0'));
      expect(Validators.amount(-5, field: 'el precio'), contains('mayor a 0'));
      expect(Validators.amount(Validators.maxAmount + 1, field: 'el precio'), contains('ceros de más'));
    });
    test('enteros en rango', () {
      expect(Validators.intInRange('5', field: 'X', max: 10), isNull);
      expect(Validators.intInRange('', field: 'X', max: 10), contains('Completá'));
      expect(Validators.intInRange('0', field: 'X', max: 10), contains('mínimo'));
      expect(Validators.intInRange('11', field: 'X', max: 10), contains('mayor a 10'));
      expect(Validators.intInRange('1.5', field: 'X', max: 10), contains('entero'));
    });
    test('rango de fechas invertido', () {
      expect(Validators.dateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 31)), isNull);
      expect(Validators.dateRange(DateTime(2026, 1, 1, 10), DateTime(2026, 1, 1, 9)), isNull, reason: 'mismo día es válido');
      expect(Validators.dateRange(DateTime(2026, 2, 1), DateTime(2026, 1, 31)), contains('posterior'));
    });
  });

  group('addMonths', () {
    test('no se pasa al mes siguiente en fin de mes', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(addMonths(DateTime(2026, 3, 31), 1), DateTime(2026, 4, 30));
      expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
      expect(addMonths(DateTime(2026, 5, 10), 12), DateTime(2027, 5, 10));
    });
  });

  group('Seguridad: búsqueda', () {
    test('elimina caracteres que alteran el filtro de PostgREST', () {
      expect(sanitizeSearchTerm('juan,id.neq.0'), 'juan id.neq.0');
      expect(sanitizeSearchTerm('a),or(deleted_at.not.is.null'), 'a or deleted_at.not.is.null');
      expect(sanitizeSearchTerm('100%*'), '100');
      expect(sanitizeSearchTerm('  Pérez  '), 'Pérez');
      expect(sanitizeSearchTerm('x' * 200).length, 60);
    });
  });

  group('ThousandsInputFormatter', () {
    final f = ThousandsInputFormatter();
    TextEditingValue fmt(String old, String now) => f.formatEditUpdate(TextEditingValue(text: old), TextEditingValue(text: now));

    test('formatea con separador de miles', () {
      expect(ThousandsInputFormatter.parse(fmt('', '150000').text), 150000);
    });
    test('no crashea con números gigantes (antes: overflow de int)', () {
      final huge = '9' * 30;
      expect(() => fmt('', huge), returnsNormally);
      expect(fmt('1', huge).text, '1', reason: 'se rechaza el cambio y queda el valor anterior');
      expect(ThousandsInputFormatter.parse(huge), 999999999999);
    });
    test('parse ignora basura', () {
      expect(ThousandsInputFormatter.parse(''), 0);
      expect(ThousandsInputFormatter.parse('Gs. 1.500'), 1500);
    });
  });
}

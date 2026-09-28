import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/membership_period.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

Future<void> exportReportPdf({required DateTime from, required DateTime to, required List<MembershipPeriod> periods}) async {
  final doc = pw.Document();
  final total = periods.fold<int>(0, (a, p) => a + p.totalAmount);

  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Header(text: 'Fitness Gym - Reporte de cobros'),
        pw.Text('Período: ${_dateFmt.format(from)} - ${_dateFmt.format(to)}'),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Fecha', 'Días/sem', 'Entrenador', 'Método', 'Total'],
          data: periods.map((p) => [_dateFmt.format(p.createdAt), '${p.daysPerWeek}', p.hasTrainer ? 'Sí' : 'No', p.paymentMethod.label, formatGs(p.totalAmount)]).toList(),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Total: ${formatGs(total)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: 'reporte_fitness_gym.pdf');
}

Future<void> exportReportExcel({required DateTime from, required DateTime to, required List<MembershipPeriod> periods}) async {
  final workbook = xls.Excel.createExcel();
  final sheet = workbook['Cobros'];
  sheet.appendRow([
    xls.TextCellValue('Fecha'),
    xls.TextCellValue('Días/semana'),
    xls.TextCellValue('Precio base'),
    xls.TextCellValue('Entrenador'),
    xls.TextCellValue('Costo entrenador'),
    xls.TextCellValue('Método de pago'),
    xls.TextCellValue('Total'),
  ]);
  for (final p in periods) {
    sheet.appendRow([
      xls.TextCellValue(_dateFmt.format(p.createdAt)),
      xls.IntCellValue(p.daysPerWeek),
      xls.IntCellValue(p.basePrice),
      xls.TextCellValue(p.hasTrainer ? 'Sí' : 'No'),
      xls.IntCellValue(p.trainerPrice),
      xls.TextCellValue(p.paymentMethod.label),
      xls.IntCellValue(p.totalAmount),
    ]);
  }

  final bytes = workbook.encode();
  if (bytes == null) return;
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/reporte_fitness_gym.xlsx');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Reporte Fitness Gym'));
}

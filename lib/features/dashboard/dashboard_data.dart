import '../../data/models/membership_period.dart';
import '../../data/repositories/stock_repository.dart';

class MonthPoint {
  final DateTime month;
  final int total;
  MonthPoint(this.month, this.total);
}

class DashboardData {
  final int todayTotal;
  final int weekTotal;
  final int monthTotal;
  final int yearTotal;
  final int previousMonthTotal;
  final int catalogTotal;
  final int customTotal;
  final int trainerTotal;
  final int nonTrainerTotal;
  final int discountTotal;
  final List<MonthPoint> monthlySeries;
  final List<StockSalesSummary> productSales;

  DashboardData({
    required this.todayTotal,
    required this.weekTotal,
    required this.monthTotal,
    required this.yearTotal,
    required this.previousMonthTotal,
    required this.catalogTotal,
    required this.customTotal,
    required this.trainerTotal,
    required this.nonTrainerTotal,
    required this.discountTotal,
    required this.monthlySeries,
    required this.productSales,
  });

  double? get monthChangePct {
    if (previousMonthTotal <= 0) return null;
    return ((monthTotal - previousMonthTotal) / previousMonthTotal) * 100;
  }

  static DashboardData compute(List<MembershipPeriod> periods, DateTime now, {List<StockSalesSummary> productSales = const []}) {
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfPrevMonth = DateTime(now.year, now.month - 1, 1);
    final startOfYear = DateTime(now.year, 1, 1);

    int todayTotal = 0, weekTotal = 0, monthTotal = 0, yearTotal = 0, prevMonthTotal = 0;
    int catalogTotal = 0, customTotal = 0, trainerTotal = 0, nonTrainerTotal = 0, discountTotal = 0;
    final monthTotals = <String, int>{};

    for (final p in periods) {
      final d = p.createdAt;
      final dDay = DateTime(d.year, d.month, d.day);
      if (!dDay.isBefore(today)) todayTotal += p.totalAmount;
      if (!dDay.isBefore(startOfWeek)) weekTotal += p.totalAmount;
      if (!d.isBefore(startOfMonth)) {
        monthTotal += p.totalAmount;
        if (p.planId == null) {
          customTotal += p.basePrice;
        } else {
          catalogTotal += p.basePrice;
        }
        if (p.hasTrainer) {
          trainerTotal += p.trainerPrice;
        }
        nonTrainerTotal += p.basePrice;
        discountTotal += p.discountAmount;
      }
      if (!d.isBefore(startOfPrevMonth) && d.isBefore(startOfMonth)) prevMonthTotal += p.totalAmount;
      if (!d.isBefore(startOfYear)) yearTotal += p.totalAmount;

      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      monthTotals[key] = (monthTotals[key] ?? 0) + p.totalAmount;
    }

    final series = <MonthPoint>[];
    for (int i = 11; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      series.add(MonthPoint(m, monthTotals[key] ?? 0));
    }

    return DashboardData(
      todayTotal: todayTotal,
      weekTotal: weekTotal,
      monthTotal: monthTotal,
      yearTotal: yearTotal,
      previousMonthTotal: prevMonthTotal,
      catalogTotal: catalogTotal,
      customTotal: customTotal,
      trainerTotal: trainerTotal,
      nonTrainerTotal: nonTrainerTotal,
      discountTotal: discountTotal,
      monthlySeries: series,
      productSales: productSales,
    );
  }
}

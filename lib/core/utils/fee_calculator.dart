import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class FeeBreakdown {
  final double exchangeRate;
  final double invoiceValueUsd;
  final double invoiceValueYer;
  final List<FeeItem> relativeFees;
  final List<FeeItem> fixedFees;
  final double totalRelativeFees;
  final double totalFixedFees;
  final double grandTotal;

  const FeeBreakdown({
    required this.exchangeRate,
    required this.invoiceValueUsd,
    required this.invoiceValueYer,
    required this.relativeFees,
    required this.fixedFees,
    required this.totalRelativeFees,
    required this.totalFixedFees,
    required this.grandTotal,
  });

  Map<String, dynamic> toJson() {
    return {
      'exchangeRate': exchangeRate,
      'invoiceValueUsd': invoiceValueUsd,
      'invoiceValueYer': invoiceValueYer,
      'relativeFees': relativeFees.map((f) => f.toJson()).toList(),
      'fixedFees': fixedFees.map((f) => f.toJson()).toList(),
      'totalRelativeFees': totalRelativeFees,
      'totalFixedFees': totalFixedFees,
      'grandTotal': grandTotal,
    };
  }

  factory FeeBreakdown.fromJson(Map<String, dynamic> json) {
    return FeeBreakdown(
      exchangeRate: (json['exchangeRate'] ?? 0).toDouble(),
      invoiceValueUsd: (json['invoiceValueUsd'] ?? 0).toDouble(),
      invoiceValueYer: (json['invoiceValueYer'] ?? 0).toDouble(),
      relativeFees: (json['relativeFees'] as List?)?.map((f) => FeeItem.fromJson(f)).toList() ?? [],
      fixedFees: (json['fixedFees'] as List?)?.map((f) => FeeItem.fromJson(f)).toList() ?? [],
      totalRelativeFees: (json['totalRelativeFees'] ?? 0).toDouble(),
      totalFixedFees: (json['totalFixedFees'] ?? 0).toDouble(),
      grandTotal: (json['grandTotal'] ?? 0).toDouble(),
    );
  }
}

class FeeItem {
  final String code;
  final String name;
  final double rate;
  final double amount;
  final String? calculationBase;
  final String? hsCodeFilter;

  const FeeItem({
    required this.code,
    required this.name,
    required this.rate,
    required this.amount,
    this.calculationBase,
    this.hsCodeFilter,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'rate': rate,
      'amount': amount,
      'calculationBase': calculationBase,
      'hsCodeFilter': hsCodeFilter,
    };
  }

  factory FeeItem.fromJson(Map<String, dynamic> json) {
    return FeeItem(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      rate: (json['rate'] ?? 0).toDouble(),
      amount: (json['amount'] ?? 0).toDouble(),
      calculationBase: json['calculationBase'],
      hsCodeFilter: json['hsCodeFilter'],
    );
  }
}

class FeeCalculator {
  final Database _database;
  final String? _hsCode;

  FeeCalculator(this._database, {String? hsCode}) : _hsCode = hsCode;

  Future<FeeBreakdown> calculateFees(double invoiceValueUsd, {double? overrideExchangeRate}) async {
    double exchangeRate;

    if (overrideExchangeRate != null && overrideExchangeRate > 0) {
      // استخدام سعر الصرف الذي أدخله المستخدم في الإقرار نفسه، دون إعادة جلبه من الجدول العام
      exchangeRate = overrideExchangeRate;
    } else {
      // لا يوجد سعر محدد للإقرار: نجلب أحدث سعر صرف عام كقيمة افتراضية فقط
      final exchangeRates = await _database.query(
        'exchange_rates',
        where: 'currency_from = ? AND currency_to = ?',
        whereArgs: ['USD', 'YER'],
        orderBy: 'effective_date DESC',
        limit: 1,
      );

      exchangeRate = 1250.0;
      if (exchangeRates.isNotEmpty) {
        exchangeRate = (exchangeRates.first['rate'] as num).toDouble();
      }
    }

    // تحويل قيمة الفاتورة للريال
    final invoiceValueYer = invoiceValueUsd * exchangeRate;

    // جلب الرسوم النسبية المفعلة (مع مراعاة تحديد الصنف إن وُجد)
    String whereClause = 'is_active = 1';
    List<Object?> whereArgs = [];
    if (_hsCode != null && _hsCode.isNotEmpty) {
      whereClause += ' AND (hs_code_filter IS NULL OR hs_code_filter = "" OR hs_code_filter = ?)';
      whereArgs.add(_hsCode);
    }

    final relativeFeesData = await _database.query(
      'relative_fees',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'execution_order ASC',
    );

    // جلب الرسوم الثابتة المفعلة
    final fixedFeesData = await _database.query(
      'fixed_fees',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );

    final List<FeeItem> relativeFees = [];
    double currentBase = invoiceValueYer;
    double totalRelativeFees = 0;

    for (final feeData in relativeFeesData) {
      final rate = (feeData['rate'] as num).toDouble();
      final calculationBase = feeData['calculation_base'] as String?;

      double baseAmount;
      if (calculationBase == 'after_st' || calculationBase == 'after_duty') {
        baseAmount = currentBase;
      } else {
        baseAmount = invoiceValueYer;
      }

      final feeAmount = baseAmount * (rate / 100);

      relativeFees.add(FeeItem(
        code: feeData['code'] as String,
        name: feeData['name'] as String,
        rate: rate,
        amount: feeAmount,
        calculationBase: calculationBase,
        hsCodeFilter: feeData['hs_code_filter'] as String?,
      ));

      currentBase += feeAmount;
      totalRelativeFees += feeAmount;
    }

    final List<FeeItem> fixedFees = [];
    double totalFixedFees = 0;

    for (final feeData in fixedFeesData) {
      final amount = (feeData['amount'] as num).toDouble();

      fixedFees.add(FeeItem(
        code: feeData['code'] as String,
        name: feeData['name'] as String,
        rate: 0,
        amount: amount,
        calculationBase: 'fixed',
        hsCodeFilter: feeData['hs_code_filter'] as String?,
      ));

      totalFixedFees += amount;
    }

    final grandTotal = totalRelativeFees + totalFixedFees;

    return FeeBreakdown(
      exchangeRate: exchangeRate,
      invoiceValueUsd: invoiceValueUsd,
      invoiceValueYer: invoiceValueYer,
      relativeFees: relativeFees,
      fixedFees: fixedFees,
      totalRelativeFees: totalRelativeFees,
      totalFixedFees: totalFixedFees,
      grandTotal: grandTotal,
    );
  }

  Future<void> saveSnapshot(String declarationId, FeeBreakdown breakdown) async {
    final now = DateTime.now().toIso8601String();

    await _database.insert('declaration_snapshots', {
      'id': 'snap-$declarationId-${DateTime.now().millisecondsSinceEpoch}',
      'declaration_id': declarationId,
      'exchange_rate': breakdown.exchangeRate,
      'fees_breakdown': jsonEncode(breakdown.toJson()),
      'total_fees': breakdown.grandTotal,
      'snapshot_date': now,
    });
  }

  /// يحفظ قاعدة رسوم لهذا الصنف (HS Code) لاستخدامها كنموذج مستقبلاً.
  /// يُستدعى عند اعتماد الإقرار لكل صنف من أصنافه.
  Future<void> saveItemFeeRule(String hsCode, String itemName, FeeBreakdown breakdown) async {
    final now = DateTime.now().toIso8601String();

    final existing = await _database.query(
      'item_fee_rules',
      where: 'hs_code = ?',
      whereArgs: [hsCode],
    );

    if (existing.isNotEmpty) {
      await _database.update(
        'item_fee_rules',
        {
          'item_name': itemName,
          'relative_fees_json': jsonEncode(breakdown.relativeFees.map((f) => f.toJson()).toList()),
          'fixed_fees_json': jsonEncode(breakdown.fixedFees.map((f) => f.toJson()).toList()),
          'total_fees': breakdown.grandTotal,
          'last_used_date': now,
          'usage_count': ((existing.first['usage_count'] as int?) ?? 0) + 1,
        },
        where: 'hs_code = ?',
        whereArgs: [hsCode],
      );
    } else {
      await _database.insert('item_fee_rules', {
        'id': 'rule-$hsCode-${DateTime.now().millisecondsSinceEpoch}',
        'hs_code': hsCode,
        'item_name': itemName,
        'relative_fees_json': jsonEncode(breakdown.relativeFees.map((f) => f.toJson()).toList()),
        'fixed_fees_json': jsonEncode(breakdown.fixedFees.map((f) => f.toJson()).toList()),
        'total_fees': breakdown.grandTotal,
        'last_used_date': now,
        'usage_count': 1,
        'created_at': now,
      });
    }
  }
}

import 'package:sqflite/sqflite.dart';
import 'dart:convert';

// ============ نماذج البيانات ============
class HsCodeFeeRule {
  final String id;
  final String hsCodeId;
  final String hsCode;
  final String feeCode;
  final String feeName;
  final String feeType;
  final double rate;
  final double fixedAmount;
  final String calculationBasis;
  final int calculationOrder;
  final bool isActive;

  const HsCodeFeeRule({
    required this.id,
    required this.hsCodeId,
    required this.hsCode,
    required this.feeCode,
    required this.feeName,
    required this.feeType,
    required this.rate,
    required this.fixedAmount,
    required this.calculationBasis,
    required this.calculationOrder,
    required this.isActive,
  });

  factory HsCodeFeeRule.fromMap(Map<String, dynamic> map) {
    return HsCodeFeeRule(
      id: map['id'] as String,
      hsCodeId: map['hs_code_id'] as String,
      hsCode: map['hs_code'] as String,
      feeCode: map['fee_code'] as String,
      feeName: map['fee_name'] as String,
      feeType: map['fee_type'] as String,
      rate: (map['rate'] as num?)?.toDouble() ?? 0,
      fixedAmount: (map['fixed_amount'] as num?)?.toDouble() ?? 0,
      calculationBasis: map['calculation_basis'] as String? ?? 'invoice_value',
      calculationOrder: map['calculation_order'] as int? ?? 99,
      isActive: (map['is_active'] as int?) == 1,
    );
  }
}

class CalculatedFee {
  final String feeCode;
  final String feeName;
  final String feeType;
  final double rate;
  final double fixedAmount;
  final double calculatedAmount;
  final String calculationBasis;
  final int calculationOrder;

  const CalculatedFee({
    required this.feeCode,
    required this.feeName,
    required this.feeType,
    required this.rate,
    required this.fixedAmount,
    required this.calculatedAmount,
    required this.calculationBasis,
    required this.calculationOrder,
  });

  Map<String, dynamic> toJson() => {
    'code': feeCode,
    'name': feeName,
    'type': feeType,
    'rate': rate,
    'fixedAmount': fixedAmount,
    'amount': calculatedAmount,
    'calculationBase': calculationBasis,
    'order': calculationOrder,
  };
}

class ItemFeeResult {
  final String hsCode;
  final String? hsCodeDescription;
  final double itemValueUsd;
  final double exchangeRate;
  final double itemValueYer;
  final List<CalculatedFee> percentageFees;
  final List<CalculatedFee> fixedFees;
  final double totalPercentageFees;
  final double totalFixedFees;
  final double totalFees;

  const ItemFeeResult({
    required this.hsCode,
    this.hsCodeDescription,
    required this.itemValueUsd,
    required this.exchangeRate,
    required this.itemValueYer,
    required this.percentageFees,
    required this.fixedFees,
    required this.totalPercentageFees,
    required this.totalFixedFees,
    required this.totalFees,
  });
}

class DeclarationFeeResult {
  final double exchangeRate;
  final double totalInvoiceUsd;
  final double totalInvoiceYer;
  final List<ItemFeeResult> itemResults;
  final List<CalculatedFee> mergedPercentageFees;
  final List<CalculatedFee> mergedFixedFees;
  final double grandTotalPercentage;
  final double grandTotalFixed;
  final double grandTotal;

  const DeclarationFeeResult({
    required this.exchangeRate,
    required this.totalInvoiceUsd,
    required this.totalInvoiceYer,
    required this.itemResults,
    required this.mergedPercentageFees,
    required this.mergedFixedFees,
    required this.grandTotalPercentage,
    required this.grandTotalFixed,
    required this.grandTotal,
  });
}

// ============ محرك الرسوم ============
class HsCodeFeeEngine {
  final Database _database;

  HsCodeFeeEngine(this._database);

  /// حساب رسوم صنف واحد
  Future<ItemFeeResult> calculateItemFees({
    required String hsCode,
    required double itemValueUsd,
    required double exchangeRate,
  }) async {
    final itemValueYer = itemValueUsd * exchangeRate;

    final rules = await _database.query(
      'hs_code_fee_rules',
      where: 'hs_code = ? AND is_active = 1',
      whereArgs: [hsCode],
      orderBy: 'calculation_order ASC',
    );

    if (rules.isEmpty) {
      return _calculateWithDefaultRules(hsCode, itemValueUsd, exchangeRate, itemValueYer);
    }

    final feeRules = rules.map((r) => HsCodeFeeRule.fromMap(r)).toList();
    final percentageRules = feeRules.where((r) => r.feeType == 'percentage').toList()
      ..sort((a, b) => a.calculationOrder.compareTo(b.calculationOrder));
    final fixedRules = feeRules.where((r) => r.feeType == 'fixed').toList();

    final List<CalculatedFee> percentageFees = [];
    double currentBase = itemValueYer;
    double totalPercentage = 0;

    for (final rule in percentageRules) {
      double baseAmount;
      switch (rule.calculationBasis) {
        case 'after_duty':
        case 'after_st':
          baseAmount = currentBase;
          break;
        default:
          baseAmount = itemValueYer;
      }
      final amount = baseAmount * (rule.rate / 100);
      percentageFees.add(CalculatedFee(
        feeCode: rule.feeCode, feeName: rule.feeName, feeType: 'percentage',
        rate: rule.rate, fixedAmount: 0, calculatedAmount: amount,
        calculationBasis: rule.calculationBasis, calculationOrder: rule.calculationOrder,
      ));
      currentBase += amount;
      totalPercentage += amount;
    }

    final List<CalculatedFee> fixedFees = [];
    double totalFixed = 0;
    for (final rule in fixedRules) {
      fixedFees.add(CalculatedFee(
        feeCode: rule.feeCode, feeName: rule.feeName, feeType: 'fixed',
        rate: 0, fixedAmount: rule.fixedAmount, calculatedAmount: rule.fixedAmount,
        calculationBasis: 'fixed', calculationOrder: rule.calculationOrder,
      ));
      totalFixed += rule.fixedAmount;
    }

    return ItemFeeResult(
      hsCode: hsCode, itemValueUsd: itemValueUsd, exchangeRate: exchangeRate,
      itemValueYer: itemValueYer, percentageFees: percentageFees, fixedFees: fixedFees,
      totalPercentageFees: totalPercentage, totalFixedFees: totalFixed,
      totalFees: totalPercentage + totalFixed,
    );
  }

  /// حساب رسوم الإقرار بالكامل
  Future<DeclarationFeeResult> calculateDeclarationFees({
    required List<Map<String, dynamic>> items,
    required double exchangeRate,
  }) async {
    final List<ItemFeeResult> itemResults = [];
    double totalUsd = 0;

    for (final item in items) {
      final hsCode = item['hs_code'] as String? ?? '';
      final itemValue = (item['item_value'] as num?)?.toDouble() ?? (item['value'] as num?)?.toDouble() ?? 0;
      if (hsCode.isNotEmpty && itemValue > 0) {
        totalUsd += itemValue;
        final result = await calculateItemFees(hsCode: hsCode, itemValueUsd: itemValue, exchangeRate: exchangeRate);
        itemResults.add(result);
      }
    }

    final mergedPercentage = _mergePercentageFees(itemResults);
    final mergedFixed = _mergeFixedFees(itemResults);
    final grandPercentage = mergedPercentage.fold<double>(0, (sum, f) => sum + f.calculatedAmount);
    final grandFixed = mergedFixed.fold<double>(0, (sum, f) => sum + f.calculatedAmount);

    return DeclarationFeeResult(
      exchangeRate: exchangeRate, totalInvoiceUsd: totalUsd, totalInvoiceYer: totalUsd * exchangeRate,
      itemResults: itemResults, mergedPercentageFees: mergedPercentage, mergedFixedFees: mergedFixed,
      grandTotalPercentage: grandPercentage, grandTotalFixed: grandFixed,
      grandTotal: grandPercentage + grandFixed,
    );
  }

  /// حفظ/تحديث قواعد رسوم HS Code
  Future<void> saveHsCodeFeeRules({
    required String hsCode,
    String? hsCodeId,
    required List<Map<String, dynamic>> percentageRules,
    required List<Map<String, dynamic>> fixedRules,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _database.delete('hs_code_fee_rules', where: 'hs_code = ?', whereArgs: [hsCode]);

    int order = 1;
    for (final rule in percentageRules) {
      await _database.insert('hs_code_fee_rules', {
        'id': 'hsfee-${hsCode}-${rule['code']}-${DateTime.now().millisecondsSinceEpoch}',
        'hs_code_id': hsCodeId ?? hsCode, 'hs_code': hsCode,
        'fee_code': rule['code'] as String, 'fee_name': rule['name'] as String,
        'fee_type': 'percentage', 'rate': (rule['rate'] as num).toDouble(),
        'fixed_amount': 0, 'calculation_basis': rule['basis'] as String? ?? 'invoice_value',
        'calculation_order': order++, 'is_active': 1, 'created_at': now, 'updated_at': now,
      });
    }
    for (final rule in fixedRules) {
      await _database.insert('hs_code_fee_rules', {
        'id': 'hsfee-${hsCode}-${rule['code']}-${DateTime.now().millisecondsSinceEpoch}',
        'hs_code_id': hsCodeId ?? hsCode, 'hs_code': hsCode,
        'fee_code': rule['code'] as String, 'fee_name': rule['name'] as String,
        'fee_type': 'fixed', 'rate': 0, 'fixed_amount': (rule['amount'] as num).toDouble(),
        'calculation_basis': 'fixed', 'calculation_order': order++, 'is_active': 1,
        'created_at': now, 'updated_at': now,
      });
    }
  }

  /// جلب قواعد HS Code المحفوظة (لشاشة الإدارة)
  Future<List<Map<String, dynamic>>> getHsCodeRules() async {
    return await _database.query('hs_code_fee_rules', where: 'is_active = 1', orderBy: 'hs_code ASC');
  }

  /// جلب جميع تصنيفات HS Code
  Future<List<Map<String, dynamic>>> getHsCodeCategories() async {
    return await _database.query('hs_code_categories', where: 'is_active = 1', orderBy: 'category_code ASC');
  }

  /// جلب قواعد HS Code محددة
  Future<List<HsCodeFeeRule>> getHsCodeFeeRules(String hsCode) async {
    final rules = await _database.query(
      'hs_code_fee_rules', where: 'hs_code = ? AND is_active = 1',
      whereArgs: [hsCode], orderBy: 'calculation_order ASC',
    );
    return rules.map((r) => HsCodeFeeRule.fromMap(r)).toList();
  }

  // ============ دوال مساعدة ============

  Future<ItemFeeResult> _calculateWithDefaultRules(
    String hsCode, double itemValueUsd, double exchangeRate, double itemValueYer) async {
    final generalRules = await _database.query('relative_fees', where: 'is_active = 1', orderBy: 'execution_order ASC');
    final generalFixed = await _database.query('fixed_fees', where: 'is_active = 1');

    final List<CalculatedFee> percentageFees = [];
    double currentBase = itemValueYer;
    double totalPercentage = 0;

    for (final rule in generalRules) {
      final rate = (rule['rate'] as num).toDouble();
      final basis = rule['calculation_base'] as String? ?? 'invoice_value';
      double baseAmount = basis == 'after_duty' || basis == 'after_st' ? currentBase : itemValueYer;
      final amount = baseAmount * (rate / 100);
      percentageFees.add(CalculatedFee(
        feeCode: rule['code'] as String, feeName: rule['name'] as String, feeType: 'percentage',
        rate: rate, fixedAmount: 0, calculatedAmount: amount,
        calculationBasis: basis, calculationOrder: rule['execution_order'] as int? ?? 99,
      ));
      currentBase += amount;
      totalPercentage += amount;
    }

    final List<CalculatedFee> fixedFees = [];
    double totalFixed = 0;
    for (final rule in generalFixed) {
      final amount = (rule['amount'] as num).toDouble();
      fixedFees.add(CalculatedFee(
        feeCode: rule['code'] as String, feeName: rule['name'] as String, feeType: 'fixed',
        rate: 0, fixedAmount: amount, calculatedAmount: amount,
        calculationBasis: 'fixed', calculationOrder: 99,
      ));
      totalFixed += amount;
    }

    return ItemFeeResult(
      hsCode: hsCode, itemValueUsd: itemValueUsd, exchangeRate: exchangeRate,
      itemValueYer: itemValueYer, percentageFees: percentageFees, fixedFees: fixedFees,
      totalPercentageFees: totalPercentage, totalFixedFees: totalFixed,
      totalFees: totalPercentage + totalFixed,
    );
  }

  List<CalculatedFee> _mergePercentageFees(List<ItemFeeResult> items) {
    final Map<String, CalculatedFee> merged = {};
    for (final item in items) {
      for (final fee in item.percentageFees) {
        if (merged.containsKey(fee.feeCode)) {
          merged[fee.feeCode] = CalculatedFee(
            feeCode: fee.feeCode, feeName: fee.feeName, feeType: fee.feeType,
            rate: fee.rate, fixedAmount: 0,
            calculatedAmount: merged[fee.feeCode]!.calculatedAmount + fee.calculatedAmount,
            calculationBasis: fee.calculationBasis, calculationOrder: fee.calculationOrder,
          );
        } else {
          merged[fee.feeCode] = fee;
        }
      }
    }
    return merged.values.toList()..sort((a, b) => a.calculationOrder.compareTo(b.calculationOrder));
  }

  List<CalculatedFee> _mergeFixedFees(List<ItemFeeResult> items) {
    final Map<String, CalculatedFee> merged = {};
    for (final item in items) {
      for (final fee in item.fixedFees) {
        if (merged.containsKey(fee.feeCode)) {
          merged[fee.feeCode] = CalculatedFee(
            feeCode: fee.feeCode, feeName: fee.feeName, feeType: fee.feeType,
            rate: 0, fixedAmount: fee.fixedAmount,
            calculatedAmount: merged[fee.feeCode]!.calculatedAmount + fee.calculatedAmount,
            calculationBasis: fee.calculationBasis, calculationOrder: fee.calculationOrder,
          );
        } else {
          merged[fee.feeCode] = fee;
        }
      }
    }
    return merged.values.toList();
  }
}

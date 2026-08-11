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
  final String? appliedHsCode;
  final String? hsCodeCategory;

  const FeeBreakdown({
    required this.exchangeRate,
    required this.invoiceValueUsd,
    required this.invoiceValueYer,
    required this.relativeFees,
    required this.fixedFees,
    required this.totalRelativeFees,
    required this.totalFixedFees,
    required this.grandTotal,
    this.appliedHsCode,
    this.hsCodeCategory,
  });

  Map<String, dynamic> toJson() => {
    'exchangeRate': exchangeRate,
    'invoiceValueUsd': invoiceValueUsd,
    'invoiceValueYer': invoiceValueYer,
    'relativeFees': relativeFees.map((f) => f.toJson()).toList(),
    'fixedFees': fixedFees.map((f) => f.toJson()).toList(),
    'totalRelativeFees': totalRelativeFees,
    'totalFixedFees': totalFixedFees,
    'grandTotal': grandTotal,
    'appliedHsCode': appliedHsCode,
    'hsCodeCategory': hsCodeCategory,
  };

  factory FeeBreakdown.fromJson(Map<String, dynamic> json) => FeeBreakdown(
    exchangeRate: json['exchangeRate'] ?? 0,
    invoiceValueUsd: json['invoiceValueUsd'] ?? 0,
    invoiceValueYer: json['invoiceValueYer'] ?? 0,
    relativeFees: (json['relativeFees'] as List?)?.map((f) => FeeItem.fromJson(f)).toList() ?? [],
    fixedFees: (json['fixedFees'] as List?)?.map((f) => FeeItem.fromJson(f)).toList() ?? [],
    totalRelativeFees: json['totalRelativeFees'] ?? 0,
    totalFixedFees: json['totalFixedFees'] ?? 0,
    grandTotal: json['grandTotal'] ?? 0,
    appliedHsCode: json['appliedHsCode'],
    hsCodeCategory: json['hsCodeCategory'],
  );
}

class FeeItem {
  final String code;
  final String name;
  final String type; // 'relative' or 'fixed'
  final double rate;
  final double amount;
  final String calculationBase;
  final String? hsCodeFilter;

  const FeeItem({
    required this.code,
    required this.name,
    required this.type,
    required this.rate,
    required this.amount,
    required this.calculationBase,
    this.hsCodeFilter,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'type': type,
    'rate': rate,
    'amount': amount,
    'calculationBase': calculationBase,
    'hsCodeFilter': hsCodeFilter,
  };

  factory FeeItem.fromJson(Map<String, dynamic> json) => FeeItem(
    code: json['code'] ?? '',
    name: json['name'] ?? '',
    type: json['type'] ?? 'relative',
    rate: (json['rate'] ?? 0).toDouble(),
    amount: (json['amount'] ?? 0).toDouble(),
    calculationBase: json['calculationBase'] ?? '',
    hsCodeFilter: json['hsCodeFilter'],
  );
}

class HsCodeFeeEngine {
  final Database _database;

  HsCodeFeeEngine(this._database);

  /// احتساب الرسوم لصنف محدد بناءً على HS Code
  Future<FeeBreakdown> calculateFeesForItem({
    required String hsCode,
    required double itemValueUsd,
    required double exchangeRate,
    String? itemType,
  }) async {
    final itemValueYer = itemValueUsd * exchangeRate;

    // 1. البحث عن قواعد خاصة بهذا HS Code
    List<FeeItem> relativeFees = [];
    List<FeeItem> fixedFees = [];
    String? categoryName;

    final specificRules = await _database.query(
      'hs_code_fee_rules',
      where: 'hs_code = ? AND is_active = 1',
      whereArgs: [hsCode],
      limit: 1,
    );

    if (specificRules.isNotEmpty) {
      // استخدام القواعد الخاصة بهذا HS Code
      final rule = specificRules.first;
      relativeFees = _parseRelativeFees(rule['relative_fees_json'] as String? ?? '[]');
      fixedFees = _parseFixedFees(rule['fixed_fees_json'] as String? ?? '[]');
      categoryName = rule['hs_code_category'] as String?;
    } else {
      // 2. البحث عن القسم (أول 4 أرقام من HS Code)
      final hsCodePrefix = hsCode.length >= 4 ? hsCode.substring(0, 4) : hsCode;
      
      final categoryRules = await _database.query(
        'hs_code_categories',
        where: 'category_code = ? AND is_active = 1',
        whereArgs: [hsCodePrefix],
        limit: 1,
      );

      if (categoryRules.isNotEmpty) {
        final cat = categoryRules.first;
        relativeFees = _parseRelativeFees(cat['default_relative_fees_json'] as String? ?? '[]');
        fixedFees = _parseFixedFees(cat['default_fixed_fees_json'] as String? ?? '[]');
        categoryName = cat['category_name'] as String?;
      } else {
        // 3. استخدام الرسوم الافتراضية العامة
        relativeFees = await _getDefaultRelativeFees();
        fixedFees = await _getDefaultFixedFees();
        categoryName = 'رسوم عامة';
      }
    }

    // حساب الرسوم النسبية
    double currentBase = itemValueYer;
    double totalRelative = 0;
    final List<FeeItem> calculatedRelative = [];

    for (final fee in relativeFees) {
      double baseAmount;
      if (fee.calculationBase == 'after_duty' || fee.calculationBase == 'after_st') {
        baseAmount = currentBase;
      } else {
        baseAmount = itemValueYer;
      }

      final feeAmount = baseAmount * (fee.rate / 100);

      calculatedRelative.add(FeeItem(
        code: fee.code,
        name: fee.name,
        type: 'relative',
        rate: fee.rate,
        amount: feeAmount,
        calculationBase: fee.calculationBase,
      ));

      currentBase += feeAmount;
      totalRelative += feeAmount;
    }

    // حساب الرسوم الثابتة
    double totalFixed = 0;
    final List<FeeItem> calculatedFixed = [];

    for (final fee in fixedFees) {
      calculatedFixed.add(FeeItem(
        code: fee.code,
        name: fee.name,
        type: 'fixed',
        rate: 0,
        amount: fee.amount,
        calculationBase: 'fixed',
      ));
      totalFixed += fee.amount;
    }

    return FeeBreakdown(
      exchangeRate: exchangeRate,
      invoiceValueUsd: itemValueUsd,
      invoiceValueYer: itemValueYer,
      relativeFees: calculatedRelative,
      fixedFees: calculatedFixed,
      totalRelativeFees: totalRelative,
      totalFixedFees: totalFixed,
      grandTotal: totalRelative + totalFixed,
      appliedHsCode: hsCode,
      hsCodeCategory: categoryName,
    );
  }

  /// احتساب رسوم الإقرار بالكامل (لجميع الأصناف)
  Future<FeeBreakdown> calculateDeclarationFees({
    required List<Map<String, dynamic>> items,
    required double exchangeRate,
  }) async {
    double totalRelative = 0;
    double totalFixed = 0;
    double totalInvoiceUsd = 0;
    List<FeeItem> allRelative = [];
    List<FeeItem> allFixed = [];

    for (final item in items) {
      final itemValue = (item['item_value'] as num?)?.toDouble() ?? 0;
      final hsCode = item['hs_code'] as String? ?? '';
      
      if (itemValue > 0 && hsCode.isNotEmpty) {
        final itemFees = await calculateFeesForItem(
          hsCode: hsCode,
          itemValueUsd: itemValue,
          exchangeRate: exchangeRate,
          itemType: item['package_type'] as String?,
        );

        totalInvoiceUsd += itemValue;
        totalRelative += itemFees.totalRelativeFees;
        totalFixed += itemFees.totalFixedFees;
        
        // دمج الرسوم (تجميع المتشابهة)
        allRelative = _mergeFees(allRelative, itemFees.relativeFees);
        allFixed = _mergeFees(allFixed, itemFees.fixedFees);
      }
    }

    return FeeBreakdown(
      exchangeRate: exchangeRate,
      invoiceValueUsd: totalInvoiceUsd,
      invoiceValueYer: totalInvoiceUsd * exchangeRate,
      relativeFees: allRelative,
      fixedFees: allFixed,
      totalRelativeFees: totalRelative,
      totalFixedFees: totalFixed,
      grandTotal: totalRelative + totalFixed,
    );
  }

  /// حفظ قاعدة رسوم لـ HS Code (تتعلم من الإقرارات المعتمدة)
  Future<void> saveHsCodeRule({
    required String hsCode,
    required String hsCodeCategory,
    required String itemType,
    required List<FeeItem> relativeFees,
    required List<FeeItem> fixedFees,
  }) async {
    final now = DateTime.now().toIso8601String();
    
    final existing = await _database.query(
      'hs_code_fee_rules',
      where: 'hs_code = ?',
      whereArgs: [hsCode],
    );

    final data = {
      'hs_code': hsCode,
      'hs_code_category': hsCodeCategory,
      'item_type': itemType,
      'relative_fees_json': jsonEncode(relativeFees.map((f) => f.toJson()).toList()),
      'fixed_fees_json': jsonEncode(fixedFees.map((f) => f.toJson()).toList()),
      'is_active': 1,
      'updated_at': now,
    };

    if (existing.isNotEmpty) {
      await _database.update('hs_code_fee_rules', data, where: 'hs_code = ?', whereArgs: [hsCode]);
    } else {
      await _database.insert('hs_code_fee_rules', {
        ...data,
        'id': 'hs-rule-$hsCode',
        'created_at': now,
      });
    }
  }

  /// إضافة تصنيف جديد لـ HS Code مع رسوم افتراضية
  Future<void> saveHsCodeCategory({
    required String categoryCode,
    required String categoryName,
    required String description,
    required List<FeeItem> defaultRelativeFees,
    required List<FeeItem> defaultFixedFees,
  }) async {
    final now = DateTime.now().toIso8601String();
    
    final existing = await _database.query(
      'hs_code_categories',
      where: 'category_code = ?',
      whereArgs: [categoryCode],
    );

    final data = {
      'category_code': categoryCode,
      'category_name': categoryName,
      'description': description,
      'default_relative_fees_json': jsonEncode(defaultRelativeFees.map((f) => f.toJson()).toList()),
      'default_fixed_fees_json': jsonEncode(defaultFixedFees.map((f) => f.toJson()).toList()),
      'is_active': 1,
      'created_at': now,
    };

    if (existing.isNotEmpty) {
      await _database.update('hs_code_categories', data, where: 'category_code = ?', whereArgs: [categoryCode]);
    } else {
      await _database.insert('hs_code_categories', {
        ...data,
        'id': 'cat-$categoryCode',
      });
    }
  }

  /// جلب جميع تصنيفات HS Code
  Future<List<Map<String, dynamic>>> getHsCodeCategories() async {
    return await _database.query('hs_code_categories', where: 'is_active = 1', orderBy: 'category_code ASC');
  }

  /// جلب قواعد HS Code المحفوظة
  Future<List<Map<String, dynamic>>> getHsCodeRules() async {
    return await _database.query('hs_code_fee_rules', where: 'is_active = 1', orderBy: 'hs_code ASC');
  }

  // --- دوال مساعدة ---

  List<FeeItem> _parseRelativeFees(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list.map((f) => FeeItem.fromJson(f)).toList();
    } catch (_) {
      return [];
    }
  }

  List<FeeItem> _parseFixedFees(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list.map((f) => FeeItem.fromJson(f)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<FeeItem>> _getDefaultRelativeFees() async {
    final fees = await _database.query('relative_fees', where: 'is_active = 1', orderBy: 'execution_order ASC');
    return fees.map((f) => FeeItem(
      code: f['code'] as String,
      name: f['name'] as String,
      type: 'relative',
      rate: (f['rate'] as num).toDouble(),
      amount: 0,
      calculationBase: f['calculation_base'] as String? ?? 'invoice_value',
    )).toList();
  }

  Future<List<FeeItem>> _getDefaultFixedFees() async {
    final fees = await _database.query('fixed_fees', where: 'is_active = 1', orderBy: 'execution_order ASC');
    return fees.map((f) => FeeItem(
      code: f['code'] as String,
      name: f['name'] as String,
      type: 'fixed',
      rate: 0,
      amount: (f['amount'] as num).toDouble(),
      calculationBase: 'fixed',
    )).toList();
  }

  List<FeeItem> _mergeFees(List<FeeItem> existing, List<FeeItem> newFees) {
    final Map<String, FeeItem> merged = {};
    
    for (final fee in existing) {
      merged[fee.code] = fee;
    }
    
    for (final fee in newFees) {
      if (merged.containsKey(fee.code)) {
        merged[fee.code] = FeeItem(
          code: fee.code,
          name: fee.name,
          type: fee.type,
          rate: fee.rate,
          amount: merged[fee.code]!.amount + fee.amount,
          calculationBase: fee.calculationBase,
        );
      } else {
        merged[fee.code] = fee;
      }
    }
    
    return merged.values.toList();
  }
}

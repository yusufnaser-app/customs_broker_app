import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class ExcelGenerator {
  static final currencyFormatter = NumberFormat('#,##0.00');

  static Future<File> generateDeclarationsExcel(List<Map<String, dynamic>> declarations) async {
    var excel = Excel.createExcel();
    var sheet = excel['الإقرارات'];
    
    // رؤوس الأعمدة
    var headers = ['رقم الإقرار', 'رقم البيان', 'تاريخ البيان', 'العميل', 'المركز الجمركي', 'قيمة الفاتورة', 'العملة', 'الحالة'];
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = CellStyle(bold: true);
    }
    
    // البيانات
    for (var r = 0; r < declarations.length; r++) {
      var d = declarations[r];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1)).value = TextCellValue(d['declaration_number'] ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1)).value = TextCellValue(d['statement_number'] ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1)).value = TextCellValue(d['statement_date'] ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r + 1)).value = TextCellValue(d['client_name'] ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r + 1)).value = TextCellValue(d['customs_center'] ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r + 1)).value = DoubleCellValue((d['invoice_value_usd'] as num?)?.toDouble() ?? 0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r + 1)).value = TextCellValue(d['currency'] ?? 'USD');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: r + 1)).value = TextCellValue(d['status'] ?? '');
    }
    
    return _saveExcel(excel, 'تقرير_الإقرارات.xlsx');
  }

  static Future<File> generateFinancialExcel({
    required List<Map<String, dynamic>> revenues,
    required List<Map<String, dynamic>> expenses,
  }) async {
    var excel = Excel.createExcel();
    
    // صفحة الإيرادات
    var revenueSheet = excel['الإيرادات'];
    var headers = ['التاريخ', 'الفئة', 'المصدر', 'الوصف', 'المبلغ'];
    for (var i = 0; i < headers.length; i++) {
      revenueSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
      revenueSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = CellStyle(bold: true);
    }
    for (var r = 0; r < revenues.length; r++) {
      var rev = revenues[r];
      revenueSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1)).value = TextCellValue((rev['revenue_date'] ?? '').toString().substring(0, 10));
      revenueSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1)).value = TextCellValue(rev['category'] ?? '');
      revenueSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1)).value = TextCellValue(rev['source'] ?? '');
      revenueSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r + 1)).value = TextCellValue(rev['description'] ?? '');
      revenueSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r + 1)).value = DoubleCellValue((rev['amount'] as num?)?.toDouble() ?? 0);
    }
    
    // صفحة المصروفات
    var expenseSheet = excel['المصروفات'];
    for (var i = 0; i < headers.length; i++) {
      expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
      expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = CellStyle(bold: true);
    }
    for (var r = 0; r < expenses.length; r++) {
      var exp = expenses[r];
      expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1)).value = TextCellValue((exp['expense_date'] ?? '').toString().substring(0, 10));
      expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1)).value = TextCellValue(exp['category'] ?? '');
      expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1)).value = TextCellValue(exp['payment_method'] ?? '');
      expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r + 1)).value = TextCellValue(exp['description'] ?? '');
      expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r + 1)).value = DoubleCellValue((exp['amount'] as num?)?.toDouble() ?? 0);
    }
    
    return _saveExcel(excel, 'التقرير_المالي.xlsx');
  }

  static Future<File> _saveExcel(Excel excel, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(excel.encode()!);
    return file;
  }

  static Future<void> shareExcel(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'تقرير Excel');
  }
}

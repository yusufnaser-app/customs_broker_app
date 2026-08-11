import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// يولّد PDF احترافي كامل لإقرار جمركي واحد: رأس بمعلومات المكتب، معلومات
/// الإقرار، جدول البضائع، كشف الرسوم، المجاميع، وختم المصادقة.
class DeclarationPdfGenerator {
  static final currencyFormatter = NumberFormat('#,##0.00');
  static final yerFormatter = NumberFormat('#,##0');

  static Future<File> generate({
    required Map<String, dynamic> office,
    required Map<String, dynamic> declaration,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> feeBreakdownJson,
    String? representativeName,
    String? approvalDate,
  }) async {
    final arabicFont = pw.Font.ttf(await rootBundle.load('assets/fonts/Arabic-Regular.ttf'));
    final arabicFontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Arabic-Bold.ttf'));

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _buildHeader(office),
          pw.SizedBox(height: 14),
          _buildDeclarationInfo(declaration),
          pw.SizedBox(height: 14),
          pw.Text('جدول البضائع', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _buildItemsTable(items),
          pw.SizedBox(height: 14),
          pw.Text('كشف الرسوم', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _buildFeesTable(feeBreakdownJson),
          pw.SizedBox(height: 10),
          _buildTotals(feeBreakdownJson),
          pw.SizedBox(height: 24),
          _buildSignature(office, representativeName, approvalDate),
          pw.SizedBox(height: 10),
          _buildFooter(),
        ],
      ),
    );

    return _saveAndGetFile(pdf, 'اقرار_${declaration['declaration_number'] ?? ''}.pdf');
  }

  static pw.Widget _buildHeader(Map<String, dynamic> office) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          office['office_name'] as String? ?? 'مكتب التخليص الجمركي',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            if ((office['license_number'] as String?)?.isNotEmpty == true)
              pw.Text('رقم الترخيص: ${office['license_number']}   ', style: const pw.TextStyle(fontSize: 10)),
            if ((office['tax_number'] as String?)?.isNotEmpty == true)
              pw.Text('الرقم الضريبي: ${office['tax_number']}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.5),
        pw.SizedBox(height: 4),
        pw.Text('إقرار جمركي', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildDeclarationInfo(Map<String, dynamic> d) {
    infoField(String label, dynamic value) => pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Text('$label: ${value ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
          ),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [infoField('رقم البيان', d['statement_number']), infoField('تاريخ البيان', d['statement_date']), infoField('نوع البيان', d['statement_type'])]),
          pw.Row(children: [infoField('المركز الجمركي', d['customs_center_name'] ?? d['customs_center']), infoField('المستورد', d['importer_name']), infoField('المورد', d['supplier_name'])]),
          pw.Row(children: [infoField('بلد المنشأ', d['origin_country']), infoField('بلد التصدير', d['export_country']), infoField('وسيلة النقل', d['transport_method'])]),
          pw.Row(children: [infoField('اسم السفينة', d['vessel_name']), infoField('رقم الحاوية', d['container_number']), infoField('', '')]),
          pw.Row(children: [infoField('رقم الفاتورة', d['invoice_number']), infoField('تاريخ الفاتورة', d['invoice_date']), infoField('العملة', d['currency'])]),
          pw.Row(children: [
            infoField('قيمة الفاتورة', currencyFormatter.format((d['invoice_value_usd'] as num?) ?? 0)),
            infoField('سعر الصرف', currencyFormatter.format((d['exchange_rate'] as num?) ?? 0)),
            infoField('', ''),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<Map<String, dynamic>> items) {
    return pw.TableHelper.fromTextArray(
      headers: ['#', 'HS Code', 'التسمية', 'المنشأ', 'نوع الطرد', 'عدد الطرود', 'وزن قائم', 'وزن صافي', 'القيمة', 'قاعدة الاحتساب'],
      data: items.asMap().entries.map((entry) {
        final i = entry.key + 1;
        final item = entry.value;
        return [
          i.toString(),
          item['hs_code'] ?? '',
          item['item_name'] ?? '',
          item['origin_country'] ?? '-',
          item['package_type'] ?? '-',
          (item['packages_count'] ?? '-').toString(),
          (item['gross_weight'] != null) ? currencyFormatter.format(item['gross_weight']) : '-',
          (item['net_weight'] != null) ? currencyFormatter.format(item['net_weight']) : '-',
          currencyFormatter.format((item['value'] as num?) ?? 0),
          (item['local_value'] != null) ? yerFormatter.format(item['local_value']) : '-',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.center,
      border: pw.TableBorder.all(width: 0.4),
    );
  }

  static pw.Widget _buildFeesTable(Map<String, dynamic> breakdown) {
    final relativeFees = (breakdown['relativeFees'] as List?) ?? [];
    final fixedFees = (breakdown['fixedFees'] as List?) ?? [];

    final rows = <List<String>>[];
    for (final fee in relativeFees) {
      rows.add([
        fee['code'] ?? '',
        fee['name'] ?? '',
        'نسبي',
        fee['calculationBase'] ?? '-',
        '${fee['rate']}%',
        yerFormatter.format((fee['amount'] as num?) ?? 0),
      ]);
    }
    for (final fee in fixedFees) {
      rows.add([
        fee['code'] ?? '',
        fee['name'] ?? '',
        'ثابت',
        '-',
        '-',
        yerFormatter.format((fee['amount'] as num?) ?? 0),
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: ['الرمز', 'اسم الرسم', 'النوع', 'أساس الاحتساب', 'النسبة/القيمة', 'المبلغ (ر.ي)'],
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.center,
      border: pw.TableBorder.all(width: 0.4),
    );
  }

  static pw.Widget _buildTotals(Map<String, dynamic> breakdown) {
    final totalRelative = (breakdown['totalRelativeFees'] as num?) ?? 0;
    final totalFixed = (breakdown['totalFixedFees'] as num?) ?? 0;
    final grandTotal = (breakdown['grandTotal'] as num?) ?? 0;

    row(String label, num value, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
              pw.Text('${yerFormatter.format(value)} ر.ي', style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ],
          ),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
      width: 260,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          row('إجمالي الرسوم النسبية', totalRelative),
          row('إجمالي الرسوم الثابتة', totalFixed),
          pw.Divider(),
          row('إجمالي المبلغ المستحق', grandTotal, bold: true),
        ],
      ),
    );
  }

  static pw.Widget _buildSignature(Map<String, dynamic> office, String? representativeName, String? approvalDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6, style: pw.BorderStyle.dashed)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('تم التدقيق والمصادقة عليه', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('مكتب التخليص: ${office['office_name'] ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('المندوب: ${representativeName ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('تاريخ الاعتماد: ${approvalDate ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Text(
        '© يوسف عبدالله ناصر | للتواصل: 775477377',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  static Future<File> _saveAndGetFile(pw.Document pdf, String fileName) async {
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}

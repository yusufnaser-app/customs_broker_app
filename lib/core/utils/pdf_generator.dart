import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart' show Printing;
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class PdfGenerator {
  static final currencyFormatter = NumberFormat('#,##0.00');
  static final dateFormatter = DateFormat('yyyy/MM/dd');

  static pw.ThemeData? _cachedTheme;

  static Future<pw.ThemeData> _arabicTheme() async {
    if (_cachedTheme != null) return _cachedTheme!;
    final base = pw.Font.ttf(await rootBundle.load('assets/fonts/Arabic-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Arabic-Bold.ttf'));
    _cachedTheme = pw.ThemeData.withFont(base: base, bold: bold);
    return _cachedTheme!;
  }

  static pw.TextStyle ts({double size = 12, bool bold = false, PdfColor? color}) {
    return pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.black);
  }

  // ============ كود تحقق (SHA-256) ============
  static String _generateVerificationCode(Map<String, dynamic> document) {
    final data = '${document['document_id'] ?? ''}-${document['document_number'] ?? ''}-${document['document_date'] ?? ''}';
    final hash = sha256.convert(utf8.encode(data));
    return hash.toString().substring(0, 6).toUpperCase();
  }

  // ============ ختم المكتب (يظهر أعلى كل صفحة عبر معامل header في MultiPage) ============
  static pw.Widget _buildStamp(Map<String, dynamic> office, Map<String, dynamic> document) {
    final officeName = office['office_name'] as String? ?? '';
    final licenseNumber = office['license_number'] as String? ?? '';
    final phone = office['phone'] as String? ?? '';
    final documentNumber = document['document_number'] as String? ?? '';
    final documentDate = document['document_date'] as String? ?? dateFormatter.format(DateTime.now());
    final verificationCode = document['verification_code'] as String? ?? _generateVerificationCode(document);

    return pw.Container(
      width: 90,
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('دليل المخلص الجمركي', style: ts(size: 6, bold: true, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 2),
          pw.Divider(color: PdfColors.grey400, height: 1),
          pw.SizedBox(height: 2),
          if (officeName.isNotEmpty)
            pw.Text(officeName, style: ts(size: 6, bold: true), textAlign: pw.TextAlign.center, maxLines: 2),
          pw.SizedBox(height: 2),
          if (licenseNumber.isNotEmpty) pw.Text('ترخيص: $licenseNumber', style: ts(size: 5, color: PdfColors.grey600)),
          if (phone.isNotEmpty) pw.Text(phone, style: ts(size: 5, color: PdfColors.grey600)),
          pw.SizedBox(height: 3),
          if (documentNumber.isNotEmpty) pw.Text(documentNumber, style: ts(size: 5, bold: true)),
          pw.Text(documentDate, style: ts(size: 5, color: PdfColors.grey600)),
          pw.SizedBox(height: 3),
          pw.Text('كود: $verificationCode', style: ts(size: 4, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  static pw.Widget _buildOfficeHeader(Map<String, dynamic> office, String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: PdfColors.blue900, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(office['office_name'] as String? ?? 'مكتب التخليص الجمركي', style: ts(size: 18, bold: true, color: PdfColors.white)),
          pw.SizedBox(height: 6),
          pw.Text(title, style: ts(size: 13, color: PdfColors.white)),
          if ((office['license_number'] as String?)?.isNotEmpty == true)
            pw.Text('ترخيص: ${office['license_number']}', style: ts(size: 9, color: PdfColors.white)),
          if ((office['phone'] as String?)?.isNotEmpty == true)
            pw.Text('هاتف: ${office['phone']}', style: ts(size: 9, color: PdfColors.white)),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Row(children: [
        pw.Container(width: 3, height: 14, color: PdfColors.blue900),
        pw.SizedBox(width: 6),
        pw.Text(title, style: ts(size: 13, bold: true, color: PdfColors.blue900)),
      ]),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 90, child: pw.Text('$label:', style: ts(size: 11, bold: true, color: PdfColors.grey700))),
          pw.Expanded(child: pw.Text(value, style: ts(size: 11))),
        ],
      ),
    );
  }

  static pw.Widget _docFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [pw.Text('دليل المخلص الجمركي - 775477377', style: ts(size: 7, color: PdfColors.grey400))],
      ),
    );
  }

  static pw.Widget _buildFeesTable(Map<String, dynamic> feesData) {
    final relativeFees = (feesData['relativeFees'] as List?) ?? [];
    final fixedFees = (feesData['fixedFees'] as List?) ?? [];
    final allFees = [
      ...relativeFees.map((f) => {...f as Map, 'type': 'نسبي'}),
      ...fixedFees.map((f) => {...f as Map, 'type': 'ثابت'}),
    ];

    if (allFees.isEmpty) {
      return pw.Text('لا توجد رسوم', style: ts(size: 11, color: PdfColors.grey500));
    }

    return pw.TableHelper.fromTextArray(
      headerStyle: ts(size: 9, bold: true),
      cellStyle: ts(size: 9),
      headers: ['الرمز', 'اسم الرسم', 'النوع', 'النسبة/القيمة', 'المبلغ (ر.ي)'],
      data: allFees.map((fee) => [
        fee['code']?.toString() ?? '',
        fee['name']?.toString() ?? '',
        fee['type']?.toString() ?? '',
        fee['type'] == 'نسبي' ? '${fee['rate']}%' : currencyFormatter.format((fee['amount'] as num?) ?? 0),
        currencyFormatter.format((fee['amount'] as num?) ?? 0),
      ]).toList(),
    );
  }

  /// يبني الصفحات مع تكرار الختم في أعلى كل صفحة عبر معامل header الرسمي في MultiPage،
  /// بدل محاولة إعادة تصيير المستند كصورة (لا وجود لتلك الآلية فعليًا في حزمة pdf).
  static Future<File> _buildStampedDocument({
    required Map<String, dynamic> office,
    required Map<String, dynamic> document,
    required List<pw.Widget> content,
    required String fileName,
  }) async {
    final theme = await _arabicTheme();
    final pdf = pw.Document(theme: theme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.only(top: 20, bottom: 20, left: 20, right: 20),
        header: (context) => pw.Align(
          alignment: pw.Alignment.topLeft,
          child: _buildStamp(office, document),
        ),
        build: (context) => content,
      ),
    );

    return _saveAndGetFile(pdf, fileName);
  }

  // ============ توليد إقرار جمركي (نسخة الختم المبسطة؛ للتقرير الكامل استخدم DeclarationPdfGenerator) ============
  static Future<File> generateDeclarationPdf({
    required Map<String, dynamic> office,
    required Map<String, dynamic> document,
    required Map<String, dynamic> declarationData,
  }) async {
    return _buildStampedDocument(
      office: office,
      document: document,
      fileName: 'اقرار_${declarationData['statement_number'] ?? ''}.pdf',
      content: [
        _buildOfficeHeader(office, 'إقرار جمركي'),
        pw.SizedBox(height: 16),
        _sectionTitle('بيانات الإقرار'),
        pw.SizedBox(height: 10),
        _infoRow('رقم البيان', declarationData['statement_number'] as String? ?? '-'),
        _infoRow('تاريخ البيان', declarationData['statement_date'] as String? ?? '-'),
        _infoRow('نوع البيان', declarationData['statement_type'] as String? ?? '-'),
        _infoRow('المركز الجمركي', declarationData['customs_center_name'] as String? ?? '-'),
        _infoRow('المستورد', declarationData['importer_name'] as String? ?? '-'),
        _infoRow('المورد', declarationData['supplier_name'] as String? ?? '-'),
        _infoRow('بلد المنشأ', declarationData['origin_country'] as String? ?? '-'),
        _infoRow('بلد التصدير', declarationData['export_country'] as String? ?? '-'),
        _infoRow('وسيلة النقل', declarationData['transport_method'] as String? ?? '-'),
        _infoRow('رقم الحاوية', declarationData['container_number'] as String? ?? '-'),
        _infoRow('رقم الفاتورة', declarationData['invoice_number'] as String? ?? '-'),
        _infoRow('قيمة الفاتورة', '${currencyFormatter.format((declarationData['invoice_value_usd'] as num?) ?? 0)} ${declarationData['currency'] ?? 'USD'}'),
        _infoRow('سعر الصرف', '${currencyFormatter.format((declarationData['exchange_rate'] as num?) ?? 0)} ريال/دولار'),
        if (declarationData['notes'] != null && (declarationData['notes'] as String).isNotEmpty)
          _infoRow('ملاحظات', declarationData['notes'] as String),
        pw.SizedBox(height: 16),
        if (declarationData['fees'] != null) ...[
          _sectionTitle('كشف الرسوم'),
          pw.SizedBox(height: 8),
          _buildFeesTable(declarationData['fees'] as Map<String, dynamic>),
        ],
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue900, width: 1.5), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Text('تم التدقيق والمصادقة عليه', style: ts(size: 14, bold: true, color: PdfColors.blue900)),
            pw.SizedBox(height: 8),
            pw.Text('المندوب: ${declarationData['representative_name'] ?? '_________________'}', style: ts(size: 12)),
          ]),
        ),
        pw.SizedBox(height: 10),
        _docFooter(),
      ],
    );
  }

  // ============ توليد فاتورة ============
  static Future<File> generateInvoicePdf({
    required Map<String, dynamic> office,
    required Map<String, dynamic> document,
    required Map<String, dynamic> invoiceData,
  }) async {
    return _buildStampedDocument(
      office: office,
      document: document,
      fileName: 'فاتورة_${invoiceData['invoice_number'] ?? ''}.pdf',
      content: [
        _buildOfficeHeader(office, 'فاتورة أتعاب'),
        pw.SizedBox(height: 16),
        _infoRow('رقم الفاتورة', invoiceData['invoice_number'] as String? ?? '-'),
        _infoRow('التاريخ', invoiceData['created_at']?.toString().split('T').first ?? '-'),
        _infoRow('العميل', invoiceData['client_name'] as String? ?? '-'),
        _infoRow('الأتعاب', '${currencyFormatter.format((invoiceData['fees_amount'] as num?) ?? 0)} ر.ي'),
        _infoRow('النثريات', '${currencyFormatter.format((invoiceData['expenses_amount'] as num?) ?? 0)} ر.ي'),
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('الإجمالي', style: ts(size: 14, bold: true)),
          pw.Text('${currencyFormatter.format((invoiceData['total_amount'] as num?) ?? 0)} ر.ي', style: ts(size: 14, bold: true, color: PdfColors.blue900)),
        ]),
        pw.SizedBox(height: 20),
        _docFooter(),
      ],
    );
  }

  // ============ توليد كشف حساب ============
  static Future<File> generateAccountStatementPdf({
    required Map<String, dynamic> office,
    required Map<String, dynamic> document,
    required Map<String, dynamic> statementData,
  }) async {
    return _buildStampedDocument(
      office: office,
      document: document,
      fileName: 'كشف_حساب_${statementData['client_name'] ?? ''}.pdf',
      content: [
        _buildOfficeHeader(office, 'كشف حساب'),
        pw.SizedBox(height: 16),
        _infoRow('العميل', statementData['client_name'] as String? ?? '-'),
        _infoRow('الرصيد', '${currencyFormatter.format((statementData['balance'] as num?) ?? 0)} ر.ي'),
        pw.SizedBox(height: 16),
        _docFooter(),
      ],
    );
  }

  // ============ توليد سند قبض ============
  static Future<File> generateReceiptPdf({
    required Map<String, dynamic> office,
    required Map<String, dynamic> document,
    required Map<String, dynamic> receiptData,
  }) async {
    return _buildStampedDocument(
      office: office,
      document: document,
      fileName: 'سند_قبض_${DateTime.now().millisecondsSinceEpoch}.pdf',
      content: [
        _buildOfficeHeader(office, 'سند قبض'),
        pw.SizedBox(height: 16),
        _infoRow('رقم السند', receiptData['id']?.toString().substring(0, 8) ?? '-'),
        _infoRow('التاريخ', receiptData['transaction_date']?.toString().split('T').first ?? '-'),
        _infoRow('المبلغ', '${currencyFormatter.format((receiptData['amount'] as num?) ?? 0)} ر.ي'),
        _infoRow('البيان', receiptData['description'] as String? ?? '-'),
        pw.SizedBox(height: 20),
        _docFooter(),
      ],
    );
  }

  // ============ توليد سند صرف ============
  static Future<File> generatePaymentVoucherPdf({
    required Map<String, dynamic> office,
    required Map<String, dynamic> document,
    required Map<String, dynamic> voucherData,
  }) async {
    return _buildStampedDocument(
      office: office,
      document: document,
      fileName: 'سند_صرف_${DateTime.now().millisecondsSinceEpoch}.pdf',
      content: [
        _buildOfficeHeader(office, 'سند صرف'),
        pw.SizedBox(height: 16),
        _infoRow('رقم السند', voucherData['id']?.toString().substring(0, 8) ?? '-'),
        _infoRow('التاريخ', voucherData['transaction_date']?.toString().split('T').first ?? '-'),
        _infoRow('المبلغ', '${currencyFormatter.format((voucherData['amount'] as num?) ?? 0)} ر.ي'),
        _infoRow('البيان', voucherData['description'] as String? ?? '-'),
        pw.SizedBox(height: 20),
        _docFooter(),
      ],
    );
  }

  static Future<File> generateDeclarationReport(Map<String, dynamic> data) async {
    final theme = await _arabicTheme();
    final pdf = pw.Document(theme: theme);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          _buildHeader('تقرير الإقرارات الجمركية'),
          pw.SizedBox(height: 10),
          _buildSummaryTable(data['summary'] as Map<String, dynamic>),
          pw.SizedBox(height: 20),
          pw.Header(text: 'قائمة الإقرارات', level: 1),
          _buildDeclarationsTable(data['declarations'] as List<Map<String, dynamic>>),
        ],
      ),
    );
    
    return _saveAndGetFile(pdf, 'تقرير_الإقرارات.pdf');
  }

  static Future<File> generateClientStatement(Map<String, dynamic> data) async {
    final theme = await _arabicTheme();
    final pdf = pw.Document(theme: theme);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          _buildHeader('كشف حساب عميل'),
          pw.SizedBox(height: 10),
          pw.Text('العميل: ${data['client_name'] ?? ''}', style: const pw.TextStyle(fontSize: 16)),
          pw.Text('الرصيد الحالي: ${currencyFormatter.format(data['balance'] ?? 0)} ر.ي', style: pw.TextStyle(fontSize: 14, color: PdfColors.blue)),
          pw.SizedBox(height: 20),
          pw.Header(text: 'الحركات', level: 1),
          _buildTransactionsTable(data['transactions'] as List<Map<String, dynamic>>),
        ],
      ),
    );
    
    return _saveAndGetFile(pdf, 'كشف_حساب_${data['client_name']}.pdf');
  }

  static Future<File> generateFinancialReport(Map<String, dynamic> data) async {
    final theme = await _arabicTheme();
    final pdf = pw.Document(theme: theme);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          _buildHeader('التقرير المالي'),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatBox('الإيرادات', data['total_revenues'] ?? 0, PdfColors.green),
              _buildStatBox('المصروفات', data['total_expenses'] ?? 0, PdfColors.red),
              _buildStatBox('الأرباح', (data['total_revenues'] ?? 0) - (data['total_expenses'] ?? 0), PdfColors.blue),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Header(text: 'تفاصيل الإيرادات', level: 1),
          _buildRevenuesTable(data['revenues'] as List<Map<String, dynamic>>),
          pw.SizedBox(height: 20),
          pw.Header(text: 'تفاصيل المصروفات', level: 1),
          _buildExpensesTable(data['expenses'] as List<Map<String, dynamic>>),
        ],
      ),
    );
    
    return _saveAndGetFile(pdf, 'التقرير_المالي.pdf');
  }

  static Future<File> generateFundReport(Map<String, dynamic> data) async {
    final theme = await _arabicTheme();
    final pdf = pw.Document(theme: theme);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          _buildHeader('تقرير الصندوق'),
          pw.SizedBox(height: 10),
          pw.Text('التاريخ: ${data['date'] ?? ''}', style: const pw.TextStyle(fontSize: 14)),
          pw.Text('الرصيد الافتتاحي: ${currencyFormatter.format(data['opening_balance'] ?? 0)} ر.ي'),
          pw.Text('الرصيد الختامي: ${currencyFormatter.format(data['closing_balance'] ?? 0)} ر.ي', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Header(text: 'الحركات', level: 1),
          _buildFundTransactionsTable(data['transactions'] as List<Map<String, dynamic>>),
        ],
      ),
    );
    
    return _saveAndGetFile(pdf, 'تقرير_الصندوق.pdf');
  }

  static pw.Widget _buildHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text(dateFormatter.format(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static pw.Widget _buildStatBox(String label, double value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(currencyFormatter.format(value), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryTable(Map<String, dynamic> summary) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['البيان', 'القيمة'],
      data: [
        ['عدد الإقرارات', '${summary['count'] ?? 0}'],
        ['الإقرارات المنجزة', '${summary['completed'] ?? 0}'],
        ['الإقرارات الجارية', '${summary['processing'] ?? 0}'],
        ['إجمالي قيمة الفواتير', '${currencyFormatter.format(summary['total_value'] ?? 0)} \$'],
      ],
    );
  }

  static pw.Widget _buildDeclarationsTable(List<Map<String, dynamic>> declarations) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['رقم الإقرار', 'العميل', 'قيمة الفاتورة', 'الحالة', 'التاريخ'],
      data: declarations.map((d) => [
        d['declaration_number'] ?? '',
        d['client_name'] ?? '',
        '${currencyFormatter.format(d['invoice_value_usd'] ?? 0)} \$',
        d['status'] ?? '',
        d['statement_date'] ?? '',
      ]).toList(),
    );
  }

  static pw.Widget _buildTransactionsTable(List<Map<String, dynamic>> transactions) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['التاريخ', 'البيان', 'مدين', 'دائن', 'الرصيد'],
      data: transactions.map((t) => [
        t['date'] ?? '',
        t['description'] ?? '',
        t['debit']?.toString() ?? '',
        t['credit']?.toString() ?? '',
        t['balance']?.toString() ?? '',
      ]).toList(),
    );
  }

  static pw.Widget _buildRevenuesTable(List<Map<String, dynamic>> revenues) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['التاريخ', 'الفئة', 'المصدر', 'المبلغ'],
      data: revenues.map((r) => [
        r['revenue_date']?.toString().substring(0, 10) ?? '',
        r['category'] ?? '',
        r['source'] ?? '',
        '${currencyFormatter.format(r['amount'] ?? 0)} ر.ي',
      ]).toList(),
    );
  }

  static pw.Widget _buildExpensesTable(List<Map<String, dynamic>> expenses) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['التاريخ', 'الفئة', 'الوصف', 'المبلغ'],
      data: expenses.map((e) => [
        e['expense_date']?.toString().substring(0, 10) ?? '',
        e['category'] ?? '',
        e['description'] ?? '',
        '${currencyFormatter.format(e['amount'] ?? 0)} ر.ي',
      ]).toList(),
    );
  }

  static pw.Widget _buildFundTransactionsTable(List<Map<String, dynamic>> transactions) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['التاريخ', 'النوع', 'البيان', 'المبلغ'],
      data: transactions.map((t) => [
        t['transaction_date']?.toString().substring(0, 10) ?? '',
        t['type'] == 'income' ? 'قبض' : 'صرف',
        t['description'] ?? '',
        '${currencyFormatter.format(t['amount'] ?? 0)} ر.ي',
      ]).toList(),
    );
  }

  static Future<File> _saveAndGetFile(pw.Document pdf, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> sharePdf(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'تقرير');
  }

  static Future<void> printPdf(File file) async {
    await Printing.layoutPdf(onLayout: (_) => file.readAsBytes());
  }
}

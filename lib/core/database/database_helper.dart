import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    String path = join(await getDatabasesPath(), 'customs_broker.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // جدول المستخدمين
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // جدول العملاء
    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        tax_number TEXT,
        commercial_register TEXT,
        balance REAL NOT NULL DEFAULT 0,
        notes TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // جدول التجار (المستوردين)
    await db.execute('''
      CREATE TABLE traders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        tax_number TEXT,
        commercial_register TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // جدول الموردين
    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        country TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // إعدادات مكتب التخليص
    await db.execute('''
      CREATE TABLE office_settings (
        id INTEGER PRIMARY KEY,
        office_name TEXT NOT NULL,
        license_number TEXT,
        tax_number TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        logo_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // المندوبون
    await db.execute('''
      CREATE TABLE representatives (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        id_number TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // المراكز الجمركية
    await db.execute('''
      CREATE TABLE customs_centers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        code TEXT,
        location TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // مكتب التخليص
    await db.execute('''
      CREATE TABLE offices (
        id TEXT PRIMARY KEY,
        office_name TEXT NOT NULL,
        license_key TEXT NOT NULL UNIQUE,
        license_number TEXT,
        tax_number TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        max_users INTEGER NOT NULL DEFAULT 5,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // اشتراك المكتب
    await db.execute('''
      CREATE TABLE office_subscriptions (
        id TEXT PRIMARY KEY,
        office_id TEXT NOT NULL UNIQUE,
        plan_type TEXT NOT NULL DEFAULT 'trial',
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        max_users INTEGER NOT NULL DEFAULT 5,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (office_id) REFERENCES offices(id)
      )
    ''');

    // جدول الإقرارات الجمركية
    await db.execute('''
      CREATE TABLE declarations (
        id TEXT PRIMARY KEY,
        declaration_number TEXT NOT NULL,
        statement_number TEXT,
        statement_date TEXT,
        statement_type TEXT,
        customs_center TEXT,
        customs_center_id TEXT,
        customs_center_name TEXT,
        representative_id TEXT,
        representative_name TEXT,
        office_name TEXT,
        vessel_name TEXT,
        total_packages INTEGER,
        total_gross_weight REAL,
        total_net_weight REAL,
        client_id TEXT NOT NULL,
        trader_id TEXT,
        supplier_id TEXT,
        origin_country TEXT,
        export_country TEXT,
        transport_method TEXT,
        container_number TEXT,
        invoice_number TEXT,
        invoice_date TEXT,
        invoice_value_usd REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'USD',
        exchange_rate REAL NOT NULL,
        items_count INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients(id),
        FOREIGN KEY (trader_id) REFERENCES traders(id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
        FOREIGN KEY (customs_center_id) REFERENCES customs_centers(id),
        FOREIGN KEY (representative_id) REFERENCES representatives(id)
      )
    ''');

    // جدول أصناف الإقرار
    await db.execute('''
      CREATE TABLE declaration_items (
        id TEXT PRIMARY KEY,
        declaration_id TEXT NOT NULL,
        hs_code TEXT NOT NULL,
        item_name TEXT NOT NULL,
        description TEXT,
        quantity REAL NOT NULL,
        weight REAL,
        unit TEXT NOT NULL,
        value REAL NOT NULL,
        origin_country TEXT,
        package_type TEXT,
        packages_count INTEGER,
        gross_weight REAL,
        net_weight REAL,
        local_value REAL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (declaration_id) REFERENCES declarations(id) ON DELETE CASCADE
      )
    ''');

    // جدول النسخ التاريخية للإقرارات
    await db.execute('''
      CREATE TABLE declaration_snapshots (
        id TEXT PRIMARY KEY,
        declaration_id TEXT NOT NULL,
        exchange_rate REAL NOT NULL,
        fees_breakdown TEXT NOT NULL,
        total_fees REAL NOT NULL,
        snapshot_date TEXT NOT NULL,
        FOREIGN KEY (declaration_id) REFERENCES declarations(id)
      )
    ''');

    // جدول التعرفة الجمركية
    await db.execute('''
      CREATE TABLE tariff (
        id TEXT PRIMARY KEY,
        hs_code TEXT NOT NULL UNIQUE,
        item_name TEXT NOT NULL,
        description TEXT,
        chapter TEXT,
        unit TEXT,
        restrictions TEXT,
        permits TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // فئات الرسوم
    await db.execute('''
      CREATE TABLE fee_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // جدول الرسوم النسبية
    await db.execute('''
      CREATE TABLE relative_fees (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        category_id TEXT,
        rate REAL NOT NULL,
        calculation_base TEXT NOT NULL,
        hs_code_filter TEXT,
        execution_order INTEGER NOT NULL,
        effective_date TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES fee_categories(id)
      )
    ''');

    // جدول الرسوم الثابتة
    await db.execute('''
      CREATE TABLE fixed_fees (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        category_id TEXT,
        amount REAL NOT NULL,
        unit TEXT DEFAULT 'YER',
        hs_code_filter TEXT,
        description TEXT,
        effective_date TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES fee_categories(id)
      )
    ''');

    // قاعدة رسوم الأصناف
    await db.execute('''
      CREATE TABLE item_fee_rules (
        id TEXT PRIMARY KEY,
        hs_code TEXT NOT NULL,
        item_name TEXT NOT NULL,
        relative_fees_json TEXT,
        fixed_fees_json TEXT,
        total_fees REAL NOT NULL,
        last_used_date TEXT NOT NULL,
        usage_count INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // جدول أسعار الصرف
    await db.execute('''
      CREATE TABLE exchange_rates (
        id TEXT PRIMARY KEY,
        currency_from TEXT NOT NULL,
        currency_to TEXT NOT NULL,
        rate REAL NOT NULL,
        effective_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // ⭐══════════ جداول رسوم HS Code الجديدة ══════════⭐
    
    // جدول تصنيفات HS Code
    await db.execute('''
      CREATE TABLE hs_code_categories (
        id TEXT PRIMARY KEY,
        category_code TEXT NOT NULL UNIQUE,
        category_name TEXT NOT NULL,
        description TEXT,
        default_relative_fees_json TEXT,
        default_fixed_fees_json TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // جدول قواعد الرسوم حسب HS Code
    await db.execute('''
      CREATE TABLE hs_code_fee_rules (
        id TEXT PRIMARY KEY,
        hs_code TEXT NOT NULL,
        hs_code_category TEXT,
        item_type TEXT,
        relative_fees_json TEXT NOT NULL,
        fixed_fees_json TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ⭐══════════ نهاية جداول HS Code ══════════⭐

    // جدول فواتير الأتعاب
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL,
        client_id TEXT NOT NULL,
        declaration_id TEXT,
        fees_amount REAL NOT NULL DEFAULT 0,
        expenses_amount REAL NOT NULL DEFAULT 0,
        total_amount REAL NOT NULL,
        payment_status TEXT NOT NULL DEFAULT 'unpaid',
        due_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients(id),
        FOREIGN KEY (declaration_id) REFERENCES declarations(id)
      )
    ''');

    // جدول المدفوعات
    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL,
        invoice_id TEXT,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        reference_number TEXT,
        payment_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients(id),
        FOREIGN KEY (invoice_id) REFERENCES invoices(id)
      )
    ''');

    // جدول الصندوق
    await db.execute('''
      CREATE TABLE fund_transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        reference_type TEXT,
        reference_id TEXT,
        transaction_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // جدول المصروفات
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        payment_method TEXT,
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // جدول الإيرادات
    await db.execute('''
      CREATE TABLE revenues (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        source TEXT,
        revenue_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // جدول الحسابات البنكية
    await db.execute('''
      CREATE TABLE bank_accounts (
        id TEXT PRIMARY KEY,
        bank_name TEXT NOT NULL,
        account_number TEXT NOT NULL,
        account_name TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'YER',
        balance REAL NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // جدول المعاملات البنكية
    await db.execute('''
      CREATE TABLE bank_transactions (
        id TEXT PRIMARY KEY,
        bank_account_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        reference_number TEXT,
        transaction_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(id)
      )
    ''');

    // جدول المستندات
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        declaration_id TEXT NOT NULL,
        document_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_extension TEXT,
        file_size INTEGER,
        notes TEXT,
        uploaded_at TEXT NOT NULL,
        FOREIGN KEY (declaration_id) REFERENCES declarations(id) ON DELETE CASCADE
      )
    ''');

    // جدول الاشتراكات
    await db.execute('''
      CREATE TABLE subscriptions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        plan_type TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // جدول الإشعارات
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        reference_type TEXT,
        reference_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // إدخال البيانات الافتراضية
    await _insertDefaultData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS office_settings (
          id INTEGER PRIMARY KEY,
          office_name TEXT NOT NULL,
          license_number TEXT,
          tax_number TEXT,
          phone TEXT,
          email TEXT,
          address TEXT,
          logo_path TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS representatives (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT,
          id_number TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS customs_centers (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          code TEXT,
          location TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS fee_categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS item_fee_rules (
          id TEXT PRIMARY KEY,
          hs_code TEXT NOT NULL,
          item_name TEXT NOT NULL,
          relative_fees_json TEXT,
          fixed_fees_json TEXT,
          total_fees REAL NOT NULL,
          last_used_date TEXT NOT NULL,
          usage_count INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');

      await _addColumnIfMissing(db, 'declarations', 'customs_center_id', 'TEXT');
      await _addColumnIfMissing(db, 'declarations', 'customs_center_name', 'TEXT');
      await _addColumnIfMissing(db, 'declarations', 'representative_id', 'TEXT');
      await _addColumnIfMissing(db, 'declarations', 'office_name', 'TEXT');
      await _addColumnIfMissing(db, 'relative_fees', 'category_id', 'TEXT');
      await _addColumnIfMissing(db, 'relative_fees', 'hs_code_filter', 'TEXT');
      await _addColumnIfMissing(db, 'fixed_fees', 'category_id', 'TEXT');
      await _addColumnIfMissing(db, 'fixed_fees', 'hs_code_filter', 'TEXT');
      await _addColumnIfMissing(db, 'fixed_fees', 'unit', "TEXT DEFAULT 'YER'");

      await _insertV2DefaultData(db);
    }

    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'declaration_items', 'package_type', 'TEXT');
      await _addColumnIfMissing(db, 'declaration_items', 'packages_count', 'INTEGER');
      await _addColumnIfMissing(db, 'declaration_items', 'gross_weight', 'REAL');
      await _addColumnIfMissing(db, 'declaration_items', 'net_weight', 'REAL');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS offices (
          id TEXT PRIMARY KEY,
          office_name TEXT NOT NULL,
          license_key TEXT NOT NULL UNIQUE,
          license_number TEXT,
          tax_number TEXT,
          phone TEXT,
          email TEXT,
          address TEXT,
          max_users INTEGER NOT NULL DEFAULT 5,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS office_subscriptions (
          id TEXT PRIMARY KEY,
          office_id TEXT NOT NULL UNIQUE,
          plan_type TEXT NOT NULL DEFAULT 'trial',
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'active',
          max_users INTEGER NOT NULL DEFAULT 5,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (office_id) REFERENCES offices(id)
        )
      ''');

      await _addColumnIfMissing(db, 'declarations', 'representative_name', 'TEXT');
      await _addColumnIfMissing(db, 'declarations', 'vessel_name', 'TEXT');
      await _addColumnIfMissing(db, 'declarations', 'total_packages', 'INTEGER');
      await _addColumnIfMissing(db, 'declarations', 'total_gross_weight', 'REAL');
      await _addColumnIfMissing(db, 'declarations', 'total_net_weight', 'REAL');
      await _addColumnIfMissing(db, 'declaration_items', 'local_value', 'REAL');

      await _insertV4DefaultData(db);
    }

    // ⭐══════════ إضافة جداول HS Code الجديدة ══════════⭐
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hs_code_categories (
          id TEXT PRIMARY KEY,
          category_code TEXT NOT NULL UNIQUE,
          category_name TEXT NOT NULL,
          description TEXT,
          default_relative_fees_json TEXT,
          default_fixed_fees_json TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS hs_code_fee_rules (
          id TEXT PRIMARY KEY,
          hs_code TEXT NOT NULL,
          hs_code_category TEXT,
          item_type TEXT,
          relative_fees_json TEXT NOT NULL,
          fixed_fees_json TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await _insertHsCodeDefaultData(db);
    }
    // ⭐══════════ نهاية إضافة HS Code ══════════⭐
  }

  Future<void> _addColumnIfMissing(Database db, String table, String column, String type) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> _insertDefaultData(Database db) async {
    final now = DateTime.now().toIso8601String();

    await db.insert('users', {
      'id': 'admin-001',
      'username': 'admin',
      'password': 'admin123',
      'full_name': 'مدير النظام',
      'role': 'super_admin',
      'email': 'admin@customs.app',
      'phone': '775477377',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    final defaultRelativeFees = [
      {'code': 'ST', 'name': 'ضريبة المبيعات', 'rate': 5.0, 'base': 'invoice_value', 'order': 1},
      {'code': 'VAT', 'name': 'ضريبة القيمة المضافة', 'rate': 5.0, 'base': 'after_st', 'order': 2},
      {'code': 'PT', 'name': 'ضريبة أرباح تجارية', 'rate': 2.5, 'base': 'invoice_value', 'order': 3},
      {'code': 'TEF', 'name': 'رسم تنمية الصادرات', 'rate': 1.0, 'base': 'invoice_value', 'order': 4},
      {'code': '04', 'name': 'رسم إضافي 4%', 'rate': 4.0, 'base': 'invoice_value', 'order': 5},
    ];

    for (final fee in defaultRelativeFees) {
      await db.insert('relative_fees', {
        'id': 'fee-${fee['code']}',
        'code': fee['code'],
        'name': fee['name'],
        'category_id': null,
        'rate': fee['rate'],
        'calculation_base': fee['base'],
        'hs_code_filter': null,
        'execution_order': fee['order'],
        'effective_date': '2024-01-01',
        'is_active': 1,
        'created_at': now,
      });
    }

    final defaultFixedFees = [
      {'code': 'SEAL', 'name': 'رسوم السيل', 'amount': 5000},
      {'code': 'SPECS', 'name': 'رسوم هيئة المواصفات والمقاييس', 'amount': 10000},
      {'code': 'TRANSPORT', 'name': 'رسوم هيئة تنظيم شؤون النقل البري', 'amount': 7500},
      {'code': 'MESSAGES', 'name': 'رسوم الرسائل', 'amount': 3000},
      {'code': 'EXTRA', 'name': 'الأجور الإضافية', 'amount': 5000},
    ];

    for (final fee in defaultFixedFees) {
      await db.insert('fixed_fees', {
        'id': 'fix-${fee['code']}',
        'code': fee['code'],
        'name': fee['name'],
        'category_id': null,
        'amount': fee['amount'],
        'unit': 'YER',
        'hs_code_filter': null,
        'description': '',
        'effective_date': '2024-01-01',
        'is_active': 1,
        'created_at': now,
      });
    }

    await db.insert('exchange_rates', {
      'id': 'rate-001',
      'currency_from': 'USD',
      'currency_to': 'YER',
      'rate': 1250.0,
      'effective_date': '2024-01-01',
      'created_at': now,
    });

    // مكتب افتراضي
    await db.insert('offices', {
      'id': 'office-001',
      'office_name': 'مكتب التخليص الجمركي',
      'license_key': 'CUSTOMS-2024-XXXX-XXXX',
      'license_number': '',
      'tax_number': '',
      'phone': '775477377',
      'email': '',
      'address': 'الجمهورية اليمنية',
      'max_users': 5,
      'created_at': now,
      'updated_at': now,
    });

    // اشتراك تجريبي
    await db.insert('office_subscriptions', {
      'id': 'sub-001',
      'office_id': 'office-001',
      'plan_type': 'trial',
      'start_date': now,
      'end_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'status': 'active',
      'max_users': 5,
      'notes': 'اشتراك تجريبي',
      'created_at': now,
      'updated_at': now,
    });

    // مراكز جمركية
    final centers = [
      'ميناء عدن', 'ميناء الحديدة', 'ميناء المكلا', 'ميناء المخا',
      'ميناء نشطون', 'منفذ الوديعة', 'منفذ شحن', 'منفذ حرض',
    ];
    for (int i = 0; i < centers.length; i++) {
      await db.insert('customs_centers', {
        'id': 'center-${i + 1}',
        'name': centers[i],
        'code': 'CUS${(i + 1).toString().padLeft(3, '0')}',
        'location': 'الجمهورية اليمنية',
        'is_active': 1,
        'created_at': now,
      });
    }

    // إدخال تصنيفات HS Code الافتراضية
    await _insertHsCodeDefaultData(db);
  }

  Future<void> _insertV2DefaultData(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    final centers = [
      'ميناء عدن', 'ميناء الحديدة', 'ميناء المكلا', 'ميناء المخا',
      'ميناء نشطون', 'منفذ الوديعة', 'منفذ شحن', 'منفذ حرض',
    ];
    for (int i = 0; i < centers.length; i++) {
      try {
        await db.insert('customs_centers', {
          'id': 'center-${i + 1}',
          'name': centers[i],
          'code': 'CUS${(i + 1).toString().padLeft(3, '0')}',
          'location': 'الجمهورية اليمنية',
          'is_active': 1,
          'created_at': now,
        });
      } catch (_) {}
    }
  }

  Future<void> _insertV4DefaultData(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    try {
      await db.insert('offices', {
        'id': 'office-001',
        'office_name': 'مكتب التخليص الجمركي',
        'license_key': 'CUSTOMS-2024-XXXX-XXXX',
        'license_number': '',
        'tax_number': '',
        'phone': '775477377',
        'email': '',
        'address': 'الجمهورية اليمنية',
        'max_users': 5,
        'created_at': now,
        'updated_at': now,
      });
    } catch (_) {}

    try {
      await db.insert('office_subscriptions', {
        'id': 'sub-001',
        'office_id': 'office-001',
        'plan_type': 'trial',
        'start_date': now,
        'end_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'status': 'active',
        'max_users': 5,
        'notes': 'اشتراك تجريبي',
        'created_at': now,
        'updated_at': now,
      });
    } catch (_) {}
  }

  // ⭐══════════ دالة إدخال تصنيفات HS Code الافتراضية ══════════⭐
  Future<void> _insertHsCodeDefaultData(Database db) async {
    final now = DateTime.now().toIso8601String();

    final defaultCategories = [
      {
        'category_code': '8471',
        'category_name': 'أجهزة كمبيوتر وملحقاتها',
        'description': 'أجهزة معالجة آلية للبيانات ووحداتها',
        'relative_fees': [
          {'code': 'CUSTOMS_DUTY', 'name': 'الرسم الجمركي', 'rate': 0, 'calculation_base': 'invoice_value', 'execution_order': 1},
          {'code': 'ST', 'name': 'ضريبة المبيعات', 'rate': 5, 'calculation_base': 'after_duty', 'execution_order': 2},
        ],
        'fixed_fees': [
          {'code': 'SEAL', 'name': 'رسوم السيل', 'amount': 5000},
        ],
      },
      {
        'category_code': '2402',
        'category_name': 'سجائر ومنتجات تبغ',
        'description': 'سيجار وسيجاريللو وسجائر من تبغ أو أبدال تبغ',
        'relative_fees': [
          {'code': 'CUSTOMS_DUTY', 'name': 'الرسم الجمركي', 'rate': 100, 'calculation_base': 'invoice_value', 'execution_order': 1},
          {'code': 'ST', 'name': 'ضريبة المبيعات', 'rate': 5, 'calculation_base': 'after_duty', 'execution_order': 2},
          {'code': 'TOBACCO_TAX', 'name': 'ضريبة التبغ الإضافية', 'rate': 50, 'calculation_base': 'after_st', 'execution_order': 3},
        ],
        'fixed_fees': [
          {'code': 'SEAL', 'name': 'رسوم السيل', 'amount': 5000},
          {'code': 'SPECS', 'name': 'رسوم المواصفات', 'amount': 10000},
        ],
      },
      {
        'category_code': '8703',
        'category_name': 'سيارات ومركبات',
        'description': 'سيارات ركوب وأنواع أخرى من مركبات نقل الأشخاص',
        'relative_fees': [
          {'code': 'CUSTOMS_DUTY', 'name': 'الرسم الجمركي', 'rate': 25, 'calculation_base': 'invoice_value', 'execution_order': 1},
          {'code': 'ST', 'name': 'ضريبة المبيعات', 'rate': 5, 'calculation_base': 'after_duty', 'execution_order': 2},
          {'code': 'LUXURY_TAX', 'name': 'ضريبة رفاهية', 'rate': 10, 'calculation_base': 'after_st', 'execution_order': 3},
        ],
        'fixed_fees': [
          {'code': 'SEAL', 'name': 'رسوم السيل', 'amount': 5000},
          {'code': 'TRANSPORT', 'name': 'رسوم النقل', 'amount': 7500},
          {'code': 'SPECS', 'name': 'رسوم المواصفات', 'amount': 15000},
        ],
      },
      {
        'category_code': '1006',
        'category_name': 'أرز',
        'description': 'أرز بجميع أنواعه',
        'relative_fees': [
          {'code': 'CUSTOMS_DUTY', 'name': 'الرسم الجمركي', 'rate': 10, 'calculation_base': 'invoice_value', 'execution_order': 1},
          {'code': 'ST', 'name': 'ضريبة المبيعات', 'rate': 5, 'calculation_base': 'after_duty', 'execution_order': 2},
        ],
        'fixed_fees': [
          {'code': 'SEAL', 'name': 'رسوم السيل', 'amount': 5000},
          {'code': 'SPECS', 'name': 'رسوم المواصفات', 'amount': 10000},
        ],
      },
      {
        'category_code': '0402',
        'category_name': 'حليب ومشتقاته',
        'description': 'حليب وقشدة مركزة أو محلاة',
        'relative_fees': [
          {'code': 'CUSTOMS_DUTY', 'name': 'الرسم الجمركي', 'rate': 15, 'calculation_base': 'invoice_value', 'execution_order': 1},
          {'code': 'ST', 'name': 'ضريبة المبيعات', 'rate': 5, 'calculation_base': 'after_duty', 'execution_order': 2},
        ],
        'fixed_fees': [
          {'code': 'SEAL', 'name': 'رسوم السيل', 'amount': 5000},
          {'code': 'SPECS', 'name': 'رسوم المواصفات', 'amount': 12000},
        ],
      },
    ];

    for (final cat in defaultCategories) {
      try {
        await db.insert('hs_code_categories', {
          'id': 'hscat-${cat['category_code']}',
          'category_code': cat['category_code'],
          'category_name': cat['category_name'],
          'description': cat['description'],
          'default_relative_fees_json': jsonEncode(cat['relative_fees']),
          'default_fixed_fees_json': jsonEncode(cat['fixed_fees']),
          'is_active': 1,
          'created_at': now,
        });
      } catch (_) {
        // التجاهل إذا كان التصنيف موجوداً مسبقاً
      }
    }
  }
}

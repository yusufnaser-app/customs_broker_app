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
Future<void> _insertTariffData(Database db) async {
  final tariffItems = [
    // ===== حبوب =====
    {'code': '10010000', 'name': 'قمح', 'category': 'حبوب'},
    {'code': '10020000', 'name': 'أرز', 'category': 'حبوب'},
    {'code': '10030000', 'name': 'شعير', 'category': 'حبوب'},
    {'code': '10040000', 'name': 'ذرة', 'category': 'حبوب'},
    {'code': '10050000', 'name': 'دخن', 'category': 'حبوب'},
    {'code': '10060000', 'name': 'شوفان', 'category': 'حبوب'},
    {'code': '10070000', 'name': 'حنطة سوداء', 'category': 'حبوب'},
    {'code': '10080000', 'name': 'كسكس', 'category': 'حبوب'},
    {'code': '10090000', 'name': 'ذرة صفراء', 'category': 'حبوب'},
    {'code': '10100000', 'name': 'ذرة بيضاء', 'category': 'حبوب'},
    {'code': '10110000', 'name': 'حبوب كاملة', 'category': 'حبوب'},
    {'code': '10120000', 'name': 'حبوب معالجة', 'category': 'حبوب'},
    {'code': '10130000', 'name': 'حبوب مطحونة', 'category': 'حبوب'},
    {'code': '10140000', 'name': 'حبوب مجففة', 'category': 'حبوب'},
    {'code': '10150000', 'name': 'حبوب معلبة', 'category': 'حبوب'},
    {'code': '10160000', 'name': 'حبوب جاهزة للأكل', 'category': 'حبوب'},
    {'code': '10170000', 'name': 'حبوب عضوية', 'category': 'حبوب'},
    {'code': '10180000', 'name': 'حبوب مستوردة', 'category': 'حبوب'},
    {'code': '10190000', 'name': 'حبوب محلية', 'category': 'حبوب'},
    {'code': '10200000', 'name': 'حبوب متنوعة', 'category': 'حبوب'},
    // ===== بذور وبقوليات =====
    {'code': '12010000', 'name': 'فول الصويا', 'category': 'بذور وبقوليات'},
    {'code': '12020000', 'name': 'سمسم', 'category': 'بذور وبقوليات'},
    {'code': '12030000', 'name': 'حمص', 'category': 'بذور وبقوليات'},
    {'code': '12040000', 'name': 'عدس', 'category': 'بذور وبقوليات'},
    {'code': '12050000', 'name': 'فول', 'category': 'بذور وبقوليات'},
    {'code': '12060000', 'name': 'بازلاء', 'category': 'بذور وبقوليات'},
    {'code': '12070000', 'name': 'فاصوليا', 'category': 'بذور وبقوليات'},
    {'code': '12080000', 'name': 'بذور كتان', 'category': 'بذور وبقوليات'},
    {'code': '12090000', 'name': 'بذور دوار الشمس', 'category': 'بذور وبقوليات'},
    {'code': '12100000', 'name': 'بذور قرع', 'category': 'بذور وبقوليات'},
    {'code': '12110000', 'name': 'بذور خردل', 'category': 'بذور وبقوليات'},
    {'code': '12120000', 'name': 'بذور قطن', 'category': 'بذور وبقوليات'},
    {'code': '12130000', 'name': 'بذور نباتية أخرى', 'category': 'بذور وبقوليات'},
    {'code': '12140000', 'name': 'بذور معالجة', 'category': 'بذور وبقوليات'},
    {'code': '12150000', 'name': 'بذور متنوعة', 'category': 'بذور وبقوليات'},
    // ===== زيوت ودهون =====
    {'code': '15010000', 'name': 'زيت الزيتون', 'category': 'زيوت ودهون'},
    {'code': '15020000', 'name': 'زيت النخيل', 'category': 'زيوت ودهون'},
    {'code': '15030000', 'name': 'زيت دوار الشمس', 'category': 'زيوت ودهون'},
    {'code': '15040000', 'name': 'زيت فول الصويا', 'category': 'زيوت ودهون'},
    {'code': '15050000', 'name': 'زبدة', 'category': 'زيوت ودهون'},
    {'code': '15060000', 'name': 'سمن نباتي', 'category': 'زيوت ودهون'},
    {'code': '15070000', 'name': 'زيت جوز الهند', 'category': 'زيوت ودهون'},
    {'code': '15080000', 'name': 'زيت الكتان', 'category': 'زيوت ودهون'},
    {'code': '15090000', 'name': 'زيت السمسم', 'category': 'زيوت ودهون'},
    {'code': '15100000', 'name': 'زيت الذرة', 'category': 'زيوت ودهون'},
    {'code': '15110000', 'name': 'زيت عباد الشمس', 'category': 'زيوت ودهون'},
    {'code': '15120000', 'name': 'زيت بذور القطن', 'category': 'زيوت ودهون'},
    {'code': '15130000', 'name': 'زيوت معالجة', 'category': 'زيوت ودهون'},
    {'code': '15140000', 'name': 'زيوت متنوعة', 'category': 'زيوت ودهون'},
    {'code': '15150000', 'name': 'دهون حيوانية', 'category': 'زيوت ودهون'},
    // ===== سكر وكاكاو =====
    {'code': '17010000', 'name': 'سكر قصب', 'category': 'سكر وكاكاو'},
    {'code': '17020000', 'name': 'سكر بنجر', 'category': 'سكر وكاكاو'},
    {'code': '17030000', 'name': 'شوكولاتة', 'category': 'سكر وكاكاو'},
    {'code': '17040000', 'name': 'كاكاو خام', 'category': 'سكر وكاكاو'},
    {'code': '17050000', 'name': 'كاكاو مسحوق', 'category': 'سكر وكاكاو'},
    {'code': '17060000', 'name': 'كاكاو معالج', 'category': 'سكر وكاكاو'},
    {'code': '17070000', 'name': 'حلويات', 'category': 'سكر وكاكاو'},
    {'code': '17080000', 'name': 'سكر مكرر', 'category': 'سكر وكاكاو'},
    {'code': '17090000', 'name': 'سكر بني', 'category': 'سكر وكاكاو'},
    {'code': '17100000', 'name': 'سكر أبيض', 'category': 'سكر وكاكاو'},
    // ===== مشروبات =====
    {'code': '22010000', 'name': 'مياه معدنية', 'category': 'مشروبات'},
    {'code': '22020000', 'name': 'مشروبات غازية', 'category': 'مشروبات'},
    {'code': '22030000', 'name': 'عصائر فواكه', 'category': 'مشروبات'},
    {'code': '22040000', 'name': 'شاي', 'category': 'مشروبات'},
    {'code': '22050000', 'name': 'قهوة', 'category': 'مشروبات'},
    {'code': '22060000', 'name': 'مشروبات طاقة', 'category': 'مشروبات'},
    {'code': '22070000', 'name': 'مشروبات رياضية', 'category': 'مشروبات'},
    {'code': '22080000', 'name': 'مشروبات عشبية', 'category': 'مشروبات'},
    {'code': '22090000', 'name': 'مشروبات كحولية', 'category': 'مشروبات'},
    {'code': '22100000', 'name': 'مشروبات متنوعة', 'category': 'مشروبات'},
    {'code': '22110000', 'name': 'مشروبات معلبة', 'category': 'مشروبات'},
    {'code': '22120000', 'name': 'مشروبات مجففة', 'category': 'مشروبات'},
    {'code': '22130000', 'name': 'مشروبات مركزة', 'category': 'مشروبات'},
    {'code': '22140000', 'name': 'مشروبات ساخنة جاهزة', 'category': 'مشروبات'},
    {'code': '22150000', 'name': 'مشروبات باردة جاهزة', 'category': 'مشروبات'},
    // ===== تبغ =====
    {'code': '24010000', 'name': 'تبغ خام', 'category': 'تبغ'},
    {'code': '24020000', 'name': 'سجائر', 'category': 'تبغ'},
    {'code': '24030000', 'name': 'سيجار', 'category': 'تبغ'},
    {'code': '24040000', 'name': 'تبغ معسل', 'category': 'تبغ'},
    {'code': '24050000', 'name': 'منتجات تبغ أخرى', 'category': 'تبغ'},
    // ===== معادن وطاقة =====
    {'code': '27010000', 'name': 'نفط خام', 'category': 'معادن وطاقة'},
    {'code': '27020000', 'name': 'غاز طبيعي', 'category': 'معادن وطاقة'},
    {'code': '27030000', 'name': 'فحم', 'category': 'معادن وطاقة'},
    {'code': '27040000', 'name': 'يورانيوم', 'category': 'معادن وطاقة'},
    {'code': '27050000', 'name': 'زيت مكرر', 'category': 'معادن وطاقة'},
    {'code': '27060000', 'name': 'منتجات بترولية', 'category': 'معادن وطاقة'},
    {'code': '27070000', 'name': 'غاز مسال', 'category': 'معادن وطاقة'},
    {'code': '27080000', 'name': 'زيوت تشحيم', 'category': 'معادن وطاقة'},
    {'code': '27090000', 'name': 'وقود طائرات', 'category': 'معادن وطاقة'},
    {'code': '27100000', 'name': 'وقود ديزل', 'category': 'معادن وطاقة'},
    {'code': '27110000', 'name': 'وقود بنزين', 'category': 'معادن وطاقة'},
    {'code': '27120000', 'name': 'منتجات طاقة أخرى', 'category': 'معادن وطاقة'},
    {'code': '27130000', 'name': 'معادن خام', 'category': 'معادن وطاقة'},
    {'code': '27140000', 'name': 'معادن مصنعة أولية', 'category': 'معادن وطاقة'},
    {'code': '27150000', 'name': 'مخلفات طاقة', 'category': 'معادن وطاقة'},
    // ===== مواد كيميائية =====
    {'code': '28010000', 'name': 'هيدروجين', 'category': 'مواد كيميائية'},
    {'code': '28020000', 'name': 'أمونيا', 'category': 'مواد كيميائية'},
    {'code': '28030000', 'name': 'أسيتون', 'category': 'مواد كيميائية'},
    {'code': '28040000', 'name': 'ميثانول', 'category': 'مواد كيميائية'},
    {'code': '28050000', 'name': 'مذيبات عضوية', 'category': 'مواد كيميائية'},
    {'code': '28060000', 'name': 'أحماض عضوية', 'category': 'مواد كيميائية'},
    {'code': '28070000', 'name': 'أحماض غير عضوية', 'category': 'مواد كيميائية'},
    {'code': '28080000', 'name': 'أسمدة كيميائية خام', 'category': 'مواد كيميائية'},
    {'code': '28090000', 'name': 'مبيدات حشرية', 'category': 'مواد كيميائية'},
    {'code': '28100000', 'name': 'بوليمرات خام', 'category': 'مواد كيميائية'},
    {'code': '28110000', 'name': 'مواد لاصقة', 'category': 'مواد كيميائية'},
    {'code': '28120000', 'name': 'مواد تنظيف صناعية', 'category': 'مواد كيميائية'},
    {'code': '28130000', 'name': 'مواد تبييض', 'category': 'مواد كيميائية'},
    {'code': '28140000', 'name': 'مواد طلاء', 'category': 'مواد كيميائية'},
    {'code': '28150000', 'name': 'مواد معالجة مياه', 'category': 'مواد كيميائية'},
    {'code': '28160000', 'name': 'مواد كيميائية خاصة', 'category': 'مواد كيميائية'},
    {'code': '28170000', 'name': 'مواد كيميائية دوائية', 'category': 'مواد كيميائية'},
    {'code': '28180000', 'name': 'مواد كيميائية بلاستيكية', 'category': 'مواد كيميائية'},
    {'code': '28190000', 'name': 'مواد كيميائية زراعية', 'category': 'مواد كيميائية'},
    {'code': '28200000', 'name': 'مواد كيميائية متنوعة', 'category': 'مواد كيميائية'},
    // ===== أدوية وأسمدة =====
    {'code': '30010000', 'name': 'مضادات حيوية', 'category': 'أدوية وأسمدة'},
    {'code': '30020000', 'name': 'أسمدة نيتروجينية', 'category': 'أدوية وأسمدة'},
    {'code': '30030000', 'name': 'أسمدة فوسفاتية', 'category': 'أدوية وأسمدة'},
    {'code': '30040000', 'name': 'أسمدة بوتاسية', 'category': 'أدوية وأسمدة'},
    {'code': '30050000', 'name': 'مستحضرات طبية بشرية', 'category': 'أدوية وأسمدة'},
    {'code': '30060000', 'name': 'مستحضرات طبية بيطرية', 'category': 'أدوية وأسمدة'},
    {'code': '30070000', 'name': 'مستلزمات طبية بسيطة', 'category': 'أدوية وأسمدة'},
    {'code': '30080000', 'name': 'مستحضرات صيدلانية أخرى', 'category': 'أدوية وأسمدة'},
    {'code': '30090000', 'name': 'مركبات دوائية خام', 'category': 'أدوية وأسمدة'},
    {'code': '30100000', 'name': 'منتجات صيدلانية متنوعة', 'category': 'أدوية وأسمدة'},
    // ===== منسوجات وملابس =====
    {'code': '52010000', 'name': 'قطن خام', 'category': 'منسوجات وملابس'},
    {'code': '52020000', 'name': 'صوف', 'category': 'منسوجات وملابس'},
    {'code': '52030000', 'name': 'حرير خام', 'category': 'منسوجات وملابس'},
    {'code': '52040000', 'name': 'ألياف صناعية', 'category': 'منسوجات وملابس'},
    {'code': '52050000', 'name': 'خيوط قطنية', 'category': 'منسوجات وملابس'},
    {'code': '52060000', 'name': 'أقمشة قطنية', 'category': 'منسوجات وملابس'},
    {'code': '52070000', 'name': 'أقمشة صوفية', 'category': 'منسوجات وملابس'},
    {'code': '52080000', 'name': 'أقمشة حريرية', 'category': 'منسوجات وملابس'},
    {'code': '52090000', 'name': 'أقمشة صناعية', 'category': 'منسوجات وملابس'},
    {'code': '52100000', 'name': 'ملابس جاهزة', 'category': 'منسوجات وملابس'},
    {'code': '52110000', 'name': 'ملابس داخلية', 'category': 'منسوجات وملابس'},
    {'code': '52120000', 'name': 'ملابس أطفال', 'category': 'منسوجات وملابس'},
    {'code': '52130000', 'name': 'ملابس عمل', 'category': 'منسوجات وملابس'},
    {'code': '52140000', 'name': 'ملابس رياضية', 'category': 'منسوجات وملابس'},
    {'code': '52150000', 'name': 'ملابس واقية', 'category': 'منسوجات وملابس'},
    {'code': '52160000', 'name': 'منسوجات منزلية', 'category': 'منسوجات وملابس'},
    {'code': '52170000', 'name': 'ستائر ونسيج منزلي', 'category': 'منسوجات وملابس'},
    {'code': '52180000', 'name': 'منسوجات طبية', 'category': 'منسوجات وملابس'},
    {'code': '52190000', 'name': 'منسوجات صناعية', 'category': 'منسوجات وملابس'},
    {'code': '52200000', 'name': 'منسوجات متنوعة', 'category': 'منسوجات وملابس'},
    // ===== أحذية =====
    {'code': '64010000', 'name': 'أحذية جلدية', 'category': 'أحذية'},
    {'code': '64020000', 'name': 'أحذية مطاطية', 'category': 'أحذية'},
    {'code': '64030000', 'name': 'أحذية رياضية', 'category': 'أحذية'},
    {'code': '64040000', 'name': 'أحذية أطفال', 'category': 'أحذية'},
    {'code': '64050000', 'name': 'أحذية متنوعة', 'category': 'أحذية'},
    // ===== زجاج وسيراميك =====
    {'code': '70010000', 'name': 'زجاج خام', 'category': 'زجاج'},
    {'code': '70020000', 'name': 'زجاج مصقول', 'category': 'زجاج'},
    {'code': '70030000', 'name': 'زجاج معزول', 'category': 'زجاج'},
    {'code': '70040000', 'name': 'زجاج معالج', 'category': 'زجاج'},
    {'code': '69010000', 'name': 'بلاط سيراميك خام', 'category': 'سيراميك'},
    {'code': '69020000', 'name': 'بلاط سيراميك مصقول', 'category': 'سيراميك'},
    {'code': '69030000', 'name': 'خزف', 'category': 'سيراميك'},
    {'code': '69040000', 'name': 'أواني خزفية', 'category': 'سيراميك'},
    {'code': '69050000', 'name': 'بلاط زجاجي', 'category': 'سيراميك'},
    {'code': '69060000', 'name': 'منتجات سيراميكية متنوعة', 'category': 'سيراميك'},
    // ===== معادن مصنعة =====
    {'code': '72010000', 'name': 'فولاذ', 'category': 'معادن مصنعة'},
    {'code': '72020000', 'name': 'فولاذ معالج', 'category': 'معادن مصنعة'},
    {'code': '73010000', 'name': 'حديد مسبوك', 'category': 'معادن مصنعة'},
    {'code': '74010000', 'name': 'نحاس', 'category': 'معادن مصنعة'},
    {'code': '74020000', 'name': 'نحاس معالج', 'category': 'معادن مصنعة'},
    {'code': '75010000', 'name': 'رصاص', 'category': 'معادن مصنعة'},
    {'code': '76010000', 'name': 'ألمنيوم', 'category': 'معادن مصنعة'},
    {'code': '76020000', 'name': 'ألمنيوم معالج', 'category': 'معادن مصنعة'},
    {'code': '77010000', 'name': 'زنك', 'category': 'معادن مصنعة'},
    {'code': '77990000', 'name': 'معادن مصنعة متنوعة', 'category': 'معادن مصنعة'},
    // ===== آلات ومعدات =====
    {'code': '84010000', 'name': 'محركات كهربائية', 'category': 'آلات ومعدات'},
    {'code': '84020000', 'name': 'محركات ديزل', 'category': 'آلات ومعدات'},
    {'code': '84030000', 'name': 'مولدات كهربائية', 'category': 'آلات ومعدات'},
    {'code': '84040000', 'name': 'مضخات ومعدات ضخ', 'category': 'آلات ومعدات'},
    {'code': '84050000', 'name': 'ضواغط هواء', 'category': 'آلات ومعدات'},
    {'code': '84060000', 'name': 'آلات تصنيع', 'category': 'آلات ومعدات'},
    {'code': '84070000', 'name': 'آلات تعبئة وتغليف', 'category': 'آلات ومعدات'},
    {'code': '84080000', 'name': 'آلات زراعية', 'category': 'آلات ومعدات'},
    {'code': '84090000', 'name': 'آلات بناء', 'category': 'آلات ومعدات'},
    {'code': '84100000', 'name': 'آلات طباعة', 'category': 'آلات ومعدات'},
    {'code': '84110000', 'name': 'آلات معالجة المعادن', 'category': 'آلات ومعدات'},
    {'code': '84120000', 'name': 'آلات معالجة الأخشاب', 'category': 'آلات ومعدات'},
    {'code': '84130000', 'name': 'معدات تبريد صناعي', 'category': 'آلات ومعدات'},
    {'code': '84140000', 'name': 'معدات تسخين صناعي', 'category': 'آلات ومعدات'},
    {'code': '84150000', 'name': 'معدات صناعية متنوعة', 'category': 'آلات ومعدات'},
    // ===== وسائل نقل =====
    {'code': '87010000', 'name': 'سيارات ركوب', 'category': 'وسائل نقل'},
    {'code': '87020000', 'name': 'شاحنات', 'category': 'وسائل نقل'},
    {'code': '87030000', 'name': 'حافلات', 'category': 'وسائل نقل'},
    {'code': '87040000', 'name': 'دراجات نارية', 'category': 'وسائل نقل'},
    {'code': '87050000', 'name': 'دراجات هوائية', 'category': 'وسائل نقل'},
    {'code': '88010000', 'name': 'مركبات سكك حديدية', 'category': 'وسائل نقل'},
    {'code': '88020000', 'name': 'طائرات ركاب', 'category': 'وسائل نقل'},
    {'code': '88030000', 'name': 'طائرات شحن', 'category': 'وسائل نقل'},
    {'code': '88040000', 'name': 'مروحيات', 'category': 'وسائل نقل'},
    {'code': '89010000', 'name': 'سفن شحن', 'category': 'وسائل نقل'},
    {'code': '89020000', 'name': 'قوارب صيد', 'category': 'وسائل نقل'},
    {'code': '89030000', 'name': 'يخوت', 'category': 'وسائل نقل'},
    {'code': '89100000', 'name': 'مركبات خاصة', 'category': 'وسائل نقل'},
    {'code': '89200000', 'name': 'مكونات نقل', 'category': 'وسائل نقل'},
    {'code': '89300000', 'name': 'معدات نقل متنوعة', 'category': 'وسائل نقل'},
    // ===== إلكترونيات =====
    {'code': '90010000', 'name': 'أجهزة بصرية', 'category': 'إلكترونيات'},
    {'code': '90020000', 'name': 'كاميرات', 'category': 'إلكترونيات'},
    {'code': '90030000', 'name': 'معدات قياس', 'category': 'إلكترونيات'},
    {'code': '90100000', 'name': 'أجهزة طبية إلكترونية', 'category': 'إلكترونيات'},
    {'code': '85110000', 'name': 'أجهزة اتصالات', 'category': 'إلكترونيات'},
    {'code': '85120000', 'name': 'أجهزة حاسوب', 'category': 'إلكترونيات'},
    {'code': '85130000', 'name': 'هواتف محمولة', 'category': 'إلكترونيات'},
    {'code': '85140000', 'name': 'مكونات إلكترونية', 'category': 'إلكترونيات'},
    {'code': '85150000', 'name': 'شاشات عرض', 'category': 'إلكترونيات'},
    {'code': '85160000', 'name': 'أجهزة صوتية', 'category': 'إلكترونيات'},
    // ===== ألعاب =====
    {'code': '95010000', 'name': 'ألعاب خشبية', 'category': 'ألعاب'},
    {'code': '95020000', 'name': 'ألعاب إلكترونية', 'category': 'ألعاب'},
    {'code': '95030000', 'name': 'ألعاب تعليمية', 'category': 'ألعاب'},
    {'code': '95040000', 'name': 'ألعاب بلاستيكية', 'category': 'ألعاب'},
    {'code': '95050000', 'name': 'ألعاب خارجية', 'category': 'ألعاب'},
    {'code': '95060000', 'name': 'ألعاب رياضية', 'category': 'ألعاب'},
    {'code': '95070000', 'name': 'دمى', 'category': 'ألعاب'},
    {'code': '95080000', 'name': 'ألعاب تركيب', 'category': 'ألعاب'},
    {'code': '95090000', 'name': 'ألعاب لوحية', 'category': 'ألعاب'},
    {'code': '95100000', 'name': 'ألعاب متنوعة', 'category': 'ألعاب'},
    // ===== فن وأثاث =====
    {'code': '97010000', 'name': 'لوحات فنية', 'category': 'فن وأثاث'},
    {'code': '97020000', 'name': 'منحوتات', 'category': 'فن وأثاث'},
    {'code': '94010000', 'name': 'أثاث خشبي', 'category': 'فن وأثاث'},
    {'code': '94020000', 'name': 'أثاث معدني', 'category': 'فن وأثاث'},
    {'code': '94030000', 'name': 'أثاث منزلي', 'category': 'فن وأثاث'},
    {'code': '94040000', 'name': 'أثاث مكتبي', 'category': 'فن وأثاث'},
    {'code': '97030000', 'name': 'مطبوعات فنية', 'category': 'فن وأثاث'},
    {'code': '97040000', 'name': 'تحف فنية', 'category': 'فن وأثاث'},
    {'code': '97050000', 'name': 'قطع ديكور', 'category': 'فن وأثاث'},
    {'code': '97060000', 'name': 'أثاث متنوع', 'category': 'فن وأثاث'},
    // ===== أجهزة منزلية =====
    {'code': '85010000', 'name': 'أجهزة كهربائية منزلية صغيرة', 'category': 'أجهزة منزلية'},
    {'code': '85020000', 'name': 'أجهزة مطبخ', 'category': 'أجهزة منزلية'},
    {'code': '85030000', 'name': 'ثلاجات منزلية', 'category': 'أجهزة منزلية'},
    {'code': '85040000', 'name': 'غسالات', 'category': 'أجهزة منزلية'},
    {'code': '85050000', 'name': 'مكيفات هواء', 'category': 'أجهزة منزلية'},
    {'code': '85060000', 'name': 'أفران كهربائية', 'category': 'أجهزة منزلية'},
    {'code': '85070000', 'name': 'سخانات مياه', 'category': 'أجهزة منزلية'},
    {'code': '85080000', 'name': 'مكنسة كهربائية', 'category': 'أجهزة منزلية'},
    {'code': '85090000', 'name': 'أجهزة منزلية ذكية', 'category': 'أجهزة منزلية'},
    {'code': '85100000', 'name': 'أجهزة منزلية متنوعة', 'category': 'أجهزة منزلية'},
    // ===== معدات طبية =====
    {'code': '98110000', 'name': 'أجهزة موجات فوق صوتية', 'category': 'معدات طبية'},
    {'code': '98120000', 'name': 'أجهزة رنين مغناطيسي', 'category': 'معدات طبية'},
    {'code': '98130000', 'name': 'أجهزة أشعة', 'category': 'معدات طبية'},
    {'code': '98140000', 'name': 'أجهزة تخطيط القلب', 'category': 'معدات طبية'},
    {'code': '98150000', 'name': 'معدات جراحية', 'category': 'معدات طبية'},
    {'code': '98160000', 'name': 'معدات مختبرية', 'category': 'معدات طبية'},
    {'code': '98170000', 'name': 'مستلزمات طبية استهلاكية', 'category': 'معدات طبية'},
    {'code': '98180000', 'name': 'أجهزة تنفس صناعي', 'category': 'معدات طبية'},
    {'code': '98190000', 'name': 'معدات إعادة تأهيل', 'category': 'معدات طبية'},
    {'code': '98200000', 'name': 'معدات طبية متنوعة', 'category': 'معدات طبية'},
    // ===== متفرقات =====
    {'code': '99910000', 'name': 'منتجات موسمية', 'category': 'متفرقات'},
    {'code': '99920000', 'name': 'منتجات هدايا', 'category': 'متفرقات'},
    {'code': '99930000', 'name': 'منتجات مكتبية', 'category': 'متفرقات'},
    {'code': '99940000', 'name': 'منتجات تعليمية', 'category': 'متفرقات'},
    {'code': '99950000', 'name': 'منتجات تجميل', 'category': 'متفرقات'},
    {'code': '99960000', 'name': 'منتجات غذائية معلبة', 'category': 'متفرقات'},
    {'code': '99970000', 'name': 'منتجات منزلية متنوعة', 'category': 'متفرقات'},
    {'code': '99980000', 'name': 'قطع غيار متنوعة', 'category': 'متفرقات'},
    {'code': '99985000', 'name': 'خدمات مصاحبة للسلع', 'category': 'متفرقات'},
    {'code': '99990000', 'name': 'منتجات متنوعة أخرى', 'category': 'متفرقات'},
  ];

  for (final item in tariffItems) {
    try {
      await db.insert('tariff_items', item);
    } catch (_) {
      // تجاهل إذا كان موجوداً
    }
  }
}

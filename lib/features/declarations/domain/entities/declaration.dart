class Declaration {
  final String id;
  final String declarationNumber;
  final String? statementNumber;
  final String? statementDate;
  final String? statementType;
  final String? customsCenter;
  final String? customsCenterId;
  final String? customsCenterName;
  final String? representativeId;
  final String? representativeName;
  final String? officeName;
  final String? vesselName;
  final int? totalPackages;
  final double? totalGrossWeight;
  final double? totalNetWeight;
  final String clientId;
  final String? traderId;
  final String? supplierId;
  final String? originCountry;
  final String? exportCountry;
  final String? transportMethod;
  final String? containerNumber;
  final String? invoiceNumber;
  final String? invoiceDate;
  final double invoiceValueUsd;
  final String currency;
  final double exchangeRate;
  final int itemsCount;
  final String? notes;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? clientName;
  final String? traderName;
  final String? supplierName;

  const Declaration({
    required this.id,
    required this.declarationNumber,
    this.statementNumber,
    this.statementDate,
    this.statementType,
    this.customsCenter,
    this.customsCenterId,
    this.customsCenterName,
    this.representativeId,
    this.representativeName,
    this.officeName,
    this.vesselName,
    this.totalPackages,
    this.totalGrossWeight,
    this.totalNetWeight,
    required this.clientId,
    this.traderId,
    this.supplierId,
    this.originCountry,
    this.exportCountry,
    this.transportMethod,
    this.containerNumber,
    this.invoiceNumber,
    this.invoiceDate,
    required this.invoiceValueUsd,
    this.currency = 'USD',
    required this.exchangeRate,
    this.itemsCount = 0,
    this.notes,
    this.status = 'draft',
    required this.createdAt,
    required this.updatedAt,
    this.clientName,
    this.traderName,
    this.supplierName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'declaration_number': declarationNumber,
      'statement_number': statementNumber,
      'statement_date': statementDate,
      'statement_type': statementType,
      'customs_center': customsCenter,
      'customs_center_id': customsCenterId,
      'customs_center_name': customsCenterName,
      'representative_id': representativeId,
      'representative_name': representativeName,
      'office_name': officeName,
      'vessel_name': vesselName,
      'total_packages': totalPackages,
      'total_gross_weight': totalGrossWeight,
      'total_net_weight': totalNetWeight,
      'client_id': clientId,
      'trader_id': traderId,
      'supplier_id': supplierId,
      'origin_country': originCountry,
      'export_country': exportCountry,
      'transport_method': transportMethod,
      'container_number': containerNumber,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate,
      'invoice_value_usd': invoiceValueUsd,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'items_count': itemsCount,
      'notes': notes,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Declaration.fromMap(Map<String, dynamic> map, {String? clientName, String? traderName, String? supplierName}) {
    return Declaration(
      id: map['id'] ?? '',
      declarationNumber: map['declaration_number'] ?? '',
      statementNumber: map['statement_number'],
      statementDate: map['statement_date'],
      statementType: map['statement_type'],
      customsCenter: map['customs_center'],
      customsCenterId: map['customs_center_id'],
      customsCenterName: map['customs_center_name'],
      representativeId: map['representative_id'],
      representativeName: map['representative_name'],
      officeName: map['office_name'],
      vesselName: map['vessel_name'],
      totalPackages: map['total_packages'] as int?,
      totalGrossWeight: (map['total_gross_weight'] as num?)?.toDouble(),
      totalNetWeight: (map['total_net_weight'] as num?)?.toDouble(),
      clientId: map['client_id'] ?? '',
      traderId: map['trader_id'],
      supplierId: map['supplier_id'],
      originCountry: map['origin_country'],
      exportCountry: map['export_country'],
      transportMethod: map['transport_method'],
      containerNumber: map['container_number'],
      invoiceNumber: map['invoice_number'],
      invoiceDate: map['invoice_date'],
      invoiceValueUsd: (map['invoice_value_usd'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'USD',
      exchangeRate: (map['exchange_rate'] ?? 1250).toDouble(),
      itemsCount: map['items_count'] ?? 0,
      notes: map['notes'],
      status: map['status'] ?? 'draft',
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
      clientName: clientName,
      traderName: traderName,
      supplierName: supplierName,
    );
  }

  Declaration copyWith({
    String? id,
    String? declarationNumber,
    String? statementNumber,
    String? statementDate,
    String? statementType,
    String? customsCenter,
    String? customsCenterId,
    String? customsCenterName,
    String? representativeId,
    String? representativeName,
    String? officeName,
    String? vesselName,
    int? totalPackages,
    double? totalGrossWeight,
    double? totalNetWeight,
    String? clientId,
    String? traderId,
    String? supplierId,
    String? originCountry,
    String? exportCountry,
    String? transportMethod,
    String? containerNumber,
    String? invoiceNumber,
    String? invoiceDate,
    double? invoiceValueUsd,
    String? currency,
    double? exchangeRate,
    int? itemsCount,
    String? notes,
    String? status,
    String? createdAt,
    String? updatedAt,
    String? clientName,
    String? traderName,
    String? supplierName,
  }) {
    return Declaration(
      id: id ?? this.id,
      declarationNumber: declarationNumber ?? this.declarationNumber,
      statementNumber: statementNumber ?? this.statementNumber,
      statementDate: statementDate ?? this.statementDate,
      statementType: statementType ?? this.statementType,
      customsCenter: customsCenter ?? this.customsCenter,
      customsCenterId: customsCenterId ?? this.customsCenterId,
      customsCenterName: customsCenterName ?? this.customsCenterName,
      representativeId: representativeId ?? this.representativeId,
      representativeName: representativeName ?? this.representativeName,
      officeName: officeName ?? this.officeName,
      vesselName: vesselName ?? this.vesselName,
      totalPackages: totalPackages ?? this.totalPackages,
      totalGrossWeight: totalGrossWeight ?? this.totalGrossWeight,
      totalNetWeight: totalNetWeight ?? this.totalNetWeight,
      clientId: clientId ?? this.clientId,
      traderId: traderId ?? this.traderId,
      supplierId: supplierId ?? this.supplierId,
      originCountry: originCountry ?? this.originCountry,
      exportCountry: exportCountry ?? this.exportCountry,
      transportMethod: transportMethod ?? this.transportMethod,
      containerNumber: containerNumber ?? this.containerNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      invoiceValueUsd: invoiceValueUsd ?? this.invoiceValueUsd,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      itemsCount: itemsCount ?? this.itemsCount,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      clientName: clientName ?? this.clientName,
      traderName: traderName ?? this.traderName,
      supplierName: supplierName ?? this.supplierName,
    );
  }
}

class Product {
  final int id;
  final String name;
  final String displayName;
  final String defaultCode;
  final String barcode;
  final double listPrice;
  final double qtyAvailable;
  final String? image128;

  Product({
    required this.id,
    required this.name,
    required this.displayName,
    required this.defaultCode,
    required this.barcode,
    required this.listPrice,
    required this.qtyAvailable,
    this.image128,
  });

  factory Product.fromOdoo(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      defaultCode: (json['default_code'] is String) ? json['default_code'] : '',
      barcode: (json['barcode'] is String) ? json['barcode'] : '',
      listPrice: (json['list_price'] is num)
          ? (json['list_price'] as num).toDouble()
          : 0.0,
      qtyAvailable: (json['qty_available'] is num)
          ? (json['qty_available'] as num).toDouble()
          : 0.0,
      image128: (json['image_128'] is String) ? json['image_128'] : null,
    );
  }
}

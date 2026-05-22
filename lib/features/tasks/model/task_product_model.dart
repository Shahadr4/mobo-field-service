class TaskProductLine {
  final int id;
  final int productId;
  final String productName;
  final double qty;
  final double priceUnit;
  final String uomName;

  const TaskProductLine({
    required this.id,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.priceUnit,
    required this.uomName,
  });

  double get subtotal => qty * priceUnit;

  factory TaskProductLine.fromMap(Map<String, dynamic> m) {
    String rel(dynamic v) {
      if (v is List && v.length >= 2) return v[1].toString();
      return '';
    }

    int relId(dynamic v) {
      if (v is List && v.isNotEmpty) return (v[0] as num).toInt();
      return 0;
    }

    return TaskProductLine(
      id: (m['id'] as num).toInt(),
      productId: relId(m['product_id']),
      productName: rel(m['product_id']),
      qty: (m['product_uom_qty'] as num?)?.toDouble() ?? 1.0,
      priceUnit: (m['price_unit'] as num?)?.toDouble() ?? 0.0,
      uomName: rel(m['product_uom_id']),
    );
  }
}

class ProductSuggestion {
  final int id;
  final String name;
  final double listPrice;
  final String uomName;

  const ProductSuggestion({
    required this.id,
    required this.name,
    required this.listPrice,
    required this.uomName,
  });

  factory ProductSuggestion.fromMap(Map<String, dynamic> m) {
    String rel(dynamic v) {
      if (v is List && v.length >= 2) return v[1].toString();
      return '';
    }

    return ProductSuggestion(
      id: (m['id'] as num).toInt(),
      name: m['name']?.toString() ?? '',
      listPrice: (m['list_price'] as num?)?.toDouble() ?? 0.0,
      uomName: rel(m['uom_id']),
    );
  }
}

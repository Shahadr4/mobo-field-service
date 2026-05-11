import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../services/product_search_service.dart';

/// Product model for TypeAhead widget
class Product {
  final int id;
  final String name;
  final double? listPrice;
  final int? uomId;
  final String? barcode;
  final String? defaultCode;
  final String? imageUrl;
  final double? qtyAvailable;
  final double? location_id;

  Product({
    required this.id,
    required this.name,
    this.listPrice,
    this.uomId,
    this.barcode,
    this.defaultCode,
    this.imageUrl,
    this.qtyAvailable,
    this.location_id,
  });
}

/// Wrapper service for product search
class OdooApiService {
  final ProductSearchService _searchService = ProductSearchService();

  Future<List<Map<String, dynamic>>> searchProducts(
      String query, {
        int limit = 20,
      }) async {
    return _searchService.fetchProducts(
      searchQuery: query.isEmpty ? null : query,
      limit: limit,
      storableOnly: true,
    );
  }
}

class ProductTypeAhead extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final bool isDark;
  final ValueChanged<Product> onProductSelected;
  final String? Function(String?)? validator;
  final OdooApiService _apiService = OdooApiService();

  ProductTypeAhead({
    required this.controller,
    required this.labelText,
    required this.isDark,
    required this.onProductSelected,
    this.hintText,
    this.validator,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight > 0 && constraints.maxHeight <= 60;
        final fieldFontSize = compact ? 13.0 : 15.0;
        final hintFontSize = compact ? 13.0 : 15.0;
        final iconPadding = compact ? 8.0 : 12.0;
        final iconSizeLeft = compact ? 16.0 : 18.0;
        final iconSizeRight = compact ? 14.0 : 16.0;
        final verticalPad = compact ? 8.0 : 16.0;

        Widget field = TypeAheadField<Product>(
          controller: controller,
          builder: (context, controller, focusNode) {
            final textField = TextFormField(
              controller: controller,
              focusNode: focusNode,
              validator: validator,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                fontSize: fieldFontSize,
                color: isDark ? Colors.white : const Color(0xff000000),
              ),
              decoration: InputDecoration(
                hintText: hintText ?? 'Search products...',
                hintStyle: GoogleFonts.manrope(
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  fontSize: hintFontSize,
                ),
                prefixIcon: Padding(
                  padding: EdgeInsets.all(iconPadding),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedPackage,
                    color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                    size: iconSizeLeft,
                  ),
                ),
                suffixIcon: Padding(
                  padding: EdgeInsets.all(iconPadding),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                    size: iconSizeRight,
                  ),
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xffF8FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.5,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: verticalPad,
                ),
              ),
            );

            if (compact) {
              return SizedBox(
                height: constraints.maxHeight,
                child: Center(child: textField),
              );
            }
            return textField;
          },
          suggestionsCallback: (pattern) async {
            try {
              final limit = pattern.isEmpty ? 6 : 100;
              final results = await _apiService.searchProducts(
                pattern,
                limit: limit,
              );


              log("result product ====> ${results.toString()}");
              return results.map((data) {
                final rawName = data['display_name']?.toString() ?? 'Unknown';
                // Strip [...] prefix (e.g., [E-COM13] Conference Chair -> Conference Chair)
                final cleanedName = rawName.replaceFirst(
                  RegExp(r'^\[.*?\]\s*'),
                  '',
                );

                return Product(
                  id: data['id'] ?? 0,
                  name: cleanedName,
                  listPrice: (data['list_price'] as num?)?.toDouble() ?? 0.0,
                  uomId: data['uom_id'] is List && data['uom_id'].isNotEmpty
                      ? data['uom_id'][0]
                      : null,
                  barcode: data['barcode']?.toString(),
                  defaultCode: data['default_code']?.toString(),
                  imageUrl: data['image_128']?.toString(),
                  qtyAvailable: (data['qty_available'] as num?)?.toDouble(),
                );
              }).toList();
            } catch (e) {
              return [];
            }
          },
          itemBuilder: (context, product) {
            return ListTile(
              leading: _buildProductImage(product),
              title: Text(
                product.name,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              // subtitle: Column(
              //   crossAxisAlignment: CrossAxisAlignment.start,
              //   children: [
              //     if (product.defaultCode != null &&
              //         product.defaultCode!.isNotEmpty &&
              //         product.defaultCode!.toLowerCase() != 'false' &&
              //         product.defaultCode!.toLowerCase() != 'null')
              //       Text(
              //         'SKU: ${product.defaultCode}',
              //         style: GoogleFonts.manrope(
              //           fontSize: 12,
              //           fontWeight: FontWeight.w500,
              //           color: AppTheme.primaryColor,
              //         ),
              //       ),
              //     Text(
              //       'Price: ${product.listPrice?.toStringAsFixed(2) ?? '0.00'}',
              //       style: GoogleFonts.manrope(
              //         fontSize: 12,
              //         color: isDark ? Colors.white60 : Colors.grey[600],
              //       ),
              //     ),
              //   ],
              // ),
              // trailing: product.qtyAvailable != null
              //     ? Text(
              //         'Stock: ${product.qtyAvailable?.toStringAsFixed(0) ?? '0'}',
              //         style: GoogleFonts.manrope(
              //           fontSize: 12,
              //           fontWeight: FontWeight.w500,
              //           color: (product.qtyAvailable ?? 0) > 0
              //               ? Colors.green
              //               : Colors.red,
              //         ),
              //       )
              //     : null,
            );
          },
          onSelected: (product) {
            controller.text = product.name;
            // Dismiss keyboard and popup
            FocusScope.of(context).unfocus();
            // Notify parent
            onProductSelected(product);
          },
          loadingBuilder: (context) => const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          emptyBuilder: (context) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No products found',
              style: GoogleFonts.manrope(
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ),
          decorationBuilder: (context, child) => Material(
            type: MaterialType.card,
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            child: child,
          ),
        );
        if (compact) {
          // In compact mode, render only the field to avoid overflow
          return field;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labelText,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
              ),
            ),
            const SizedBox(height: 8),
            field,
          ],
        );
      },
    );
  }

  Widget _buildProductImage(Product product) {
    if (product.imageUrl != null &&
        product.imageUrl!.isNotEmpty &&
        product.imageUrl != 'false') {
      try {
        final base64String = product.imageUrl!.contains(',')
            ? product.imageUrl!.split(',')[1]
            : product.imageUrl!;
        final bytes = base64Decode(base64String);
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (e) {
        // Fallback to icon
      }
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const HugeIcon(
        icon: HugeIcons.strokeRoundedPackage,
        color: AppTheme.primaryColor,
        size: 18,
      ),
    );
  }
}

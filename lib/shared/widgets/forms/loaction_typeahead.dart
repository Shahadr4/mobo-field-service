import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../services/location_services.dart';

class LocationItem {
  final int id;
  final String name;
  final String? completeName;

  LocationItem({required this.id, required this.name, this.completeName});
}

class LocationTypeAhead extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool isDark;
  final int companyId;
  final ValueChanged<LocationItem> onLocationSelected;
  final String? hintText;
  final String? Function(String?)? validator;
  final int? parentLocationId; /// For picking mode - filter to warehouse

  const LocationTypeAhead({
    super.key,
    required this.controller,
    required this.labelText,
    required this.isDark,
    required this.companyId,
    required this.onLocationSelected,
    this.hintText,
    this.validator,
    this.parentLocationId,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight > 0 && constraints.maxHeight <= 60;
        final fieldFontSize = compact ? 13.0 : 15.0;
        final hintFontSize = compact ? 13.0 : 15.0;
        final iconPadding = compact ? 8.0 : 12.0;
        final iconSizeRight = compact ? 14.0 : 16.0;
        final verticalPad = compact ? 8.0 : 16.0;

        Widget field = TypeAheadField<LocationItem>(
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
                hintText: hintText ?? 'Search locations...',
                hintStyle: GoogleFonts.manrope(
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  fontSize: hintFontSize,
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
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
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
              final results = await LocationService.fetchInternalLocations(
                companyId: companyId,
                search: pattern,
                limit: 50,
                parentLocationId: parentLocationId,
              );
              return results.map((e) {
                final name = (e['complete_name'] ?? e['name'] ?? 'Unknown')
                    .toString();
                return LocationItem(
                  id: e['id'] as int,
                  name: name,
                  completeName: e['complete_name']?.toString(),
                );
              }).toList();
            } catch (e) {
              return [];
            }
          },
          itemBuilder: (context, item) {
            return ListTile(
              title: Text(
                item.name,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
          onSelected: (item) {
            controller.text = item.name;
            FocusScope.of(context).unfocus();
            onLocationSelected(item);
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
              'No locations found',
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
}

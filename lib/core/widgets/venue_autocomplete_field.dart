import 'package:flutter/material.dart';

import '../../models/venue.dart';
import '../constants/app_colours.dart';
import '../constants/app_text_styles.dart';

/// A location-name field that suggests matching partner venues as the
/// user types. Picking a suggestion calls [onVenuePicked] so the caller
/// can pre-fill associated fields (address, pitch type, etc.).
class VenueAutocompleteField extends StatelessWidget {
  const VenueAutocompleteField({
    super.key,
    required this.controller,
    required this.venues,
    required this.onVenuePicked,
    required this.validator,
    this.label = 'Location name',
    this.hint = 'Type to find a partner venue',
  });

  final TextEditingController controller;
  final List<Venue> venues;
  final ValueChanged<Venue> onVenuePicked;
  final String? Function(String?) validator;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.small.copyWith(
            color: AppColours.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        RawAutocomplete<Venue>(
          textEditingController: controller,
          focusNode: FocusNode(),
          optionsBuilder: (text) {
            final q = text.text.trim().toLowerCase();
            if (q.isEmpty) return const Iterable<Venue>.empty();
            return venues.where(
              (v) =>
                  v.name.toLowerCase().contains(q) ||
                  v.city.toLowerCase().contains(q),
            );
          },
          displayStringForOption: (venue) => venue.name,
          onSelected: onVenuePicked,
          fieldViewBuilder: (context, textController, focusNode, onSubmit) {
            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              style: AppTextStyles.body,
              validator: validator,
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: const Icon(Icons.place_outlined, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 240),
                  decoration: BoxDecoration(
                    color: AppColours.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColours.line),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: AppColours.line,
                    ),
                    itemBuilder: (context, index) {
                      final venue = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(venue),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.stadium,
                                color: AppColours.accent,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      venue.name,
                                      style: AppTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${venue.city} · ${venue.pitchTypes.join(", ")}',
                                      style: AppTextStyles.small,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

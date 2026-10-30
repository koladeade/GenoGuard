import 'package:flutter/material.dart';
import '../core/ng_states.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class LocationField extends StatefulWidget {
  const LocationField({
    super.key,
    required this.controller,
    this.helper,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String? helper;
  final TextInputAction? textInputAction;

  @override
  State<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Iterable<String> _options(TextEditingValue v) {
    final q = v.text.trim().toLowerCase();
    if (q.isEmpty) return kNgStateNames;
    final starts = kNgStateNames.where((n) => n.toLowerCase().startsWith(q));
    final contains = kNgStateNames.where((n) {
      final l = n.toLowerCase();
      return !l.startsWith(q) && l.contains(q);
    });
    return [...starts, ...contains];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('City or area'),
        LayoutBuilder(
          builder: (context, constraints) => RawAutocomplete<String>(
            textEditingController: widget.controller,
            focusNode: _focus,
            optionsBuilder: _options,
            fieldViewBuilder:
                (context, textController, focusNode, onSubmitted) =>
                    TextFormField(
                      controller: textController,
                      focusNode: focusNode,
                      textInputAction: widget.textInputAction,
                      onFieldSubmitted: (_) => onSubmitted(),
                      style: AppText.body(16),
                      decoration: const InputDecoration(
                        hintText: 'Start typing, e.g. Lagos',
                      ),
                    ),
            optionsViewBuilder: (context, onSelected, options) {
              final list = options.toList();
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: constraints.maxWidth,
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (context, i) => InkWell(
                        onTap: () => onSelected(list[i]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Text(list[i], style: AppText.body(16)),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helper!,
            style: AppText.body(13, FontWeight.w500, AppColors.hint),
          ),
        ],
      ],
    );
  }
}

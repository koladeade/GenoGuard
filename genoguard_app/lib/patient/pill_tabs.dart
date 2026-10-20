import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Segmented control used for the filter chips and the sheet's Type / Repeat rows.
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.gold = false,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool gold; // gold fill for the selected pill (Repeat row)

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border, width: 1.2),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Container(
                margin: const EdgeInsets.all(4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == selected
                      ? (gold ? AppColors.gold : AppColors.surfaceAlt)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labels[i],
                    style: AppText.body(
                      16,
                      FontWeight.w700,
                      i == selected
                          ? (gold ? AppColors.onGold : AppColors.text)
                          : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bottom navigation bar shared by the patient and explorer shells.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });
  final List<(IconData, String)> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.navBar,
      border: Border(top: BorderSide(color: AppColors.border, width: 1.2)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 40,
                        decoration: BoxDecoration(
                          color: i == index
                              ? AppColors.gold
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          items[i].$1,
                          size: 26,
                          color: i == index
                              ? AppColors.onGold
                              : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$2,
                        style: AppText.body(
                          13,
                          i == index ? FontWeight.w700 : FontWeight.w500,
                          i == index ? AppColors.gold : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

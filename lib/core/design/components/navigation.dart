import 'package:flutter/material.dart';

import '../palette.dart';
import '../tokens.dart';

class DockItem {
  final IconData icon;
  final String label;
  const DockItem(this.icon, this.label);
}

/// 떠 있는 검은 알약 하단 내비. 레퍼런스 모바일 화면의 아래 막대.
/// 선택된 탭은 흰 동그라미 안 아이콘 + 글자, 나머지는 아이콘만.
class FloatingDock extends StatelessWidget {
  final List<DockItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  const FloatingDock({super.key, required this.items, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: AppGap.lg),
      child: Center(
        heightFactor: 1,
        child: Container(
          padding: const EdgeInsets.all(AppGap.snug),
          decoration: BoxDecoration(
            color: p.dock,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                _DockButton(item: items[i], selected: i == index, onTap: () => onChanged(i)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final DockItem item;
  final bool selected;
  final VoidCallback onTap;

  const _DockButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 14),
          decoration: BoxDecoration(
            color: selected ? p.onDock : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 20, color: selected ? p.dock : p.onDock.withValues(alpha: 0.7)),
              if (selected) ...[
                const SizedBox(width: AppGap.snug),
                Text(
                  item.label,
                  style: TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w700, color: p.dock),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 알약 세그먼트 탭(검은 알약이 선택). 레퍼런스 상단의 "Dashboard | Tasks | Calendar".
/// 자녀 고르기·보기 방식 바꾸기 등 "같은 화면 안 전환"에 쓴다.
class PillTabs<T> extends StatelessWidget {
  final List<(T value, String label, Color? dot)> items;
  final T selected;
  final ValueChanged<T> onChanged;

  const PillTabs({super.key, required this.items, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(AppGap.xs),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(
          children: [
            for (final (value, label, dot) in items)
              GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ), // 33→약 39dp + 바깥 4 (디자인 점검: 누르기 영역)
                  decoration: BoxDecoration(
                    color: value == selected ? p.dock : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dot != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: AppGap.snug),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: AppText.label,
                          fontWeight: FontWeight.w600,
                          color: value == selected ? p.onDock : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

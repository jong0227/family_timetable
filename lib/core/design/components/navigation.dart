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

/// 요일 고르기 띠: 월~일 7칸이 **항상 화면 폭 안에 다 들어간다**(가로 스크롤 없음).
///
/// 예전엔 [PillTabs]("금 · 오늘")를 썼는데 폭이 화면보다 넓어 가로로 스크롤됐다. 그래서 좌우로 밀어
/// 토·일로 가면 고른 칸이 화면 밖에 있어 바뀐 게 안 보였고, 띠 위에서 밀면 띠가 스크롤되며 요일이 안 넘어갔다
/// (실사용 버그). 오늘은 글자 대신 아래 점으로 표시해 칸 폭이 늘지 않게 한다.
class WeekdayStrip extends StatelessWidget {
  final int selected;
  final int today;
  final ValueChanged<int> onChanged;

  const WeekdayStrip({super.key, required this.selected, required this.today, required this.onChanged});

  static const _labels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppGap.xs),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        children: [
          for (var d = 1; d <= 7; d++)
            Expanded(
              child: Semantics(
                button: true,
                selected: d == selected,
                label: '${_labels[d - 1]}요일${d == today ? ', 오늘' : ''}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(d),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.curve,
                    height: 40,
                    decoration: BoxDecoration(
                      color: d == selected ? p.dock : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _labels[d - 1],
                          style: TextStyle(
                            fontSize: AppText.label,
                            fontWeight: FontWeight.w700,
                            color: d == selected ? p.onDock : null,
                          ),
                        ),
                        // 오늘 표시(고른 칸이면 반전 색). 자리는 늘 잡아 둬서 칸 높이가 흔들리지 않는다.
                        const SizedBox(height: 2),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: d != today ? Colors.transparent : (d == selected ? p.onDock : p.status.positive),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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

/// 켜고 끄는 알약 칩: 켜지면 검은 알약 + 체크, 꺼지면 바탕색 + 빈 동그라미. [PillTabs]와 같은 색 규칙.
///
/// 기본 FilterChip은 어두운 화면에서 켜진 칩 글자가 바탕에 묻혔다(미리보기에서 발견). 켜짐/꺼짐이 한눈에
/// 보여야 해서("학교 교시 보기"를 어딜 눌러야 하냐는 실사용 질문) 체크 표시를 늘 붙인다.
class ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const ToggleChip({super.key, required this.label, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? p.onDock : p.textMuted;
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      child: GestureDetector(
        onTap: () => onChanged(!selected),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? p.dock : p.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 16, color: fg),
              const SizedBox(width: AppGap.snug),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppText.label,
                  fontWeight: FontWeight.w700,
                  color: selected ? p.onDock : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

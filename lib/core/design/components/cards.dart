import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../palette.dart';
import '../tokens.dart';

/// 대시보드 카드. 머리에 작은 아이콘 + 흐린 제목, 오른쪽에 "전체 보기" 같은 링크.
/// 레퍼런스의 "⚙ Need to do ......... View all" 카드 모양. 앱의 거의 모든 묶음은 이 카드에 담는다.
class DashCard extends StatelessWidget {
  final IconData? icon;
  final String? title;
  final String? linkLabel;
  final VoidCallback? onLink;
  final VoidCallback? onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DashCard({
    super.key,
    this.icon,
    this.title,
    this.linkLabel,
    this.onLink,
    this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(AppGap.lg),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Row(
                  children: [
                    if (icon != null) ...[Icon(icon, size: 16, color: p.textMuted), const SizedBox(width: AppGap.snug)],
                    Expanded(
                      child: Text(
                        title!,
                        style: TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w600, color: p.textMuted),
                      ),
                    ),
                    // 흐린 글자 + GestureDetector(약 17dp)라 링크인지도 모르고 누르기도 어려웠다(디자인 점검).
                    if (linkLabel != null)
                      TextButton(
                        onPressed: onLink,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w700),
                        ),
                        child: Text(linkLabel!),
                      ),
                  ],
                ),
                const SizedBox(height: AppGap.md),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 히어로 카드: 자녀색 파스텔 그라데이션 위에 큰 내용. 레퍼런스의 유리 같은
/// "Water on floor near fridge" 카드. 한 화면에 하나(또는 자녀별 넘겨 보기 한 묶음)만 쓴다.
class HeroCard extends StatelessWidget {
  final List<Color> gradient;
  final Widget child;
  final VoidCallback? onTap;

  const HeroCard({super.key, required this.gradient, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(AppGap.xl), child: child),
        ),
      ),
    );
  }
}

/// 상태 칩: 흰 알약 안에 상태색 글자. 레퍼런스의 "Overdue"(주황) "Today"(주황) "Active"(초록).
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;

  const StatusChip(this.label, {super.key, required this.color, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppGap.xs),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: AppText.caption,
              fontWeight: FontWeight.w600,
              color: context.palette.status.text(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// 시각 표시(Poppins 숫자). 히어로·타임라인에서 시간은 전부 이걸로.
class TimeText extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;

  const TimeText(this.text, {super.key, this.size = AppText.bodyLg, this.weight = FontWeight.w600, this.color});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppFonts.numeric(size: size, weight: weight, color: color),
  );
}

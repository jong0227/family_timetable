import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../palette.dart';
import '../tokens.dart';

/// 화면 본문 틀: 최대 폭 제한 + 좌우 여백 + 하단 내비만큼 아래 여백.
/// 모든 탭/화면의 스크롤 본문은 이걸로 감싼다.
class PageBody extends StatelessWidget {
  final List<Widget> children;

  const PageBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppGap.page, MediaQuery.paddingOf(context).top + AppGap.md, AppGap.page,
              kDockClearance),
          children: children,
        ),
      ),
    );
  }
}

/// 화면 머리: 왼쪽 큰 가는 제목 + 한 줄 요약, 오른쪽 날짜 블록.
/// 레퍼런스의 "Dashboard / 6 overdue tasks … ·  27 Jul 2026 Monday" 자리.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// 오른쪽 위 작은 글씨(예: "10월 23일")
  final String? asideTop;

  /// 오른쪽 큰 글씨(예: "목요일")
  final String? asideMain;
  final List<Widget> actions;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.asideTop,
    this.asideMain,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppGap.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (actions.isNotEmpty) Row(children: actions),
                Text(title,
                    style: const TextStyle(fontSize: AppText.display, fontWeight: FontWeight.w300, height: 1.15)),
                if (subtitle != null) ...[
                  const SizedBox(height: AppGap.xs),
                  Text(subtitle!, style: TextStyle(fontSize: AppText.body, color: p.textMuted)),
                ],
              ],
            ),
          ),
          if (asideMain != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (asideTop != null)
                  Text(asideTop!, style: TextStyle(fontSize: AppText.caption, color: p.textMuted)),
                Text(asideMain!, style: const TextStyle(fontSize: AppText.titleLg, fontWeight: FontWeight.w700)),
              ],
            ),
        ],
      ),
    );
  }
}

/// KPI 한 칸: 흐린 라벨 위에 크고 가는 숫자. 레퍼런스의 "Open tasks 24".
class Kpi {
  final String label;
  final String value;

  /// 값 옆 상태 점(예: 빈 시간이 있으면 urgent)
  final Color? dot;
  const Kpi(this.label, this.value, {this.dot});
}

class KpiRow extends StatelessWidget {
  final List<Kpi> items;
  const KpiRow(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppGap.xl),
      child: Row(
        children: [
          for (final k in items)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.label, style: TextStyle(fontSize: AppText.caption, color: p.textMuted)),
                  const SizedBox(height: AppGap.xs),
                  Row(
                    children: [
                      Text(k.value, style: AppFonts.numeric(size: AppText.kpi)),
                      if (k.dot != null) ...[
                        const SizedBox(width: AppGap.snug),
                        StatusDot(k.dot!),
                      ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 대시보드 카드 격자. 폭에 따라 1~3열(Breakpoint). 카드 높이는 내용대로.
class DashboardGrid extends StatelessWidget {
  final List<Widget> children;
  const DashboardGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final cols = Breakpoint.of(context).columns;
    if (cols == 1) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppGap.md),
            children[i],
          ],
        ],
      );
    }
    // 열마다 차례로 나눠 담는다(순서 유지, 높이 다른 카드끼리 빈틈 최소화는 다음 단계 과제).
    final columns = List.generate(cols, (_) => <Widget>[]);
    for (var i = 0; i < children.length; i++) {
      columns[i % cols].add(children[i]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < cols; c++) ...[
          if (c > 0) const SizedBox(width: AppGap.md),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < columns[c].length; i++) ...[
                  if (i > 0) const SizedBox(height: AppGap.md),
                  columns[c][i],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class StatusDot extends StatelessWidget {
  final Color color;
  final double size;
  const StatusDot(this.color, {super.key, this.size = 8});

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

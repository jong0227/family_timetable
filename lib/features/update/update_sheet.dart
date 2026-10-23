import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import '../../core/design/design.dart';
import '../../domain/app_version.dart';

/// 새 버전 안내 + 앱 안에서 바로 내려받아 설치.
///
/// 내려받기가 끝나면 안드로이드 설치 화면이 뜬다(처음 한 번은 "이 출처 허용"을 켜야 한다).
/// 지금 앱 위에 덮어 설치되므로 시간표는 그대로 남는다 — 같은 PC 서명이라 가능(CLAUDE.md "테스트 배포").
Future<void> showUpdateSheet(BuildContext context, AvailableUpdate update, {required AppVersion current}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UpdateSheet(update: update, current: current),
    );

class _UpdateSheet extends StatefulWidget {
  final AvailableUpdate update;
  final AppVersion current;
  const _UpdateSheet({required this.update, required this.current});

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  StreamSubscription<OtaEvent>? _sub;
  double? _progress; // null = 시작 전, 0~1 = 내려받는 중
  String? _error;
  bool _installing = false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      _sub = OtaUpdate()
          .execute(widget.update.apkUrl, destinationFilename: 'family_timetable_${widget.update.version}.apk')
          .listen(_onEvent, onError: (Object e) => _fail('내려받다가 문제가 생겼어요'));
    } catch (_) {
      _fail('이 기기에서는 앱 안 업데이트를 쓸 수 없어요');
    }
  }

  void _onEvent(OtaEvent e) {
    switch (e.status) {
      case OtaStatus.DOWNLOADING:
        setState(() => _progress = (double.tryParse(e.value ?? '') ?? 0) / 100);
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        setState(() => _installing = true);
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        _fail('설치 권한이 필요해요. 설정에서 "이 출처의 앱 설치 허용"을 켜 주세요');
      default:
        _fail('업데이트하지 못했어요 (${e.status.name})');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _progress = null;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final u = widget.update;
    final downloading = _progress != null && !_installing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.page, 0, AppGap.page, AppGap.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '새 버전이 나왔어요',
                  style: TextStyle(fontSize: AppText.heading, fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip('v${u.version}', color: p.status.info, dot: true),
            ],
          ),
          const SizedBox(height: AppGap.xs),
          Text(
            '지금 v${widget.current} → v${u.version}',
            style: TextStyle(fontSize: AppText.label, color: p.textMuted),
          ),
          if (u.notes.isNotEmpty) ...[
            const SizedBox(height: AppGap.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Text(u.notes, style: const TextStyle(fontSize: AppText.body, height: 1.5)),
              ),
            ),
          ],
          const SizedBox(height: AppGap.lg),
          Text(
            '지금 앱 위에 덮어 설치돼서 시간표는 그대로 남아요.',
            style: TextStyle(fontSize: AppText.label, color: p.textMuted),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppGap.sm),
            Text(
              _error!,
              style: TextStyle(fontSize: AppText.label, color: p.status.urgentText, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: AppGap.lg),
          if (downloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(value: _progress == 0 ? null : _progress, minHeight: 8),
            ),
            const SizedBox(height: AppGap.sm),
            Text(
              '내려받는 중 ${((_progress ?? 0) * 100).round()}%',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppText.label, color: p.textMuted),
            ),
          ] else if (_installing)
            const Text(
              '설치 화면에서 "업데이트"를 눌러 주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppText.bodyLg, fontWeight: FontWeight.w700),
            )
          else
            FilledButton(onPressed: _start, child: Text(_error == null ? '지금 업데이트' : '다시 시도')),
        ],
      ),
    );
  }
}

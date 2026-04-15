import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

/// ข้อความขั้นตอนซิงค์ (0.0–1.0)
String syncPhaseLabel(double v) {
  if (v < 0.15) return 'เตรียมซิงค์…';
  if (v < 0.45) return 'ดึงข้อมูลสินค้า…';
  if (v < 0.78) return 'ส่งบิลที่ค้าง…';
  if (v < 1.0) return 'ล้างบิลเก่า…';
  return 'เสร็จสิ้น';
}

/// Dialog กลางจอแสดงความคืบหน้าซิงค์ (ใช้ [percent_indicator])
class SyncProgressDialog extends StatelessWidget {
  const SyncProgressDialog({super.key, required this.progress});

  final ValueNotifier<double> progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, v, _) {
        final pct = v.clamp(0.0, 1.0);
        final pctInt = (pct * 100).round();

        return Dialog(
          backgroundColor: cs.surface,
          surfaceTintColor: cs.primary.withValues(alpha: 0.12),
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_sync_rounded,
                    size: 32,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'กำลังซิงค์ข้อมูล',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'โปรดรอสักครู่',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                CircularPercentIndicator(
                  radius: 58,
                  lineWidth: 9,
                  percent: pct,
                  animation: true,
                  animateFromLastPercent: true,
                  animationDuration: 450,
                  curve: Curves.easeOutCubic,
                  circularStrokeCap: CircularStrokeCap.round,
                  progressColor: cs.primary,
                  backgroundColor: cs.surfaceContainerHighest,
                  startAngle: 220,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pctInt',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1,
                          color: cs.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        '%',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 260,
                  child: LinearPercentIndicator(
                    width: 260,
                    lineHeight: 8,
                    percent: pct,
                    animation: true,
                    animateFromLastPercent: true,
                    animationDuration: 450,
                    curve: Curves.easeOutCubic,
                    barRadius: const Radius.circular(8),
                    progressColor: cs.primary,
                    backgroundColor: cs.surfaceContainerHighest,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  syncPhaseLabel(v),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

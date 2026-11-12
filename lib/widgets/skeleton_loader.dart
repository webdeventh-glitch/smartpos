import 'package:flutter/material.dart';

/// Step 7.5: Animated shimmer/pulse skeleton placeholders to avoid jarring layout jumps.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlightColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final col = Color.lerp(baseColor, highlightColor, _ctrl.value)!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: col,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Reusable dashboard/report loading skeleton showing KPI cards + table rows.
class DashboardSkeletonView extends StatelessWidget {
  const DashboardSkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 82, borderRadius: 16),
            SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: SkeletonBox(height: 92, borderRadius: 14)),
                SizedBox(width: 14),
                Expanded(child: SkeletonBox(height: 92, borderRadius: 14)),
                SizedBox(width: 14),
                Expanded(child: SkeletonBox(height: 92, borderRadius: 14)),
                SizedBox(width: 14),
                Expanded(child: SkeletonBox(height: 92, borderRadius: 14)),
              ],
            ),
            SizedBox(height: 18),
            SkeletonBox(height: 220, borderRadius: 14),
            SizedBox(height: 16),
            SkeletonBox(height: 180, borderRadius: 14),
          ],
        ),
      ),
    );
  }
}

/// Compact table row skeleton for Products, Reports, and Ledger screens.
class TableSkeletonView extends StatelessWidget {
  final int rowCount;

  const TableSkeletonView({super.key, this.rowCount = 6});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          rowCount,
          (i) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonBox(height: 44, borderRadius: 10),
          ),
        ),
      ),
    );
  }
}

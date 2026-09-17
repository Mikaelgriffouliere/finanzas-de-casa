import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Primitivas de skeleton con efecto shimmer para estados de carga.
///
/// Uso típico: construir un layout con [SkeletonLine], [SkeletonCircle] o
/// [SkeletonBox] usando los helpers de pantalla (p.ej. [SkeletonReportsView])
/// y envolverlo con [SkeletonRipple].
class SkeletonRipple extends StatelessWidget {
  final Widget child;

  const SkeletonRipple({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1D2640) : const Color(0xFFE3E7F2),
      highlightColor: isDark
          ? const Color(0xFF2C3654)
          : const Color(0xFFF4F6FC),
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final EdgeInsetsGeometry margin;
  final Widget? child;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 16,
    this.margin = EdgeInsets.zero,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonLine({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double height;
  final int lines;

  const SkeletonCard({super.key, this.height = 120, this.lines = 3});

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < lines; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SkeletonLine(
                  width: i == lines - 1 ? 120 : double.infinity,
                  height: i == 0 ? 18 : 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  final double circleSize;
  final bool showTrailing;

  const SkeletonListTile({
    super.key,
    this.circleSize = 40,
    this.showTrailing = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SkeletonCircle(size: circleSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLine(height: 14, width: 140),
                SizedBox(height: 8),
                SkeletonLine(height: 11, width: 90),
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 16),
            const SkeletonLine(height: 14, width: 60),
          ],
        ],
      ),
    );
  }
}

/// Layout de carga para la pantalla de reportes.
class SkeletonReportsView extends StatelessWidget {
  const SkeletonReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonRipple(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonLine(height: 18, width: 180),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 96)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 96)),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 96)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 96)),
            ],
          ),
          SizedBox(height: 24),
          SkeletonLine(height: 18, width: 200),
          SizedBox(height: 10),
          SkeletonBox(height: 200),
          SizedBox(height: 24),
          SkeletonLine(height: 18, width: 200),
          SizedBox(height: 10),
          SkeletonBox(height: 120),
        ],
      ),
    );
  }
}

/// Layout de carga para el resumen del dashboard.
class SkeletonDashboardSummary extends StatelessWidget {
  const SkeletonDashboardSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonRipple(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SkeletonBox(
          height: 260,
          radius: 26,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    SkeletonBox(width: 110, height: 24, radius: 12),
                    Spacer(),
                    SkeletonBox(width: 120, height: 24, radius: 12),
                  ],
                ),
                SizedBox(height: 20),
                SkeletonLine(width: 90, height: 11),
                SizedBox(height: 8),
                SkeletonLine(width: 180, height: 30),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 64, radius: 14)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 64, radius: 14)),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 64, radius: 14)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 64, radius: 14)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista de movimientos en carga.
class SkeletonTransactionsList extends StatelessWidget {
  const SkeletonTransactionsList({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonRipple(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [for (var i = 0; i < 8; i++) const SkeletonListTile()],
      ),
    );
  }
}

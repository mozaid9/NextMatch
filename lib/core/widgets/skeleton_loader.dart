import 'package:flutter/material.dart';

import '../constants/app_colours.dart';

/// A horizontally-scrolling list of [count] shimmer match-card placeholders.
/// All cards share a single [AnimationController] so they pulse in sync.
class SkeletonMatchList extends StatefulWidget {
  const SkeletonMatchList({
    super.key,
    this.count = 3,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 112),
  });

  final int count;
  final EdgeInsets padding;

  @override
  State<SkeletonMatchList> createState() => _SkeletonMatchListState();
}

class _SkeletonMatchListState extends State<SkeletonMatchList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Color?> _color;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _color = ColorTween(
      begin: AppColours.cardAlt,
      end: AppColours.line,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _color,
      builder: (_, __) {
        final shimmer = _color.value ?? AppColours.cardAlt;
        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: widget.padding,
          itemCount: widget.count,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, __) => _SkeletonCard(shimmer: shimmer),
        );
      },
    );
  }
}

/// A single shimmer placeholder shaped like a [MatchCard].
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.shimmer});

  final Color shimmer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status pill
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(shimmer, h: 15, w: 190),
                    const SizedBox(height: 8),
                    _box(shimmer, h: 12, w: 130),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _box(shimmer, h: 28, w: 74, r: 8),
            ],
          ),
          const SizedBox(height: 14),
          // Info chips
          Row(
            children: [
              _box(shimmer, h: 28, w: 84),
              const SizedBox(width: 8),
              _box(shimmer, h: 28, w: 72),
              const SizedBox(width: 8),
              _box(shimmer, h: 28, w: 60),
            ],
          ),
          const SizedBox(height: 14),
          // Price + spaces row
          Row(
            children: [
              _box(shimmer, h: 13, w: 110),
              const Spacer(),
              _box(shimmer, h: 13, w: 80),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          _box(shimmer, h: 6, r: 99),
          const SizedBox(height: 12),
          // Organiser line
          _box(shimmer, h: 11, w: 160),
        ],
      ),
    );
  }

  Widget _box(Color color, {required double h, double? w, double r = 6}) =>
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(r),
        ),
      );
}

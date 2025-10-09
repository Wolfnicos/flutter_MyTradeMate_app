import 'package:flutter/material.dart';

class UiSkeleton extends StatelessWidget {
  final double height;
  final double radius;
  const UiSkeleton({super.key, this.height = 16, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.6),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}



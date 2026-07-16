import 'package:flutter/material.dart';

class FlexibleSpaceM3 extends StatelessWidget {
  const FlexibleSpaceM3({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final flexCfg = context
            .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>()!;

        final statusBarHeight = MediaQuery.of(context).padding.top;
        final deltaExtend = flexCfg.maxExtent - flexCfg.minExtent;
        final double t =
            ((flexCfg.currentExtent - flexCfg.minExtent) / deltaExtend).clamp(
              0.0,
              1.0,
            );

        final padding = EdgeInsetsDirectional.lerp(
          EdgeInsetsDirectional.zero,
          const EdgeInsetsDirectional.only(start: 16, bottom: 16),
          t,
        )!;

        final alignment = AlignmentDirectional.lerp(
          AlignmentDirectional.center,
          AlignmentDirectional.bottomStart,
          t,
        )!;

        final titleStyle = TextStyle.lerp(
          Theme.of(context).textTheme.titleLarge,
          Theme.of(context).textTheme.displayMedium,
          t,
        )!;

        return Padding(
          padding: EdgeInsetsGeometry.only(top: statusBarHeight),
          child: Padding(
            padding: padding,
            child: Align(
              alignment: alignment,
              child: Text(title, style: titleStyle),
            ),
          ),
        );
      },
    );
  }
}

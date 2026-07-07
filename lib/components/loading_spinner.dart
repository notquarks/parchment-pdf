import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

class LoadingSpinner extends StatelessWidget {
  const LoadingSpinner({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    return SizedBox(
      width: shortest * size,
      height: shortest * size,
      child: LoadingIndicatorM3E(variant: LoadingIndicatorM3EVariant.contained),
    );
  }
}

import 'package:flutter/material.dart';

/// The MJ brand mark on a light rounded tile.
///
/// The logo artwork is dark on a transparent background, so it disappears on
/// dark surfaces (e.g. the splash screen). Drawing it on a white tile keeps
/// the contrast high everywhere, and `BoxFit.contain` keeps its proportions.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: const Color(0x1A94A3B8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Image.asset(
        'assets/icon/mj_mark.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

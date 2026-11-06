import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const String sharedPageBackgroundAsset =
    'assets/images/shared_guqin_background.jpg';

/// 全应用统一的淡水墨背景。
class InkBackdrop extends StatelessWidget {
  const InkBackdrop({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
        sharedPageBackgroundAsset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      );
}

/// 使用全应用统一背景的页面骨架。
class InkScaffold extends StatelessWidget {
  const InkScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
    this.backgroundImageAsset,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;
  final String? backgroundImageAsset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: backgroundImageAsset == null
                  ? const InkBackdrop()
                  : Opacity(
                      opacity: 0.32,
                      child: Image.asset(
                        backgroundImageAsset!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
            ),
          ),
          Positioned.fill(child: body),
        ],
      ),
    );
  }
}

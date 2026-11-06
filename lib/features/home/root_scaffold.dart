import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../profile/profile_page.dart';
import 'experience_page.dart';
import 'home_page.dart';
import 'learn_page.dart';

/// 全局底部导航容器：首页 / 习琴 / 体验 / 我的。
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  final _pages = const [
    HomePage(),
    LearnPage(),
    ExperiencePage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.paperLight,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 62,
          selectedIndex: _index,
          onDestinationSelected: (i) {
            setState(() => _index = i);
            if (i == 3) ProfilePage.reload();
          },
          indicatorColor: AppColors.cinnabar.withValues(alpha: 0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.spa_outlined),
              selectedIcon: Icon(Icons.spa, color: AppColors.cinnabar),
              label: '首页',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book, color: AppColors.cinnabar),
              label: '习琴',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome, color: AppColors.cinnabar),
              label: '体验',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.cinnabar),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}

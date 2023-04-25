import 'package:everyvaluation/screen/community.dart';
import 'package:everyvaluation/screen/setting.dart';
import 'package:everyvaluation/screen/valuation.dart';
import 'package:flutter/material.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';

class home extends StatefulWidget {
  const home({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _homeState createState() => _homeState();
}

class _homeState extends State<home> with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      initialIndex: 0,
      length: 3,
      vsync: this,
    );
  }

  @override
  void dispose() {
    super.dispose();
    _tabController!.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: MotionTabBar(
        initialSelectedTab: "가치평가",
        useSafeArea: true,
        labels: const ["가치평가", "커뮤니티", "설정"],
        icons: const [Icons.calculate, Icons.home, Icons.settings],
        tabSize: 50,
        tabBarHeight: 55,
        textStyle: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        tabIconColor: Colors.white,
        tabIconSize: 32.0,
        tabIconSelectedSize: 28.0,
        tabSelectedColor: const Color.fromARGB(255, 32, 82, 149),
        tabIconSelectedColor: Colors.white,
        tabBarColor: const Color.fromARGB(255, 20, 66, 114),
        onTabItemSelected: (int value) {
          setState(() {
            _tabController!.index = value;
          });
        },
      ),
      body: TabBarView(
        physics:
            NeverScrollableScrollPhysics(), // swipe navigation handling is not supported
        controller: _tabController,
        // ignore: prefer_const_literals_to_create_immutables
        children: <Widget>[
          ValuationScreen(),
          CommunityScreen(),
          SettingScreen(),
        ],
      ),
    );
  }
}

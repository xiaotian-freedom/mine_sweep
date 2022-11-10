import 'dart:async';
import 'dart:math';

import 'package:flip_card/flip_card.dart';
import 'package:flip_card/flip_card_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mines_go_flutter/JellyButton.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); //不加这个强制横/竖屏会报错
  SystemChrome.setPreferredOrientations([
    // 强制竖屏
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(title: '扫雷'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class Player {
  int type; //0: 钻石 1: 地雷
  int tag; //0: 未翻开 1: 已翻开

  Player(this.type, this.tag);
}

class _MyHomePageState extends State<MyHomePage> {
  //包含炸弹和钻石的列表
  final List<Player> _list = [];
  final List<FlipCardController> _controllerList = [];

  //总数量
  final int totalCount = 25;

  //当前局的地雷数量
  var _boomCount = 0;

  //游戏是否结束
  var isGameOver = false;

  //是否开启作弊模式
  var isGodMode = false;

  //是否正在初始化
  var isRestart = false;

  final random = Random();

  ///获取随机数
  int getRandomInt(int min, int max) {
    return random.nextInt((max - min).floor()) + min;
  }

  ///生成不重复的随机索引
  int getFitLocation(List<int> list) {
    var index = getRandomInt(0, totalCount);
    if (isFitLocation(index, list)) {
      return index;
    }
    return getFitLocation(list);
  }

  ///是否是满意的随机数
  bool isFitLocation(int index, List<int> list) {
    if (list.isEmpty || !list.contains(index)) {
      list.add(index);
      return true;
    }
    return false;
  }

  ///重新开始游戏
  ///清空列表，随机生成地雷的数量 3-5个
  void restart() {
    if (isRestart) return;
    Fluttertoast.cancel();
    isRestart = true;
    _list.clear();
    isGameOver = false;
    _boomCount = getRandomInt(3, 5);
    //数据重新初始化
    for (int i = 0; i < totalCount; i++) {
      _list.add(Player(0, 0));
    }
    //放置炸弹前要先翻卡片
    for (int i = 0; i < _controllerList.length; i++) {
      var controller = _controllerList[i];
      var state = controller.state;
      if (state != null && !state.isFront) {
        //所有卡片全部翻一遍
        controller.toggleCard();
        // Timer(Duration(milliseconds: i * 50), () {
        //   controller.toggleCard();
        // });
      }
    }

    //添加延时避免翻卡片时炸弹位置泄漏
    Timer(const Duration(milliseconds: 500), () {
      //放置炸弹
      var boomIndexList = <int>[];
      for (int i = 0; i < _boomCount; i++) {
        //生成地雷的位置
        var boomIndex = getFitLocation(boomIndexList);
        if (_list[boomIndex].type == 0) {
          _list[boomIndex].type = 1;
        }
      }
      if (kDebugMode) {
        print("boomIndexList ---> $boomIndexList");
      }
      setState(() {
        //更新列表展示
      });
      isRestart = false;
    });
  }

  @override
  void initState() {
    super.initState();
    restart();
    for (int i = 0; i < totalCount; i++) {
      _controllerList.add(FlipCardController());
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screeW = size.width;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/bg.png"),
            fit: BoxFit.fill,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Image(
              image: AssetImage("images/title_logo.png"),
              width: 400,
            ),
            SizedBox(
              width: screeW,
              height: screeW,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image(
                    image: const AssetImage("images/content_bg.png"),
                    width: screeW,
                    fit: BoxFit.fill,
                  ),
                  gridWidget()
                ],
              ),
            ),
            bottomWidget()
          ],
        ),
      ),
    );
  }

  ///卡片widget
  Widget gridWidget() {
    return Container(
      padding: const EdgeInsets.all(30.0),
      child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            childAspectRatio: 1.0,
          ),
          itemCount: totalCount,
          itemBuilder: (item, index) {
            return GestureDetector(
              onTap: () {
                onItemClick(index);
              },
              onHorizontalDragEnd: (details) {
                if (!isGodMode || details.primaryVelocity == null) return;
                if (details.primaryVelocity! > 0) {
                  toggleAllCard();
                } else {
                  toggleAllCard();
                }
              },
              child: FlipCard(
                controller: _controllerList[index],
                direction: FlipDirection.HORIZONTAL,
                flipOnTouch: false,
                front: const Image(
                  image: AssetImage("images/card.png"),
                ),
                back: showDiamondAndBoom(index),
              ),
            );
          }),
    );
  }

  ///展示地雷和钻石widget
  Widget showDiamondAndBoom(int index) {
    if (_list[index].type == 0) {
      return Stack(
        children: const [
          Image(
            image: AssetImage("images/card.png"),
          ),
          Image(
            image: AssetImage("images/diamond.png"),
          )
        ],
      );
    } else {
      return Stack(
        children: const [
          Image(
            image: AssetImage("images/card.png"),
          ),
          Image(image: AssetImage("images/boom.png"))
        ],
      );
    }
  }

  ///底部widget
  Widget bottomWidget() {
    return Flex(
      direction: Axis.horizontal,
      children: [
        const Expanded(
            flex: 3,
            child: Image(
              image: AssetImage("images/win_num.png"),
              width: 300,
            )),
        Expanded(
          flex: 2,
          child: JellyButton(
              onTap: restart,
              size: const Size(200, 120),
              unCheckedImgAsset: 'images/new.png',
              checkedImgAsset: 'images/new.png'),
        )
      ],
    );
  }

  ///列表点击
  void onItemClick(int index) {
    if (isGameOver) {
      showToast("游戏结束");
      return;
    }
    if (_list[index].tag == 0) {
      //更改状态
      _list[index].tag = 1;
      _controllerList[index].toggleCard();

      setState(() {
      });
      if (_list[index].type == 1) {
        isGameOver = true;
        //点击炸弹
        showToast("游戏结束");
        Timer(const Duration(milliseconds: 500), () {
          openLeftCard(index);
        });
        // restart();
      } else {
        checkIsComplete();
      }
    }
  }

  ///翻开或关闭所有的卡片
  void toggleAllCard() {
    for (var element in _controllerList) {
      element.toggleCard();
    }
  }

  ///翻开剩余卡片,除了翻开的地雷
  void openLeftCard(int boomIndex) {
    for (int i = 0; i < _controllerList.length; i++) {
      var controller = _controllerList[i];
      var state = controller.state;
      if (state != null && state.isFront && i != boomIndex) {
        //所有卡片全部翻一遍
        Timer(Duration(milliseconds: i * 50), () {
          controller.toggleCard();
        });
      }
    }
  }

  ///检测是否翻开所有钻石
  void checkIsComplete() {
    var leftDiamondCount = 0;
    for (var element in _list) {
      if (element.type == 0 && element.tag == 0) {
        leftDiamondCount++;
      }
    }
    if (leftDiamondCount == 0) {
      //赢了
      showToast("你真棒");
      restart();
    }
  }

  ///展示吐司
  void showToast(String msg) {
    Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }
}

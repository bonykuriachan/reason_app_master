import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'coinCard.dart';
import 'coinModel.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

const MethodChannel platform =
MethodChannel('reasonLabs');

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

String? selectedNotificationPayload;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _requestPermissions();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  WidgetsFlutterBinding.ensureInitialized();


  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@drawable/rl');

  /// Note: permissions aren't requested here just to demonstrate that can be
  /// done later
  final IOSInitializationSettings initializationSettingsIOS =
  IOSInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: (
          int id,
          String? title,
          String? body,
          String? payload,
          ) async {
      });
  const MacOSInitializationSettings initializationSettingsMacOS =
  MacOSInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: initializationSettingsMacOS
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String? payload) async {
        if (payload != null) {
          debugPrint('notification payload: $payload');
        }
        selectedNotificationPayload = payload;
      });
  runApp(MyApp(prefs));
}

void _requestPermissions() {
  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );
  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      MacOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );
}

class MyApp extends StatelessWidget {
  SharedPreferences prefs;

  // This widget is the root of your application.
  MyApp(this.prefs);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Home(prefs),
    );
  }
}

class Home extends StatefulWidget {
  SharedPreferences prefs;

  Home(this.prefs);

  @override
  _HomeState createState() => _HomeState();
}

 class _HomeState extends State<Home> {

  late TextEditingController minController;
  late TextEditingController maxController;
  String minVariable = "Enter you min range";
  String maxVariable = "Enter you max range";



  Future<List<Coin>> fetchCoin() async {
    String data = await platform.invokeMethod("startService");
    debugPrint(data);
    final response = await http.get(Uri.parse(
        'https://api.coingecko.com/api/v3/coins/markets?symbol=bitcoin&vs_currency=usd&order=market_cap_desc&per_page=1&page=1&sparkline=false%27'));

    if (response.statusCode == 200) {
      List<dynamic> values = [];
      values = json.decode(response.body);
      if (values.length > 0) {
        for (int i = 0; i < values.length; i++) {
          if (values[i] != null) {
            Map<String, dynamic> map = values[i];
            final coinFromBackend = Coin.fromJson(map);
            final index = coinList.indexWhere((element) => element.symbol == coinFromBackend.symbol);
            if (index == -1) {
              coinList.add(coinFromBackend);
            } else {
              coinList.insert(index, coinFromBackend);
            }
          }
        }
      }
      return coinList;

    } else {
      throw Exception('Failed to load coins');
    }
  }
  @override
  void initState() {

    minController = TextEditingController();
    maxController = TextEditingController();
    fetchCoin();
    Timer.periodic(
        Duration(seconds: 5), (timer) =>
          setState(() {
            fetchCoin();

           }));
    super.initState();
  }
  @override
  void dispose() {
    minController.dispose();
    maxController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // appBar: AppBar(
        //   title: Text('Reason Labs'),
        // ),
        body: Padding(
            padding: EdgeInsets.all(10),
            child: ListView(
              children: <Widget>[
                Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(10),
                    child: Text(
                      'ReasonLabs',
                      style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w500,
                          fontSize: 30),
                    )),
                // Container(
                //     alignment: Alignment.center,
                //     padding: EdgeInsets.all(10),
                //     child: CoinName(coinList[0])),
                FutureBuilder<List<Coin>>(
                  future: fetchCoin(),
                  builder: (context, snapshot) {
                    Widget buildCoinName() => Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.all(10),
                        child: CoinName());
                    if(coinList.isNotEmpty&&widget.prefs.getString('maxRange')!=null&&widget.prefs.getString('maxRange')!='') {
                      if ((coinList[0].price?.toDouble() ?? 0) >
                          (double.tryParse(widget.prefs.getString('maxRange')!) ?? 0)) {
                        _showNotification('High Price Change');
                      }
                    }
                    if(coinList.isNotEmpty&&widget.prefs.getString('minRange')!=null&&widget.prefs.getString('minRange')!='') {
                     if ((coinList[0].price?.toDouble() ?? 0) <
                          (double.tryParse(widget.prefs.getString('minRange')!) ?? 0)) {
                        _showNotification('Low Price Change');
                      }
                    }
                    if(snapshot.connectionState == ConnectionState.done) {
                      if(snapshot.hasData) {
                        coinList = snapshot.data!;
                        return buildCoinName();
                      } else {
                        if(coinList.isNotEmpty) {
                          return buildCoinName();
                        }
                        return const SizedBox();
                      }

                    } else {
                      if(coinList.isNotEmpty) {
                        return buildCoinName();
                      }
                      return const SizedBox();
                    }

                  },
                ),
                FutureBuilder<String?>(
                    future:
                        Future.sync(() => widget.prefs.getString('minRange')),
                    builder: (Context, Snapshot) {
                      if (Snapshot.connectionState == ConnectionState.done) {
                        minVariable = Snapshot.data ?? "Enter you min range";
                      }

                      return Container(
                        padding: EdgeInsets.all(10),
                        child: TextField(
                          controller: minController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: minVariable,
                          ),
                        ),
                      );
                    }),
                FutureBuilder<String?>(future:
                        Future.sync(() => widget.prefs.getString('maxRange')),
                    builder: (Context, Snapshot) {
                      if (Snapshot.connectionState == ConnectionState.done) {
                        maxVariable = Snapshot.data ?? "Enter you max range";
                      }
                      return Container(
                        padding: EdgeInsets.all(10),
                        child: TextField(
                          controller: maxController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: maxVariable,
                          ),
                        ),
                      );
                    }),
                Container(
                    height: 80,
                    padding: EdgeInsets.fromLTRB(10, 20, 10, 10),
                    child: RaisedButton(
                      textColor: Colors.white,
                      color: Colors.purple,
                      child: Text('Update'),
                      onPressed: () {
                        setState(() {
                          _storemMinMaxRange(minController.text.toString(),
                              maxController.text.toString());
                        });
                      },
                    )),
              ],
            )));
  }
  void showInSnackBar(BuildContext con,String value) {
      // Scaffold.of(con).showSnackBar(new SnackBar(
      //     content: new Text(value)
      // ));
  }
  Future _storemMinMaxRange(String min, String max) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if((min!='Enter you min range')||(min!='')){
    prefs.setString('minRange', min);
    }
    if((min!='Enter you max range')||(max!='')) {
      prefs.setString('maxRange', max);
    }
  }


}

class CoinName extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CoinCard(
      name: coinList[0].name,
      symbol: coinList[0].symbol,
      imageUrl: coinList[0].imageUrl,
      price: coinList[0].price?.toDouble(),
      change: coinList[0].change?.toDouble(),
      changePercentage: coinList[0].changePercentage?.toDouble(),
    );
  }
}
Future<void> _showNotification(String alert) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails('ReasonLabs', 'Alert',
      playSound: true,
      styleInformation: DefaultStyleInformation(true, true));
  const IOSNotificationDetails iOSPlatformChannelSpecifics =
  IOSNotificationDetails(presentSound: true);
  const MacOSNotificationDetails macOSPlatformChannelSpecifics =
  MacOSNotificationDetails(presentSound: true);
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
      macOS: macOSPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(0, '<b>ReasonLabs</b> Alert',
      '<b>BTC</b>'+alert, platformChannelSpecifics);
}

Future<void> _showNotificationCustomSound() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'ReasonLab',
    'your other channel description',
    sound: RawResourceAndroidNotificationSound('slow_spring_board'),
  );
  const IOSNotificationDetails iOSPlatformChannelSpecifics =
  IOSNotificationDetails(sound: 'slow_spring_board.aiff');
  const MacOSNotificationDetails macOSPlatformChannelSpecifics =
  MacOSNotificationDetails(sound: 'slow_spring_board.aiff');
  final NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
    macOS: macOSPlatformChannelSpecifics
  );
  await flutterLocalNotificationsPlugin.show(
    0,
    'custom sound notification title',
    'custom sound notification body',
    platformChannelSpecifics,
  );
}

Future<void> onSelectNotification(String payload) async {
  if (payload != null) {
    debugPrint('notification payload: ' + payload);
  }
}

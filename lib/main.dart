// import 'dart:async';
// import 'dart:convert';
// import 'dart:developer';
// import 'dart:isolate';

// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_isolate/flutter_isolate.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:path_provider/path_provider.dart';

// import 'data_bloc.dart';
// import 'datamodel.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   final appDocumentDir = await getApplicationDocumentsDirectory();
//   Hive.init(appDocumentDir.path);
//   Hive.registerAdapter(DataModelAdapter());
//   await Hive.openBox<DataModel>('dataBox');

//   // final ReceivePort receivePort = ReceivePort();
//   // FlutterIsolate.spawn(backgroundIsolate, receivePort.sendPort);
//   final ReceivePort receivePort = ReceivePort();
//   FlutterIsolate? isolate;

//   void spawnBackgroundIsolate() async {
//     isolate = await FlutterIsolate.spawn(
//       backgroundIsolateEntryPoint,
//       receivePort.sendPort,
//     );
//   }

//   spawnBackgroundIsolate();
//   final Box<DataModel> dataBox = Hive.box<DataModel>('dataBox');
//   final DataBloc dataBloc = DataBloc(dataBox: dataBox);
//   dataBloc.add(FetchData());
//   receivePort.listen((message) {
//     if (message is String) {
//       final String serializedDateTime = message;
//       final DateTime dateTime = DateTime.parse(jsonDecode(serializedDateTime));
//       dataBloc.add(AddData(dateTime));
//     }
//   });
//   runApp(MyApp(dataBloc: dataBloc));
// }

// class MyApp extends StatelessWidget {
//   final DataBloc dataBloc;

//   const MyApp({super.key, required this.dataBloc});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter App',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: Scaffold(
//         appBar: AppBar(
//           title: const Text('Data List'),
//         ),
//         body: BlocBuilder<DataBloc, DataState>(
//           bloc: dataBloc,
//           builder: (context, state) {
//             if (state is DataInitial) {
//               dataBloc
//                   .add(FetchData()); // Add this line to handle FetchData event
//               return const Center(
//                 child: CircularProgressIndicator(),
//               );
//             } else if (state is DataLoaded) {
//               final dataList = state.dataList;
//               return ListView.builder(
//                 itemCount: dataList.length,
//                 itemBuilder: (context, index) {
//                   final data = dataList[index];
//                   return ListTile(
//                     title: Text(data.dateTime.toString()),
//                   );
//                 },
//               );
//             } else if (state is DataError) {
//               return Center(
//                 child: Text(state.message),
//               );
//             } else {
//               return Container();
//             }
//           },
//         ),
//       ),
//     );
//   }
// }

// void backgroundIsolateEntryPoint(SendPort sendPort) {
//   Timer.periodic(const Duration(seconds: 1), (Timer t) {
//     final DateTime now = DateTime.now();
//     log('${now.hour},${now.minute},${now.second}');
//     final String serializedDateTime = jsonEncode(now.toIso8601String());
//     sendPort.send(serializedDateTime);
//   });
// }
import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox<DateTime>('data');
  Box<DateTime> box = Hive.box('data');
  // SendPort mainToIsolateStream = await initIsolate(db: box);
  // mainToIsolateStream.send('Sending from main');

  runApp(const MyApp());
  await AndroidAlarmManager.periodic(
      const Duration(seconds: 1), 0, myIsolateCallback);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Box<DateTime> box = Hive.box('data');
  List<DateTime> listOfData = [];
  Stream<List<DateTime>>? dataStream;
  @override
  void initState() {
    super.initState();
    dataStream = getDataStream();
  }

  void listenForDataUpdates() async {
    ReceivePort isolateToMainStream = ReceivePort();
    isolateToMainStream.listen((data) {
      if (data is DateTime) {
        setState(() {
          box.add(data);
          listOfData = box.values.toList();
        });
      }
    });

    SendPort mainToIsolateStream = await initIsolate(db: box);
    mainToIsolateStream.send(isolateToMainStream.sendPort);
  }

  Stream<List<DateTime>> getDataStream() async* {
    StreamController<List<DateTime>> streamController =
        StreamController<List<DateTime>>();
    SendPort? mainToIsolateStream;

    streamController.onListen = () {
      ReceivePort isolateToMainStream = ReceivePort();
      isolateToMainStream.listen((data) {
        if (data is SendPort) {
          mainToIsolateStream = data;
        } else if (data is DateTime) {
          box.add(data);
          final listOfData = box.values.toList();
          streamController.add(listOfData);
        }
      });

      Isolate.spawn(
        myIsolate,
        isolateToMainStream.sendPort,
      );
    };

    streamController.onCancel = () {
      mainToIsolateStream?.send(null);
      streamController.close();
    };

    yield* streamController.stream;
  }

  @override
  void dispose() {
    Hive.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => pre.clear(),
          child: const Text(
            'Flutter Demo',
          ),
        ),
      ),
      body: StreamBuilder<List<DateTime>>(
        stream: dataStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final listOfData = snapshot.data!;
            return ListView.builder(
              itemCount: listOfData.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    "${listOfData[index].hour} : ${listOfData[index].minute} : ${listOfData[index].second}",
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            return const Center(
              child: Text('Error'),
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}

Future<SendPort> initIsolate({required Box<DateTime> db}) async {
  Completer<SendPort> completer = Completer<SendPort>();
  ReceivePort isolateToMainStream = ReceivePort();
  isolateToMainStream.listen((data) {
    if (data is SendPort) {
      SendPort mainToIsolateStream = data;
      completer.complete(mainToIsolateStream);
    } else {
      initializeServices();
      FlutterBackgroundService().invoke('setAsBackground');
      db.add(data);
      List<DateTime> listOfData = db.values.toList();
      log('List values$listOfData');
      log('[isolateToMainStream] $data');
    }
  });

  await Isolate.spawn(
    myIsolate,
    isolateToMainStream.sendPort,
  );
  return completer.future;
}

void myIsolate(SendPort isolateToMainStream) {
  Timer.periodic(const Duration(seconds: 1), (timer) {
    DateTime now = DateTime.now();
    isolateToMainStream.send(now);
  });
}

void myIsolateCallback() {
  DateTime now = DateTime.now();
  log('Data from background: $now');

  Box<DateTime> box = Hive.box('data');
  box.add(now);
}

Future<void> initializeServices() async {
  final services = FlutterBackgroundService();
  await services.configure(
      iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onStart,
          onBackground: onIosBackground),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: true,
      ));
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance serviceInstance) async {
  // const platform =  MethodChannel('com.example/background_fetch');
  // platform.invokeMethod('enableBackgroundFetch');
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
onStart(ServiceInstance serviceInstance) async {
  WidgetsFlutterBinding.ensureInitialized();
  // HiveManager.initialize();
  Box<DateTime> box = Hive.box('data');

  DartPluginRegistrant.ensureInitialized();
  if (serviceInstance is AndroidServiceInstance) {
    serviceInstance.on('setAsForeground').listen((event) {
      serviceInstance.setAsForegroundService();
    });
    serviceInstance.on('setAsBackground').listen((event) {
      serviceInstance.setAsBackgroundService();
    });
  }
  serviceInstance.on('stopService').listen((event) {
    serviceInstance.stopSelf();
  });
  Timer.periodic(
    const Duration(seconds: 1),
    (timer) async {
      if (serviceInstance is AndroidServiceInstance) {
        if (await serviceInstance.isForegroundService()) {
          serviceInstance.setForegroundNotificationInfo(
            title: "This demo application is runnig in background",
            content: "",
          );
        }
      }
      Position currentLocation = await getCurrentLocation();
      var battery = Battery();
      int? level = await battery.batteryLevel;
      log("${currentLocation.latitude}   ${DateTime.now()}     $level");
      // DataBaseServices().addLocationData(
      //   locationModel: LocationModel(
      //     lat: currentLocation.latitude.toString(),
      //     lon: currentLocation.longitude.toString(),
      //     batteryLevel: level.toString(),
      //     currentTime: DateTime.now(),
      //   ),
      // );
      serviceInstance.invoke('update');
    },
  );
}

Future<Position> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location sevices are disabled');
  }
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error("Location permissions are denied");
    }
  }
  if (permission == LocationPermission.deniedForever) {
    return Future.error(
        "Location permissions are perminently denied, We cannot access it");
  }
  return await Geolocator.getCurrentPosition();
}

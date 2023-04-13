import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

const String mainId = 'main';
const String backgroundId = 'background';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Logger.root.onRecord.listen(ConsoleOutput().log);
  final Logger log = Logger('Main');
  log.info('Started');

  log.info('Starting background isolate');
  const methodChannel = MethodChannel('com.example.demo/isolate');

  await methodChannel.invokeMethod('startService');

  maybeCleanNameServer(mainId);
  final ReceivePort port = ReceivePort(mainId);
  IsolateNameServer.registerPortWithName(port.sendPort, mainId);

  port.listen((message) {
    log.info('Received object from background: $message');
  });

  log.info('Sending to background isolate.');

  final sendPort = await waitForSendPort(backgroundId);

  /// Reset any stored value in the background isolate
  sendPort.send(const Value(0));

  runApp(MyApp(sendPort: sendPort));
}

@pragma('vm:entry-point')
Future<void> background() async {
  final Logger log = Logger('Background');
  Logger.root.onRecord.listen(ConsoleOutput().log);
  log.info('Started');

  /// Value stored here from the foreground
  int value = 0;

  maybeCleanNameServer(backgroundId);

  final ReceivePort port = ReceivePort(backgroundId);
  IsolateNameServer.registerPortWithName(port.sendPort, backgroundId);

  log.info('Sending to main isolate.');
  final sendPort = IsolateNameServer.lookupPortByName(mainId);

  /// Listen for events - and if it's a [Value] then store the value locally
  /// and ack back (which shows bidirectional comms)
  port.listen((message) {
    log.info('Received object from main: $message');
    if (message is Value) {
      value = message.count;
      sendPort?.send(Ack.fromValue(message));
    }
  });

  /// Every 5 seconds, simulate some ongoing background process
  /// and report the times the button has been pressed.
  Timer.periodic(const Duration(seconds: 5), (timer) {
    log.info('Simulated Activity - Current Value: $value');
  });
}

/// If a port is already registered - clean it up
void maybeCleanNameServer(String name) {
  if (IsolateNameServer.lookupPortByName(name) != null) {
    IsolateNameServer.removePortNameMapping(name);
  }
}

/// Wait for a sendport at the given [name] to appear in the [IsolateNameServer]
Future<SendPort> waitForSendPort(String name) async {
  final sendPort = IsolateNameServer.lookupPortByName(name);
  if (sendPort == null) {
    return Future.delayed(const Duration(milliseconds: 100))
        .then((_) => waitForSendPort(name));
  }

  return sendPort;
}

class Value {
  final int count;

  const Value(this.count);

  @override
  String toString() => 'Value($count)';
}

class Ack {
  final int count;

  Ack._(this.count);

  factory Ack.fromValue(Value value) => Ack._(value.count);

  @override
  String toString() => 'Ack($count)';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.sendPort});

  final SendPort sendPort;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(
          title: 'Flutter Demo Home Page',
          onIncrement: (value) {
            sendPort.send(Value(value));
          }),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.onIncrement});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final void Function(int) onIncrement;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
      widget.onIncrement(_counter);
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

/// A log output handler, responsible for pushing a provided [LogRecord]
/// to it's destination (console or otherwise)
abstract class LogOutput {
  void log(LogRecord record);
}

class ConsoleOutput extends LogOutput {
  @override
  void log(LogRecord record) {
    //ignore: avoid_print
    print(
        '${record.level.name} · ${record.time} · ${record.loggerName} · ${record.message}');

    if (record.error != null) {
      //ignore: avoid_print
      print(
          '${record.level.name} · ${record.time} · ${record.loggerName}  · ${record.error}');
      //ignore: avoid_print
      print(
          '${record.level.name} · ${record.time} · ${record.loggerName}  · ${record.stackTrace}');
    }
  }
}

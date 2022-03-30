import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_fetch/background_fetch.dart';

const String eventKey = "fetch_events";

/// This "Headless Task" is run when app is terminated.
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  print('[BackgroundFetch] Headless event received.');
  print("Hey Pawan Background headless fetch is successful");
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Read fetch_events from SharedPreferences
  List<String> events = [];
  String? json = prefs.getString(eventKey);
  if (json != null) {
    events = jsonDecode(json).cast<String>();
  }
  // Add new event.
  events.insert(0, DateTime.now().toString() + ' [Headless]');
  // Persist fetch events in SharedPreferences
  prefs.setString(eventKey, jsonEncode(events));

  BackgroundFetch.finish(task.taskId);
}

void main() {
  // Enable integration testing with the Flutter Driver extension.
  // See https://flutter.io/testing/ for more info.
  runApp(MyApp());

  // Register to receive BackgroundFetch events after app is terminated.
  // Requires {stopOnTerminate: false, enableHeadless: true}
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _enabled = true;
  int _status = 0;
  List<String> _events = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // Load persisted fetch events from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? json = prefs.getString(eventKey);
    if (json != null) {
      setState(() {
        _events = jsonDecode(json).cast<String>();
      });
    }

    // Configure BackgroundFetch.
    BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
      ),
      _onBackgroundFetch,
      _onBackgroundTimeout,
    ).then((int status) {
      print("Hey Pawan Background fetch is successful");
      print('[BackgroundFetch] SUCCESS: $status');
      setState(() {
        _status = status;
      });
    }).catchError((e) {
      print('[BackgroundFetch] ERROR: $e');
      setState(() {
        _status = e;
      });
    });

    // Optionally query the current BackgroundFetch status.
    int status = await BackgroundFetch.status;
    setState(() {
      _status = status;
    });

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  void _onBackgroundTimeout(String taskId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // This task has exceeded its allowed running-time.  You must stop what you're doing and immediately .finish(taskId)
    print("[BackgroundFetch] TIMEOUT taskId: $taskId");
    setState(() {
      _events.insert(0, DateTime.now().toString());
    });
    // Persist fetch events in SharedPreferences
    prefs.setString(eventKey, jsonEncode(_events));

    BackgroundFetch.finish(taskId);
  }

  void _onBackgroundFetch(String taskId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // This is the fetch-event callback.
    print('[BackgroundFetch] Event received');
    setState(() {
      _events.insert(0, DateTime.now().toString());
    });
    // Persist fetch events in SharedPreferences
    prefs.setString(eventKey, jsonEncode(_events));

    // IMPORTANT:  You must signal completion of your fetch task or the OS can punish your app
    // for taking too long in the background.
    BackgroundFetch.finish(taskId);
  }

  void _onClickEnable(enabled) {
    setState(() {
      _enabled = enabled;
    });
    if (enabled) {
      BackgroundFetch.start().then((int status) {
        print('[BackgroundFetch] start success: $status');
      }).catchError((e) {
        print('[BackgroundFetch] start FAILURE: $e');
      });
    } else {
      BackgroundFetch.stop().then((int status) {
        print('[BackgroundFetch] stop success: $status');
      });
    }
  }

  void _onClickStatus() async {
    int status = await BackgroundFetch.status;
    print('[BackgroundFetch] status: $status');
    setState(() {
      _status = status;
    });
  }

  void _onClickClear() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(eventKey);
    setState(() {
      _events = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('BackgroundFetch Example',
              style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.amberAccent,
          actions: <Widget>[
            Switch(value: _enabled, onChanged: _onClickEnable),
          ],
        ),
        body: (_events.isEmpty)
            ? const Center(
                child: Text(
                    'Waiting for fetch events.  Simulate one.\n [Android] \$ ./scripts/simulate-fetch\n [iOS] XCode->Debug->Simulate Background Fetch'),
              )
            : ListView.builder(
                itemCount: _events.length,
                itemBuilder: (BuildContext context, int index) {
                  String timestamp = _events[index];
                  return InputDecorator(
                    decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.only(left: 5.0, top: 5.0, bottom: 5.0),
                        labelStyle:
                            TextStyle(color: Colors.blue, fontSize: 20.0),
                        labelText: "[background fetch event]"),
                    child: Text(
                      timestamp,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16.0,
                      ),
                    ),
                  );
                },
              ),
        bottomNavigationBar: BottomAppBar(
          child: Container(
            padding: const EdgeInsets.only(left: 5.0, right: 5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                OutlinedButton(
                  onPressed: _onClickStatus,
                  child: Text('Status: $_status'),
                ),
                OutlinedButton(
                  onPressed: () {
                    /// - scheduleTask on iOS seems only to run when the device is plugged into power. 
                    /// - scheduleTask on iOS are designed for low-priority tasks, such as purging cache files — they tend to be unreliable for mission-critical tasks. scheduleTask will never run a frequently as you want.
                    BackgroundFetch.scheduleTask(
                      TaskConfig(
                        taskId: "id.alarm",
                        delay: 10000, // 10 second or 10000 milisecond
                      ),
                    );
                  },
                  child: const Text('Scheduled 10s'),
                ),
                OutlinedButton(
                  onPressed: _onClickClear,
                  child: const Text('Clear'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

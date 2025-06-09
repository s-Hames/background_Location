import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

Future<void> checkAndRequestPermissions(BuildContext context) async {
  if (Platform.isAndroid) {
    // Check and request location permissions
    final locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      final result = await Permission.location.request();
      if (result.isDenied) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Location Permission Required'),
                  content: const Text(
                    'This app needs location permission to work properly. Please enable it in app settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await openAppSettings();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
          );
        }
      }
    }

    // Check and request notification permission
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      final result = await Permission.notification.request();
      if (result.isDenied) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Notification Permission Required'),
                  content: const Text(
                    'This app needs notification permission to show background service status. Please enable it in app settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await openAppSettings();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
          );
        }
      }
    }

    // Request battery optimization permission
    await Permission.ignoreBatteryOptimizations.request();
  } else if (Platform.isIOS) {
    // Request location permissions for iOS
    // First request when in use permission
    final locationWhenInUseStatus = await Permission.locationWhenInUse.status;
    if (!locationWhenInUseStatus.isGranted) {
      final result = await Permission.locationWhenInUse.request();
      if (result.isDenied) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Location Permission Required'),
                  content: const Text(
                    'This app needs location permission to work properly. Please enable it in Settings > Privacy > Location Services.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await openAppSettings();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
          );
        }
      }
    }

    // Then request always permission
    final locationAlwaysStatus = await Permission.locationAlways.status;
    if (!locationAlwaysStatus.isGranted) {
      final result = await Permission.locationAlways.request();
      if (result.isDenied) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Background Location Permission Required'),
                  content: const Text(
                    'This app needs background location permission to track your location when the app is not active. Please enable it in Settings > Privacy > Location Services > [App Name] > Always.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await openAppSettings();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
          );
        }
      }
    }

    // Request notification permission for iOS
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      final result = await Permission.notification.request();
      if (result.isDenied) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Notification Permission Required'),
                  content: const Text(
                    'This app needs notification permission to show background service status. Please enable it in Settings > Notifications.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await openAppSettings();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
          );
        }
      }
    }
  }
}

Future<void> initializeService() async {
  // Check if all required permissions are granted
  if (Platform.isAndroid) {
    final locationStatus = await Permission.location.status;

    if (!locationStatus.isGranted) {
      print('Location permission not granted. Please grant all permissions.');
      return;
    }
  }

  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'api_service_channel',
    'API Service',
    description: 'This channel is used for API service notifications',
    importance: Importance.high,
    enableVibration: true,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
        android: AndroidInitializationSettings('ic_bg_service_small'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'api_service_channel',
      initialNotificationTitle: 'Location Service',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final log = preferences.getStringList('log') ?? <String>[];
    log.add(
      '${DateTime.now().toIso8601String()} - iOS Background Task Started',
    );
    await preferences.setStringList('log', log);

    // Get location and send to API
    await sendLocationToApi();

    return true;
  } catch (e) {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final log = preferences.getStringList('log') ?? <String>[];
    log.add(
      '${DateTime.now().toIso8601String()} - Error in iOS background: $e',
    );
    await preferences.setStringList('log', log);
    return false;
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString("hello", "world");

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Always set as foreground service
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Location update timer
  Timer.periodic(const Duration(seconds: 6), (timer) async {
    try {
      final responseText = await sendLocationToApi();

      if (service is AndroidServiceInstance) {
        flutterLocalNotificationsPlugin.show(
          888,
          'Location Service',
          responseText,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'api_service_channel',
              'Location Service',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );

        service.setForegroundNotificationInfo(
          title: "Location Service",
          content: responseText,
        );
      }

      // Update UI
      service.invoke('update', {
        "current_date": DateTime.now().toIso8601String(),
        "response": responseText,
      });
    } catch (e) {
      String errorText = 'Error: $e';
      if (service is AndroidServiceInstance) {
        flutterLocalNotificationsPlugin.show(
          888,
          'Location Service',
          errorText,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'api_service_channel',
              'Location Service',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );
      }

      // Log the error
      final log = preferences.getStringList('log') ?? <String>[];
      log.add('${DateTime.now().toIso8601String()} - $errorText');
      await preferences.setStringList('log', log);
    }
  });
}

Future<String> sendLocationToApi() async {
  try {
    // Get current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Prepare the request body
    final Map<String, dynamic> body = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Send to API
    final response = await http.post(
      Uri.parse('http://192.168.29.21:8000/location'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    String responseText =
        response.statusCode == 200
            ? 'Location sent successfully: ${response.body}'
            : 'Error: ${response.statusCode}';

    // Log the response
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final log = preferences.getStringList('log') ?? <String>[];
    log.add('${DateTime.now().toIso8601String()} - $responseText');
    await preferences.setStringList('log', log);

    return responseText;
  } catch (e) {
    throw Exception('Failed to send location: $e');
  }
}

// Add a global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String text = "Stop Service";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndRequestPermissions(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add the navigator key here
      home: Scaffold(
        appBar: AppBar(title: const Text('Location Service')),
        body: Column(
          children: [
            StreamBuilder<Map<String, dynamic>?>(
              stream: FlutterBackgroundService().on('update'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!;
                String? response = data["response"];
                DateTime? date = DateTime.tryParse(data["current_date"]);
                return Column(
                  children: [
                    Text(response ?? 'No response yet'),
                    Text(date.toString()),
                  ],
                );
              },
            ),
            ElevatedButton(
              child: Text(text),
              onPressed: () async {
                final service = FlutterBackgroundService();
                var isRunning = await service.isRunning();
                isRunning
                    ? service.invoke("stopService")
                    : service.startService();

                setState(() {
                  text = isRunning ? 'Start Service' : 'Stop Service';
                });
              },
            ),
            ElevatedButton(
              child: const Text("Request Permissions"),
              onPressed: () => checkAndRequestPermissions(context),
            ),
            const Expanded(child: LogView()),
          ],
        ),
      ),
    );
  }
}

class LogView extends StatefulWidget {
  const LogView({Key? key}) : super(key: key);

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late final Timer timer;
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.reload();
      logs = sp.getStringList('log') ?? [];
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs.elementAt(index);
        return Text(log);
      },
    );
  }
}

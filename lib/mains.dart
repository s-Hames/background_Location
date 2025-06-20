// import 'dart:async';
// import 'dart:io' show Platform;
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:workmanager/workmanager.dart';
// import 'package:cron/cron.dart';

// import 'package:baseflow_plugin_template/baseflow_plugin_template.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geolocator_android/geolocator_android.dart';
// import 'package:geolocator_apple/geolocator_apple.dart';

// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     try {
//       final position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       final response = await http.post(
//         Uri.parse('https://fast-jwt-newuage.vercel.app'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'latitude': position.latitude,
//           'longitude': position.longitude,
//           'timestamp': DateTime.now().toIso8601String(),
//           'accuracy': position.accuracy,
//           'altitude': position.altitude,
//           'speed': position.speed,
//           'speedAccuracy': position.speedAccuracy,
//           'heading': position.heading,
//         }),
//       );

//       print('Background task completed: ${response.statusCode}');
//       return true;
//     } catch (e) {
//       print('Background task failed: $e');
//       return false;
//     }
//   });
// }

// /// Defines the main theme color.
// final MaterialColor themeMaterialColor =
//     BaseflowPluginExample.createMaterialColor(
//       const Color.fromRGBO(48, 49, 60, 1),
//     );

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Workmanager().initialize(callbackDispatcher);
//   runApp(const GeolocatorWidget());
// }

// /// Example [Widget] showing the functionalities of the geolocator plugin
// class GeolocatorWidget extends StatefulWidget {
//   /// Creates a new GeolocatorWidget.
//   const GeolocatorWidget({super.key});

//   /// Utility method to create a page with the Baseflow templating.
//   static ExamplePage createPage() {
//     return ExamplePage(
//       Icons.location_on,
//       (context) => const GeolocatorWidget(),
//     );
//   }

//   @override
//   State<GeolocatorWidget> createState() => _GeolocatorWidgetState();
// }

// class _GeolocatorWidgetState extends State<GeolocatorWidget>
//     with WidgetsBindingObserver {
//   static const String _kLocationServicesDisabledMessage =
//       'Location services are disabled.';
//   static const String _kPermissionDeniedMessage = 'Permission denied.';
//   static const String _kPermissionDeniedForeverMessage =
//       'Permission denied forever.';
//   static const String _kPermissionGrantedMessage = 'Permission granted.';

//   final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
//   final List<_PositionItem> _positionItems = <_PositionItem>[];
//   StreamSubscription<Position>? _positionStreamSubscription;
//   StreamSubscription<ServiceStatus>? _serviceStatusStreamSubscription;
//   bool positionStreamStarted = false;
//   final Cron _cron = Cron();
//   bool _isCronRunning = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _toggleServiceStatusStream();
//     _startCronJob();
//   }

//   void _startCronJob() {
//     if (!_isCronRunning) {
//       _cron.schedule(Schedule.parse('*/6 * * * * *'), () async {
//         if (positionStreamStarted) {
//           try {
//             final position = await _geolocatorPlatform.getCurrentPosition();
//             await _callApiWithLocation(position);
//             _updatePositionList(
//               _PositionItemType.log,
//               'Cron job executed at ${DateTime.now()}',
//             );
//           } catch (e) {
//             print('Error in cron job: $e');
//             _updatePositionList(_PositionItemType.log, 'Error in cron job: $e');
//           }
//         }
//       });
//       _isCronRunning = true;
//       _updatePositionList(
//         _PositionItemType.log,
//         'Cron job started - running every 6 seconds',
//       );
//     }
//   }

//   void _stopCronJob() {
//     if (_isCronRunning) {
//       _cron.close();
//       _isCronRunning = false;
//       _updatePositionList(_PositionItemType.log, 'Cron job stopped');
//     }
//   }

//   @override
//   void dispose() {
//     _stopCronJob();
//     WidgetsBinding.instance.removeObserver(this);
//     if (_positionStreamSubscription != null) {
//       _positionStreamSubscription!.cancel();
//       _positionStreamSubscription = null;
//     }
//     _stopBackgroundTask();
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.paused) {
//       // App is in background
//       if (positionStreamStarted) {
//         // Ensure location updates continue in background
//         _toggleListening();
//       }
//     } else if (state == AppLifecycleState.resumed) {
//       // App is in foreground
//       if (positionStreamStarted) {
//         _toggleListening();
//       }
//     }
//   }

//   Future<void> _startBackgroundTask() async {
//     try {
//       await Workmanager().registerPeriodicTask(
//         "locationTask",
//         "locationTask",
//         frequency: const Duration(seconds: 6),
//         constraints: Constraints(
//           networkType: NetworkType.connected,
//           requiresBatteryNotLow: true,
//           requiresCharging: false,
//           requiresDeviceIdle: false,
//           requiresStorageNotLow: false,
//         ),
//         existingWorkPolicy: ExistingWorkPolicy.replace,
//         backoffPolicy: BackoffPolicy.linear,
//         backoffPolicyDelay: const Duration(seconds: 1),
//       );
//       print('Background task registered successfully');
//       _updatePositionList(
//         _PositionItemType.log,
//         'Background task started - running every 6 seconds',
//       );
//     } catch (e) {
//       print('Error registering background task: $e');
//       _updatePositionList(
//         _PositionItemType.log,
//         'Error starting background task: $e',
//       );
//     }
//   }

//   Future<void> _stopBackgroundTask() async {
//     await Workmanager().cancelByUniqueName("locationTask");
//   }

//   PopupMenuButton _createActions() {
//     return PopupMenuButton(
//       elevation: 40,
//       onSelected: (value) async {
//         switch (value) {
//           case 1:
//             _getLocationAccuracy();
//             break;
//           case 2:
//             _requestTemporaryFullAccuracy();
//             break;
//           case 3:
//             _openAppSettings();
//             break;
//           case 4:
//             _openLocationSettings();
//             break;
//           case 5:
//             setState(_positionItems.clear);
//             break;
//           default:
//             break;
//         }
//       },
//       itemBuilder:
//           (context) => [
//             if (Platform.isIOS)
//               const PopupMenuItem(
//                 value: 1,
//                 child: Text("Get Location Accuracy"),
//               ),
//             if (Platform.isIOS)
//               const PopupMenuItem(
//                 value: 2,
//                 child: Text("Request Temporary Full Accuracy"),
//               ),
//             const PopupMenuItem(value: 3, child: Text("Open App Settings")),
//             if (Platform.isAndroid || Platform.isWindows)
//               const PopupMenuItem(
//                 value: 4,
//                 child: Text("Open Location Settings"),
//               ),
//             const PopupMenuItem(value: 5, child: Text("Clear")),
//           ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     const sizedBox = SizedBox(height: 10);

//     return BaseflowPluginExample(
//       pluginName: 'Geolocator',
//       githubURL: 'https://github.com/Baseflow/flutter-geolocator',
//       pubDevURL: 'https://pub.dev/packages/geolocator',
//       appBarActions: [_createActions()],
//       pages: [
//         ExamplePage(
//           Icons.location_on,
//           (context) => Scaffold(
//             backgroundColor: Theme.of(context).colorScheme.surface,
//             body: ListView.builder(
//               itemCount: _positionItems.length,
//               itemBuilder: (context, index) {
//                 final positionItem = _positionItems[index];

//                 if (positionItem.type == _PositionItemType.log) {
//                   return ListTile(
//                     title: Text(
//                       positionItem.displayValue,
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   );
//                 } else {
//                   return Card(
//                     child: ListTile(
//                       tileColor: themeMaterialColor,
//                       title: Text(
//                         positionItem.displayValue,
//                         style: const TextStyle(color: Colors.white),
//                       ),
//                     ),
//                   );
//                 }
//               },
//             ),
//             floatingActionButton: Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 FloatingActionButton(
//                   onPressed: () {
//                     positionStreamStarted = !positionStreamStarted;
//                     _toggleListening();
//                   },
//                   tooltip:
//                       (_positionStreamSubscription == null)
//                           ? 'Start position updates'
//                           : _positionStreamSubscription!.isPaused
//                           ? 'Resume'
//                           : 'Pause',
//                   backgroundColor: _determineButtonColor(),
//                   child:
//                       (_positionStreamSubscription == null ||
//                               _positionStreamSubscription!.isPaused)
//                           ? const Icon(Icons.play_arrow)
//                           : const Icon(Icons.pause),
//                 ),
//                 sizedBox,
//                 FloatingActionButton(
//                   onPressed: _getCurrentPosition,
//                   child: const Icon(Icons.my_location),
//                 ),
//                 sizedBox,
//                 FloatingActionButton(
//                   onPressed: _getLastKnownPosition,
//                   child: const Icon(Icons.bookmark),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Future<void> _getCurrentPosition() async {
//     final hasPermission = await _handlePermission();

//     if (!hasPermission) {
//       return;
//     }

//     final position = await _geolocatorPlatform.getCurrentPosition();
//     _updatePositionList(_PositionItemType.position, position.toString());
//   }

//   Future<bool> _handlePermission() async {
//     bool serviceEnabled;
//     LocationPermission permission;

//     // Test if location services are enabled.
//     serviceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       // Location services are not enabled don't continue
//       // accessing the position and request users of the
//       // App to enable the location services.
//       _updatePositionList(
//         _PositionItemType.log,
//         _kLocationServicesDisabledMessage,
//       );

//       return false;
//     }

//     permission = await _geolocatorPlatform.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await _geolocatorPlatform.requestPermission();
//       if (permission == LocationPermission.denied) {
//         // Permissions are denied, next time you could try
//         // requesting permissions again (this is also where
//         // Android's shouldShowRequestPermissionRationale
//         // returned true. According to Android guidelines
//         // your App should show an explanatory UI now.
//         _updatePositionList(_PositionItemType.log, _kPermissionDeniedMessage);

//         return false;
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       // Permissions are denied forever, handle appropriately.
//       _updatePositionList(
//         _PositionItemType.log,
//         _kPermissionDeniedForeverMessage,
//       );

//       return false;
//     }

//     // When we reach here, permissions are granted and we can
//     // continue accessing the position of the device.
//     _updatePositionList(_PositionItemType.log, _kPermissionGrantedMessage);
//     return true;
//   }

//   void _updatePositionList(_PositionItemType type, String displayValue) {
//     _positionItems.add(_PositionItem(type, displayValue));
//     setState(() {});
//   }

//   bool _isListening() =>
//       !(_positionStreamSubscription == null ||
//           _positionStreamSubscription!.isPaused);

//   Color _determineButtonColor() {
//     return _isListening() ? Colors.green : Colors.red;
//   }

//   void _toggleServiceStatusStream() {
//     if (_serviceStatusStreamSubscription == null) {
//       final serviceStatusStream = _geolocatorPlatform.getServiceStatusStream();
//       _serviceStatusStreamSubscription = serviceStatusStream
//           .handleError((error) {
//             _serviceStatusStreamSubscription?.cancel();
//             _serviceStatusStreamSubscription = null;
//           })
//           .listen((serviceStatus) {
//             String serviceStatusValue;
//             if (serviceStatus == ServiceStatus.enabled) {
//               if (positionStreamStarted) {
//                 _toggleListening();
//               }
//               serviceStatusValue = 'enabled';
//             } else {
//               if (_positionStreamSubscription != null) {
//                 setState(() {
//                   _positionStreamSubscription?.cancel();
//                   _positionStreamSubscription = null;
//                   _updatePositionList(
//                     _PositionItemType.log,
//                     'Position Stream has been canceled',
//                   );
//                 });
//               }
//               serviceStatusValue = 'disabled';
//             }
//             _updatePositionList(
//               _PositionItemType.log,
//               'Location service has been $serviceStatusValue',
//             );
//           });
//     }
//   }

//   Future<void> _callApiWithLocation(Position position) async {
//     try {
//       final response = await http.get(
//         Uri.parse('https://fast-jwt-newuage.vercel.app'),
//         headers: {'Content-Type': 'application/json'},
//         // body: jsonEncode({
//         //   'latitude': position.latitude,
//         //   'longitude': position.longitude,
//         //   'timestamp': DateTime.now().toIso8601String(),
//         //   'accuracy': position.accuracy,
//         //   'altitude': position.altitude,
//         //   'speed': position.speed,
//         //   'speedAccuracy': position.speedAccuracy,
//         //   'heading': position.heading,
//         // }),
//       );

//       if (response.statusCode == 200) {
//       } else {
//         print('API call failed: ${response.statusCode}');
//         _updatePositionList(
//           _PositionItemType.log,
//           'API call failed: ${response.statusCode}',
//         );
//       }
//     } catch (e) {
//       print('Error calling API: $e');
//       _updatePositionList(_PositionItemType.log, 'Error calling API: $e');
//     }
//   }

//   void _toggleListening() {
//     if (_positionStreamSubscription == null) {
//       late LocationSettings locationSettings;

//       if (Platform.isAndroid) {
//         locationSettings = AndroidSettings(
//           accuracy: LocationAccuracy.high,
//           distanceFilter: 0,
//           intervalDuration: const Duration(seconds: 5),
//           foregroundNotificationConfig: const ForegroundNotificationConfig(
//             notificationText: "Location updates are active",
//             notificationTitle: "Location Tracking",
//             enableWakeLock: true,
//           ),
//         );
//       } else if (Platform.isIOS) {
//         locationSettings = AppleSettings(
//           accuracy: LocationAccuracy.high,
//           activityType: ActivityType.fitness,
//           distanceFilter: 0,
//           pauseLocationUpdatesAutomatically: false,
//           showBackgroundLocationIndicator: true,
//         );
//       } else {
//         locationSettings = const LocationSettings(
//           accuracy: LocationAccuracy.high,
//           distanceFilter: 0,
//         );
//       }

//       final positionStream = _geolocatorPlatform.getPositionStream(
//         locationSettings: locationSettings,
//       );

//       _positionStreamSubscription = positionStream
//           .handleError((error) {
//             print('Error in location stream: $error');
//             // Don't cancel on error, just log it
//           })
//           .listen((position) {
//             // Update UI with position
//             _updatePositionList(
//               _PositionItemType.position,
//               'Lat: ${position.latitude}, Long: ${position.longitude}, Time: ${DateTime.now()}',
//             );

//             // Call API with position
//             _callApiWithLocation(position);
//           });

//       // Start background task when location tracking starts
//       if (positionStreamStarted) {
//         _startBackgroundTask();
//       }

//       // Don't pause initially if positionStreamStarted is true
//       if (!positionStreamStarted) {
//         _positionStreamSubscription?.pause();
//       }
//     }

//     setState(() {
//       if (_positionStreamSubscription == null) {
//         return;
//       }

//       String statusDisplayValue;
//       if (_positionStreamSubscription!.isPaused) {
//         _positionStreamSubscription!.resume();
//         _startBackgroundTask();
//         statusDisplayValue = 'resumed';
//       } else {
//         _positionStreamSubscription!.pause();
//         _stopBackgroundTask();
//         statusDisplayValue = 'paused';
//       }

//       _updatePositionList(
//         _PositionItemType.log,
//         'Listening for position updates $statusDisplayValue',
//       );
//     });
//   }

//   void _getLastKnownPosition() async {
//     final position = await _geolocatorPlatform.getLastKnownPosition();
//     if (position != null) {
//       _updatePositionList(_PositionItemType.position, position.toString());
//     } else {
//       _updatePositionList(
//         _PositionItemType.log,
//         'No last known position available',
//       );
//     }
//   }

//   void _getLocationAccuracy() async {
//     final status = await _geolocatorPlatform.getLocationAccuracy();
//     _handleLocationAccuracyStatus(status);
//   }

//   void _requestTemporaryFullAccuracy() async {
//     final status = await _geolocatorPlatform.requestTemporaryFullAccuracy(
//       purposeKey: "TemporaryPreciseAccuracy",
//     );
//     _handleLocationAccuracyStatus(status);
//   }

//   void _handleLocationAccuracyStatus(LocationAccuracyStatus status) {
//     String locationAccuracyStatusValue;
//     if (status == LocationAccuracyStatus.precise) {
//       locationAccuracyStatusValue = 'Precise';
//     } else if (status == LocationAccuracyStatus.reduced) {
//       locationAccuracyStatusValue = 'Reduced';
//     } else {
//       locationAccuracyStatusValue = 'Unknown';
//     }
//     _updatePositionList(
//       _PositionItemType.log,
//       '$locationAccuracyStatusValue location accuracy granted.',
//     );
//   }

//   void _openAppSettings() async {
//     final opened = await _geolocatorPlatform.openAppSettings();
//     String displayValue;

//     if (opened) {
//       displayValue = 'Opened Application Settings.';
//     } else {
//       displayValue = 'Error opening Application Settings.';
//     }

//     _updatePositionList(_PositionItemType.log, displayValue);
//   }

//   void _openLocationSettings() async {
//     final opened = await _geolocatorPlatform.openLocationSettings();
//     String displayValue;

//     if (opened) {
//       displayValue = 'Opened Location Settings';
//     } else {
//       displayValue = 'Error opening Location Settings';
//     }

//     _updatePositionList(_PositionItemType.log, displayValue);
//   }
// }

// enum _PositionItemType { log, position }

// class _PositionItem {
//   _PositionItem(this.type, this.displayValue);

//   final _PositionItemType type;
//   final String displayValue;
// }

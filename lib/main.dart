import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:image/image.dart' as image;
import 'package:learnnotification/second_page.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'home_pagwe.dart';

int id = 0;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Streams are created so that app can respond to notification-related events
/// since the plugin is initialised in the `main` function
final StreamController<ReceivedNotification> didReceiveLocalNotificationStream =
    StreamController<ReceivedNotification>.broadcast();

final StreamController<String?> selectNotificationStream =
    StreamController<String?>.broadcast();

const MethodChannel platform =
    MethodChannel('dexterx.dev/flutter_local_notifications_example');

const String portName = 'notification_send_port';

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

/// A notification action which triggers a url launch event
const String urlLaunchActionId = 'id_1';

/// A notification action which triggers a App navigation event
const String navigationActionId = 'id_3';

/// Defines a iOS/MacOS notification category for text input actions.
const String darwinNotificationCategoryText = 'textCategory';

/// Defines a iOS/MacOS notification category for plain actions.
const String darwinNotificationCategoryPlain = 'plainCategory';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // ignore: avoid_print
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    // ignore: avoid_print
    print(
        'notification action tapped with input: ${notificationResponse.input}');
  }
}

/// IMPORTANT: running the following code on its own won't work as there is
/// setup required for each platform head project.
///
/// Please download the complete example app from the GitHub repository where
/// all the setup has been done
Future<void> main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  await _configureLocalTimeZone();

  final NotificationAppLaunchDetails? notificationAppLaunchDetails = !kIsWeb &&
          Platform.isLinux
      ? null
      : await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  String initialRoute = HomePage.routeName;
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    selectedNotificationPayload =
        notificationAppLaunchDetails!.notificationResponse?.payload;
    print("selectedNotificationPayload");
    print(selectedNotificationPayload);
    initialRoute = SecondPage.routeName;
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');

  final List<DarwinNotificationCategory> darwinNotificationCategories =
      <DarwinNotificationCategory>[
    DarwinNotificationCategory(
      darwinNotificationCategoryText,
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.text(
          'text_1',
          'Action 1',
          buttonTitle: 'Send',
          placeholder: 'Placeholder',
        ),
      ],
    ),
    DarwinNotificationCategory(
      darwinNotificationCategoryPlain,
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain('id_1', 'Action 1'),
        DarwinNotificationAction.plain(
          'id_2',
          'Action 2 (destructive)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
        DarwinNotificationAction.plain(
          navigationActionId,
          'Action 3 (foreground)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.foreground,
          },
        ),
        DarwinNotificationAction.plain(
          'id_4',
          'Action 4 (auth required)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.authenticationRequired,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    )
  ];

  /// Note: permissions aren't requested here just to demonstrate that can be
  /// done later
  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    onDidReceiveLocalNotification:
        (int id, String? title, String? body, String? payload) async {
      didReceiveLocalNotificationStream.add(
        ReceivedNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        ),
      );
    },
    notificationCategories: darwinNotificationCategories,
  );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) {
      switch (notificationResponse.notificationResponseType) {
        case NotificationResponseType.selectedNotification:
          selectNotificationStream.add(notificationResponse.payload);
          break;
        case NotificationResponseType.selectedNotificationAction:
          if (notificationResponse.actionId == navigationActionId) {
            selectNotificationStream.add(notificationResponse.payload);
          }
          break;
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  runApp(
    MaterialApp(
      initialRoute: initialRoute,
      routes: <String, WidgetBuilder>{
        HomePage.routeName: (_) => HomePage(notificationAppLaunchDetails),
        SecondPage.routeName: (_) => SecondPage(selectedNotificationPayload)
      },
    ),
  );
}




Future<void> _configureLocalTimeZone() async {
  if (kIsWeb || Platform.isLinux) {
    return;
  }
  tz.initializeTimeZones();
  final String? timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName!));
}

Future<void> showLinuxNotificationWithBodyMarkup() async {
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with body markup',
    '<b>bold text</b>\n'
        '<i>italic text</i>\n'
        '<u>underline text</u>\n'
        'https://example.com\n'
        '<a href="https://example.com">example.com</a>',
    null,
  );
}

Future<void> showLinuxNotificationWithCategory() async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    category: LinuxNotificationCategory.emailArrived,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with category',
    null,
    notificationDetails,
  );
}

Future<void> showLinuxNotificationWithByteDataIcon() async {
  final ByteData assetIcon = await rootBundle.load(
    'icons/app_icon_density.png',
  );
  final image.Image? iconData = image.decodePng(assetIcon.buffer.asUint8List());
  final Uint8List iconBytes = iconData!.getBytes();
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    icon: ByteDataLinuxIcon(
      LinuxRawIconData(
        data: iconBytes,
        width: iconData.width,
        height: iconData.height,
        channels: 4,
        // The icon has an alpha channel
        hasAlpha: true,
      ),
    ),
  );
  final NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with byte data icon',
    null,
    notificationDetails,
  );
}

Future<void> showLinuxNotificationWithPathIcon(String path) async {
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(icon: FilePathLinuxIcon(path));
  final NotificationDetails platformChannelSpecifics = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    0,
    'notification with file path icon',
    null,
    platformChannelSpecifics,
  );
}

Future<void> showLinuxNotificationWithThemeIcon() async {
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    icon: ThemeLinuxIcon('media-eject'),
  );
  final NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with theme icon',
    null,
    notificationDetails,
  );
}

Future<void> showLinuxNotificationWithThemeSound() async {
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    sound: ThemeLinuxSound('message-new-email'),
  );
  final NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with theme sound',
    null,
    notificationDetails,
  );
}

Future<void> showLinuxNotificationWithCriticalUrgency() async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    urgency: LinuxNotificationUrgency.critical,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with critical urgency',
    null,
    notificationDetails,
  );
}

Future<void> showLinuxNotificationWithTimeout() async {
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    timeout: LinuxNotificationTimeout.fromDuration(
      const Duration(seconds: 1),
    ),
  );
  final NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with timeout',
    null,
    notificationDetails,
  );
}

Future<void> showLinuxNotificationSuppressSound() async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    suppressSound: true,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'suppress notification sound',
    null,
    notificationDetails,
  );
}

Future<void> showLinuxNotificationTransient() async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    transient: true,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'transient notification',
    null,
    notificationDetails,
  );
}

Future<void> showLinuxNotificationResident() async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    resident: true,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'resident notification',
    null,
    notificationDetails,
  );
}

Future<void> showLinuxNotificationDifferentLocation() async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(location: LinuxNotificationLocation(10, 10));
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification on different screen location',
    null,
    notificationDetails,
  );
}

Future<LinuxServerCapabilities> getLinuxCapabilities() =>
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            LinuxFlutterLocalNotificationsPlugin>()!
        .getCapabilities();



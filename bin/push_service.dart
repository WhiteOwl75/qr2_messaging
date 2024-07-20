import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
final serviceAccountJson = File('transport-7ee79-firebase-adminsdk-5jrj3-7f564a0dea.json').readAsStringSync();

const String firebaseMessagingUrl = 'https://fcm.googleapis.com/v1/projects/transport-7ee79/messages:send';






Future<void> globalPush(title, body,topic) async {
  // Load the service account credentials
  final serviceAccountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

  // Get an authenticated HTTP client
  final client = await clientViaServiceAccount(
    serviceAccountCredentials,
    [ 'https://www.googleapis.com/auth/firebase.messaging' ],
  );

  // Create the message payload


  final response = await client.post(
    Uri.parse(firebaseMessagingUrl),
    headers: { 'Content-Type': 'application/json' },
    body: jsonEncode({
      "message": {
        "topic": topic,
        "notification": {
          "title": title,
          "body": body,
        },
        "data": {"story_id": "story_12345"}
      }
    }),
  );

  if (response.statusCode == 200) {
    print('Message sent successfully');
  } else {
    print('Failed to send message: ${response.statusCode}');
    print('Response body: ${response.body}');
  }

  client.close();
}



Future<void> localPush(token, title, body) async {
  // Load the service account credentials
  final serviceAccountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

  // Get an authenticated HTTP client
  final client = await clientViaServiceAccount(
    serviceAccountCredentials,
    [ 'https://www.googleapis.com/auth/firebase.messaging' ],
  );

  // Create the message payload


  final response = await client.post(
    Uri.parse(firebaseMessagingUrl),
    headers: { 'Content-Type': 'application/json' },
    body: jsonEncode( {
      "message": {
        "token": token,
        "notification": {
          "body": body,
          "title": title,
        }
      }}),
  );

  if (response.statusCode == 200) {
    print('Message sent successfully');
  } else {
    print('Failed to send message: ${response.statusCode}');
    print('Response body: ${response.body}');
  }

  client.close();
}


// void globalPush(title, body) async {
//   Dio dio = Dio();
//   // getToken();
//   await dio.post(
//       'https://fcm.googleapis.com/v1/projects/dwd-app-3e56e/messages:send',
//       options: Options(headers: {
//         'Content-Type': 'application/json',
//         'Authorization':
//         "Bearer $tokenn",
//       }),
//       data: {
//         "message": {
//           "topic": "main",
//           "notification": {
//             "title": title,
//             "body": body,
//           },
//           "data": {"story_id": "story_12345"}
//         }
//       });
// }
//
// void localPush(token, title, body) async {
// //  getToken();
//   Dio dio = Dio();
//   await dio.post(
//       'https://fcm.googleapis.com/v1/projects/dwd-app-3e56e/messages:send',
//       options: Options(headers: {
//         'Content-Type': 'application/json',
//         'Authorization':
//         "Bearer $tokenn",
//       }),
//       data: {
//         "message": {
//           "token": token,
//           "notification": {
//             "body": body,
//             "title": title,
//           }
//         }
//       });
// }

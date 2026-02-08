// ignore_for_file: non_constant_identifier_names

import 'dart:convert';

import 'package:mshwar_app_driver/core/constant/constant.dart';
import 'package:mshwar_app_driver/core/constant/logdata.dart';
import 'package:flutter/cupertino.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class SendNotification {
  static final _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  static Future getCharacters() {
    return http.get(Uri.parse(Constant.jsonNotificationFileURL.toString()));
  }

  static Future<String> getAccessToken() async {
    Map<String, dynamic> jsonData = {};

    await getCharacters().then((response) {
      jsonData = json.decode(response.body);
    });
    final serviceAccountCredentials =
        ServiceAccountCredentials.fromJson(jsonData);

    final client =
        await clientViaServiceAccount(serviceAccountCredentials, _scopes);
    return client.credentials.accessToken.data;
  }

  static sendOneNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final String accessToken = await getAccessToken();

      final response = await http.post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(
          <String, dynamic>{
            'message': {
              'token': token,
              'notification': {'body': body, 'title': title},
              'data': payload,
            }
          },
        ),
      );

      return true;
    } catch (e) {
      return false;
    }
  }
}

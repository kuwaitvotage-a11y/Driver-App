// ignore_for_file: file_names

import 'dart:convert';

import 'package:mshwar_app_driver/core/constant/logdata.dart';
import 'package:mshwar_app_driver/features/wallet/model/payment_setting_model.dart';
import 'package:mshwar_app_driver/features/wallet/model/paypalClientToken_model.dart';
import 'package:mshwar_app_driver/service/api.dart';
import 'package:http/http.dart' as http;

import 'package:mshwar_app_driver/core/utils/Preferences.dart';

class PayPalClientTokenGen {
  static Future<PayPalClientTokenModel> paypalClientToken(
      PayPal? payPal) async {
    // final String userId = UserPreference.getUserId();
    // final String orderId = isTopup ? UserPreference.getPaymentId() : UserPreference.getOrderId();

    final url = "${API.baseUrl}payments/paypalclientid";

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'apikey': API.apiKey,
        'accesstoken': Preferences.getString(Preferences.accesstoken),
      },
      body: {
        "environment":
            payPal!.isLive.toString() == "true" ? "production" : "sandbox",
        "merchant_id": payPal.merchantId.toString(),
        "public_key": payPal.publicKey.toString(),
        "private_key": payPal.privateKey.toString(),
      },
    );

    final data = jsonDecode(response.body);
    return PayPalClientTokenModel.fromJson(data);
  }

  static paypalSettleAmount({
    required payPal,
    required nonceFromTheClient,
    required amount,
    required deviceDataFromTheClient,
  }) async {
    final url = "${API.baseUrl}payments/paypaltransaction";

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'apikey': API.apiKey,
        'accesstoken': Preferences.getString(Preferences.accesstoken),
      },
      body: {
        "environment":
            payPal!.isLive.toString() == "true" ? "production" : "sandbox",
        "merchant_id": payPal.merchantId.toString(),
        "public_key": payPal.publicKey.toString(),
        "private_key": payPal.privateKey.toString(),
        "nonceFromTheClient": nonceFromTheClient,
        "amount": amount,
        "deviceDataFromTheClient": deviceDataFromTheClient,
      },
    );

    final data = jsonDecode(response.body);

    // final dlo = PayPalCurrencyCodeErrorModel.fromJson(data);
    // print(dlo.data.message);

    return data; //PayPalClientSettleModel.fromJson(data);
  }
}

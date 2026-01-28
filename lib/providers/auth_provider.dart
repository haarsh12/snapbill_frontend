import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../models/shop_details.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  ShopDetails? _shopDetails;
  final ApiClient _apiClient = ApiClient();

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  ShopDetails? get shopDetails => _shopDetails;

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('user_token')) return false;

    _token = prefs.getString('user_token');

    // Load saved shop details if available
    if (prefs.containsKey('user_data')) {
      final data = jsonDecode(prefs.getString('user_data')!);
      _shopDetails = ShopDetails(
        shopName: data['shop_name'] ?? "My Kirana",
        ownerName: data['owner_name'] ?? "Owner",
        address: data['address'] ?? "India",
        phone1: data['phone_number'] ?? "",
        phone2: "",
      );
    }

    notifyListeners();
    return true;
  }

  Future<bool> verifyOtp({
    required String phone,
    required String otp,
    String? shopName,
    String? ownerName,
    String? address,
  }) async {
    try {
      // 1. Send Request
      final response = await _apiClient.post('/auth/verify-otp', {
        "phone_number": phone,
        "otp_code": otp,
        if (shopName != null) "shop_name": shopName,
        if (ownerName != null) "owner_name": ownerName,
        if (address != null) "address": address,
      });

      // DEBUG LOG: Check this in your Flutter Terminal!
      print("SERVER RESPONSE: $response");

      // 2. Extract Token
      _token = response['access_token'];

      // 3. Extract Data (Prioritize Backend Data)
      // If response['shop_name'] is null, it means the Backend Schema is broken.
      String finalShopName = response['shop_name'] ?? shopName ?? "My Shop";
      String finalOwnerName = response['owner_name'] ?? ownerName ?? "Owner";
      String finalAddress = response['address'] ?? address ?? "India";
      int userId = response['user_id'] ?? 0;

      // 4. Save to Storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_token', _token!);

      final userData = {
        'user_id': userId,
        'shop_name': finalShopName,
        'owner_name': finalOwnerName,
        'address': finalAddress,
        'phone_number': phone,
      };
      await prefs.setString('user_data', jsonEncode(userData));

      // 5. Update State
      _shopDetails = ShopDetails(
        shopName: finalShopName,
        ownerName: finalOwnerName,
        address: finalAddress,
        phone1: phone,
        phone2: "",
      );

      notifyListeners();
      return true;
    } catch (e) {
      print("LOGIN ERROR: $e");
      rethrow;
    }
  }

  Future<void> sendOtp(String phone, bool isLogin) async {
    try {
      await _apiClient
          .post('/auth/send-otp', {"phone_number": phone, "is_login": isLogin});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    _shopDetails = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}

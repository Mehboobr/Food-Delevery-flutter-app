// ignore_for_file: prefer_adjacent_string_concatenation, prefer_interpolation_to_compose_strings

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../../util/api-list.dart';
import '../../../../util/constant.dart';
import '../../../../widgets/custom_snackbar.dart';
import '../../../data/api/server.dart';
import '../../../data/model/response/login_model.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../profile/controllers/profile_controller.dart';

class AuthController extends GetxController {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final box = GetStorage();
  Server server = Server();
  LoginModel loginModel = LoginModel();
  bool loader = false;
  @override
  void onInit() {
    if (box.read('isLogedIn') == null) {
      box.write('isLogedIn', false);
    }
    if (box.read('isLogedIn') == true) {
      getRefreshToken();
    }
    super.onInit();
  }

  Future<LoginModel?> login(email, password) async {
    loader = true;
    update();
    
    // The API always expects 'email' field, whether it's email or username
    Map body = {'email': email, 'password': password};
    String jsonBody = json.encode(body);
    
    debugPrint('Login attempt with: $email');
    debugPrint('Request body: $jsonBody');
    
    try {
      final response = await server.postRequest(endPoint: APIList.login, body: jsonBody);
      
      debugPrint('Response status: ${response?.statusCode}');
      debugPrint('Response body: ${response?.body}');
      
      if (response != null && response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['user']['role_id'] == 3) {
          loginModel = LoginModel.fromJson(jsonResponse);
          box.write('isLogedIn', true);
          var bearerToken = 'Bearer ' + '${loginModel.token}';
          box.write('justToken', loginModel);
          box.write('token', bearerToken);
          box.write('branchId', loginModel.branchId);
          Server.initClass(token: box.read('token'));
          Get.put(ProfileController());
          Get.find<ProfileController>().getProfileData();
          update();
          customSnackbar("SUCCESS".tr, jsonResponse["message"].toString(),
              AppColor.success);
          Get.offAll(const DashboardView());
          loader = false;
          update();
          return loginModel;
        } else {
          box.write('isLogedIn', false);
          customSnackbar("ERROR".tr, "Only delivery boy can login to this app", AppColor.error);
          loader = false;
          update();
          return null;
        }
      } else if (response != null) {
        final jsonResponse = json.decode(response.body);
        debugPrint('Error response: $jsonResponse');
        
        String errorMessage = "Login failed";
        if (jsonResponse.containsKey("errors")) {
          if (jsonResponse["errors"] is Map && jsonResponse["errors"].containsKey("validation")) {
            errorMessage = jsonResponse["errors"]["validation"].toString();
          } else if (jsonResponse["errors"] is String) {
            errorMessage = jsonResponse["errors"].toString();
          }
        } else if (jsonResponse.containsKey("message")) {
          errorMessage = jsonResponse["message"].toString();
        }
        
        customSnackbar("ERROR".tr, errorMessage, AppColor.error);
        box.write('isLogedIn', false);
        loader = false;
        update();
        return null;
      } else {
        debugPrint('Response is null');
        customSnackbar("ERROR".tr, "Network error. Please check your connection.", AppColor.error);
        box.write('isLogedIn', false);
        loader = false;
        update();
        return null;
      }
    } catch (e) {
      debugPrint('Login error: $e');
      customSnackbar("ERROR".tr, "An error occurred: ${e.toString()}", AppColor.error);
      loader = false;
      update();
      return null;
    }
  }

  Future getRefreshToken() async {
    try {
      server
          .getRequest(endPoint: APIList.refreshToken! + box.read('justToken'))
          .then((response) {
        if (response != null && response.statusCode == 201) {
          final jsonResponse = json.decode(response.body);
          var bearerToken = 'Bearer ' + jsonResponse["token"].toString();
          box.write('token', bearerToken);

          update();
        } else {
          box.write('isLogedIn', false);
          box.remove('token');
          update();
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future postDeviceToken(token) async {
    loader = true;
    update();
    Map body = {
      'token': token,
    };
    String jsonBody = json.encode(body);
    try {
      server
          .postRequestWithToken(endPoint: APIList.token, body: jsonBody)
          .then((response) {
        if (response != null && response.statusCode == 200) {
          loader = false;
          update();
        } else {
          loader = false;
          update();
        }
      });
    } catch (e) {
      debugPrint(e.toString());
      loader = false;
      update();
    }
    loader = false;
    update();
  }
}

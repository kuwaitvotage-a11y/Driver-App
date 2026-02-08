import 'package:mshwar_app_driver/common/widget/custom_text.dart';
import 'package:mshwar_app_driver/common/widget/custom_app_bar.dart';
import 'package:mshwar_app_driver/core/themes/constant_colors.dart';
import 'package:mshwar_app_driver/features/dashboard/controller/dash_board_controller.dart';
import 'package:mshwar_app_driver/features/dashboard/view/dash_board.dart';
import 'package:mshwar_app_driver/features/wallet/view/wallet_screen.dart';
import 'package:mshwar_app_driver/features/wallet/controller/wallet_controller.dart';
import 'package:mshwar_app_driver/features/profile/view/my_profile_screen.dart';
import 'package:mshwar_app_driver/features/document/view/document_status_screen.dart';
import 'package:mshwar_app_driver/features/vehicle/view/vehicle_info_screen.dart';
import 'package:mshwar_app_driver/common/screens/botton_nav_bar.dart';
import 'package:mshwar_app_driver/core/constant/show_toast_dialog.dart';
import 'package:mshwar_app_driver/core/constant/constant.dart';
import 'package:mshwar_app_driver/core/themes/custom_alert_dialog.dart';
import 'package:mshwar_app_driver/core/utils/Preferences.dart';
import 'package:mshwar_app_driver/features/authentication/model/user_model.dart';
import 'dart:convert';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide WalletController;
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:mshwar_app_driver/core/utils/dark_theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Worker? _userModelWorker;
  Timer? _periodicCheckTimer;
  bool _isFirstLoad = true;
  bool _isManualToggle = false;
  bool _isRefreshing = false; // Flag to prevent Worker during refresh

  @override
  void initState() {
    super.initState();
    
    // Fetch fresh data from server when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = Get.find<DashBoardController>();
      
      // Get fresh data from server first
      await controller.getUsrData();
      
      // Then check and update toggle status without toast
      _checkAndUpdateToggleStatus(showToast: false);
      _isFirstLoad = false;
      
      // Start periodic check every 30 seconds
      _startPeriodicCheck();
    });
    
    // Listen to userModel changes with debounce to prevent multiple triggers
    final controller = Get.find<DashBoardController>();
    
    // Use debounce instead of ever to prevent multiple rapid triggers
    _userModelWorker = debounce(
      controller.userModel,
      (_) {
        if (mounted && !_isFirstLoad && !_isManualToggle && !_isRefreshing) {
          _checkAndUpdateToggleStatus(showToast: true); // Show toast only on server updates
        }
        
        // Reset flag after processing
        _isManualToggle = false;
      },
      time: const Duration(milliseconds: 500), // Wait 500ms before triggering
    );
  }

  /// Start periodic check to sync with server every 30 seconds
  void _startPeriodicCheck() {
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final controller = Get.find<DashBoardController>();
      await controller.getUsrData();
      // The Worker will handle the toggle update automatically
    });
  }

  @override
  void dispose() {
    _userModelWorker?.dispose();
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  /// Check and update toggle status based on server data
  void _checkAndUpdateToggleStatus({bool showToast = false}) async {
    if (!mounted) return;
    
    final controller = Get.find<DashBoardController>();
    final userData = controller.userModel.value.userData;
    
    if (userData != null) {
      // Get the actual online status from server
      final serverOnlineStatus = userData.online == "yes";
      final accountIsActive = userData.statut == "yes";
      
      // Store previous state to detect changes
      final previousState = controller.isActive.value;
      
      // Priority 1: Check statut first - if "no", force offline
      if (!accountIsActive) {
        if (controller.isActive.value) {
          controller.isActive.value = false;
          
          Map<String, dynamic> bodyParams = {
            'id_driver': Preferences.getInt(Preferences.userId),
            'online': 'no',
          };
          await controller.changeOnlineStatus(bodyParams);
          
          if (mounted && showToast) {
            ShowToastDialog.showToast(
              "Your account is currently inactive. You cannot go online.".tr
            );
          }
        }
      } else {
        // Priority 2: Account is active (statut = "yes"), sync with server online status
        controller.isActive.value = serverOnlineStatus;
        
        // Show toast only if state changed and showToast is true
        if (mounted && showToast && previousState != serverOnlineStatus) {
          if (serverOnlineStatus) {
            ShowToastDialog.showToast("You are now online".tr);
          } else {
            ShowToastDialog.showToast("You are now offline".tr);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final isDarkMode = themeChange.getThem();
    final controller = Get.find<DashBoardController>();

    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(
        showBackButton: false,
        titleWidget: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ConstantColors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                "assets/icons/appLogo.png",
                height: 32,
                width: 32,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomText(
                    text: "Mshwar Driver".tr,
                    size: 18,
                    weight: FontWeight.bold,
                    color: isDarkMode
                        ? AppThemeData.grey900Dark
                        : AppThemeData.grey900,
                  ),
                  Obx(() => CustomText(
                        text: controller.isActive.value
                            ? "Online".tr
                            : "Offline".tr,
                        size: 12,
                        color: controller.isActive.value
                            ? ConstantColors.primary
                            : AppThemeData.grey500,
                      )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Iconsax.menu_1,
              color:
                  isDarkMode ? AppThemeData.grey900Dark : AppThemeData.grey900,
              size: 24,
            ),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ],
      ),
      drawer: GetBuilder<DashBoardController>(
        builder: (controller) => buildAppDrawer(context, controller),
      ),
      body: GetX<DashBoardController>(
        builder: (controller) {
          final userData = controller.userModel.value.userData;
          if (userData == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Set flag to prevent Worker from interfering
              _isRefreshing = true;
              
              await controller.getUsrData();
              await Get.find<WalletController>().getTrancation();
              
              // No need to call _checkAndUpdateToggleStatus here
              // because getUsrData() already updates isActive correctly
              
              // Reset flag after a delay to allow Worker to resume
              await Future.delayed(const Duration(milliseconds: 1000));
              _isRefreshing = false;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  _buildWelcomeCard(context, controller, isDarkMode, userData),
                  const SizedBox(height: 16),

                  // Quick Stats Cards
                  _buildStatsSection(context, controller, isDarkMode, userData),
                  const SizedBox(height: 24),

                  // Active Status Toggle
                  _buildActiveToggleCard(context, controller, isDarkMode),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActionsSection(context, controller, isDarkMode),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, DashBoardController controller,
      bool isDarkMode, dynamic userData) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Driver App - Dark Navy Theme
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ConstantColors.navyLight, // Lighter navy
            ConstantColors.blue, // Dark navy
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ConstantColors.blue.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: userData.photoPath != null &&
                      userData.photoPath.toString().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: userData.photoPath.toString(),
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        width: 70,
                        height: 70,
                        color: Colors.white.withOpacity(0.2),
                        child: const Icon(
                          Iconsax.user,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                    )
                  : Container(
                      width: 70,
                      height: 70,
                      color: Colors.white.withOpacity(0.2),
                      child: const Icon(
                        Iconsax.user,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  text: "Welcome back!".tr,
                  size: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(height: 4),
                CustomText(
                  text: "${userData.prenom ?? ''} ${userData.nom ?? ''}".trim(),
                  size: 22,
                  weight: FontWeight.bold,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Iconsax.user,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    CustomText(
                      text: userData.email != null &&
                              userData.email.toString().isNotEmpty
                          ? userData.email.toString().split('@').first
                          : "Driver".tr,
                      size: 14,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: controller.isActive.value
                            ? ConstantColors.primary.withOpacity(0.2)
                            : AppThemeData.grey500.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CustomText(
                        text: controller.isActive.value
                            ? "● Online".tr
                            : "● Offline".tr,
                        size: 11,
                        color: controller.isActive.value
                            ? ConstantColors.primary
                            : AppThemeData.grey400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context,
      DashBoardController controller, bool isDarkMode, dynamic userData) {
    return GetX<WalletController>(
      init: WalletController(),
      initState: (_) {
        Get.find<WalletController>().getTrancation();
      },
      builder: (walletController) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Iconsax.wallet_3,
                    title: "Total Earnings".tr,
                    value: walletController.totalEarn.value.isNotEmpty &&
                            walletController.totalEarn.value != "0" &&
                            walletController.totalEarn.value != "null"
                        ? "${walletController.totalEarn.value} KWD"
                        : "0.00 KWD",
                    color: ConstantColors.blue,
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Iconsax.wallet_2,
                    title: "Wallet Balance".tr,
                    value: userData.amount != null &&
                            userData.amount.toString().isNotEmpty &&
                            userData.amount.toString() != "null"
                        ? "${userData.amount.toString()} KWD"
                        : "0.0 KWD",
                    color: ConstantColors.blue,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Iconsax.car,
                    title: "Vehicle".tr,
                    value: userData.brand != null &&
                            userData.brand.toString().isNotEmpty &&
                            userData.brand.toString() != "null"
                        ? "${userData.brand} ${userData.model ?? ''}".trim()
                        : "Not Set".tr,
                    maxLines: 1,
                    color: ConstantColors.blue,
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Iconsax.shield_tick,
                    title: "Account Status".tr,
                    value: userData.isVerified != null &&
                            userData.isVerified.toString().toLowerCase() ==
                                "yes"
                        ? "Verified".tr
                        : "Pending".tr,
                    color: ConstantColors.blue,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String value,
      required Color color,
      required bool isDarkMode,
      int? maxLines}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppThemeData.surface50Dark : AppThemeData.surface50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? AppThemeData.grey300Dark.withOpacity(0.3)
              : AppThemeData.grey200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          CustomText(
            text: title,
            size: 12,
            color: isDarkMode ? AppThemeData.grey500Dark : AppThemeData.grey500,
          ),
          const SizedBox(height: 4),
          CustomText(
            text: value,
            size: 18,
            weight: FontWeight.bold,
            color: isDarkMode ? AppThemeData.grey900Dark : AppThemeData.grey900,
            maxLines: maxLines ?? 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveToggleCard(
      BuildContext context, DashBoardController controller, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppThemeData.surface50Dark : AppThemeData.surface50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? AppThemeData.grey300Dark.withOpacity(0.3)
              : AppThemeData.grey200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (controller.isActive.value
                      ? ConstantColors.primary
                      : ConstantColors.blue)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              controller.isActive.value
                  ? Iconsax.tick_circle
                  : Iconsax.close_circle,
              color: controller.isActive.value
                  ? ConstantColors.blue
                  : AppThemeData.grey400,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  text: controller.isActive.value
                      ? "You're Online".tr
                      : "You're Offline".tr,
                  size: 16,
                  weight: FontWeight.w600,
                  color: isDarkMode
                      ? AppThemeData.grey900Dark
                      : AppThemeData.grey900,
                ),
                const SizedBox(height: 4),
                CustomText(
                  text: controller.isActive.value
                      ? "Ready to accept rides".tr
                      : "Turn on to start receiving rides".tr,
                  size: 12,
                  color: isDarkMode
                      ? AppThemeData.grey500Dark
                      : AppThemeData.grey500,
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.1,
            child: Obx(() {
              // Check if account is active (statut = "yes")
              final isAccountActive = controller.userModel.value.userData?.statut == "yes";
              
              return Switch(
                value: controller.isActive.value,
                // Disable toggle if account is not active
                onChanged: !isAccountActive ? null : (value) async {
                  // Set flag to prevent Worker from showing toast
                  _isManualToggle = true;
                  
                  // Get fresh data from server first
                  await controller.getUsrData();
                  
                  // Double check if account status is still active
                  if (controller.userModel.value.userData!.statut == "no") {
                    ShowToastDialog.showToast(
                      "Your account is currently inactive. Please contact support.".tr
                    );
                    _isManualToggle = false; // Reset flag
                    return;
                  }
                  
                  // Check vehicle status
                  if (controller.userModel.value.userData!.statutVehicule ==
                      "no") {
                    _isManualToggle = false; // Reset flag
                    showAlertDialog(context, "vehicleInformation");
                    return;
                  }
                  
                  // Check verification status
                  if (controller.userModel.value.userData!.isVerified == "no" ||
                      controller.userModel.value.userData!.isVerified!.isEmpty) {
                    _isManualToggle = false; // Reset flag
                    showAlertDialog(context, "document");
                    return;
                  }
                  
                  // All checks passed, proceed with status change
                  ShowToastDialog.showLoader("Please wait".tr);

                  Map<String, dynamic> bodyParams = {
                    'id_driver': Preferences.getInt(Preferences.userId),
                    'online': controller.isActive.value ? 'no' : 'yes',
                  };

                  await controller
                      .changeOnlineStatus(bodyParams)
                      .then((value) async {
                    if (value != null) {
                      if (value['success'] == "success") {
                        // IMPORTANT: Update ALL fields from server response, not just online
                        UserModel userModel = Constant.getUserData();
                        userModel.userData!.online = value['data']['online'];
                        userModel.userData!.statut = value['data']['statut']; // Update statut too!
                        
                        controller.userModel.value = userModel;
                        Preferences.setString(Preferences.user,
                            jsonEncode(userModel.toJson()));
                        
                        // Check statut first, then online
                        if (value['data']['statut'] == 'no') {
                          // Account disabled by admin
                          controller.isActive.value = false;
                          ShowToastDialog.showToast(
                            "Your account has been disabled by admin. Please contact support.".tr
                          );
                        } else {
                          // Account active, sync with online status
                          controller.isActive.value =
                              userModel.userData!.online == 'no'
                                  ? false
                                  : true;
                          ShowToastDialog.showToast(value['message']);
                        }
                      } else {
                        ShowToastDialog.showToast(value['error']);
                      }
                    }
                    
                    // Fetch fresh data after status change to ensure sync
                    await controller.getUsrData();
                  });

                  ShowToastDialog.closeLoader();
                },
                activeTrackColor: ConstantColors.primary,
                activeColor: Colors.white,
                inactiveTrackColor: isDarkMode
                    ? AppThemeData.grey800Dark
                    : AppThemeData.grey300,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(
      BuildContext context, DashBoardController controller, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(
          text: "Quick Actions".tr,
          size: 18,
          weight: FontWeight.bold,
          color: isDarkMode ? AppThemeData.grey900Dark : AppThemeData.grey900,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                context,
                icon: Iconsax.wallet_2,
                title: "Wallet".tr,
                color: ConstantColors.blue,
                isDarkMode: isDarkMode,
                onTap: () {
                  Get.to(() => WalletScreen());
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                context,
                icon: Iconsax.car,
                title: "All Rides".tr,
                color: ConstantColors.blue,
                isDarkMode: isDarkMode,
                onTap: () {
                  // Navigate to rides tab
                  Get.find<BottomNavController>().updateIndex(1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                context,
                icon: Iconsax.user,
                title: "Profile".tr,
                color: ConstantColors.blue,
                isDarkMode: isDarkMode,
                onTap: () {
                  Get.to(() => MyProfileScreen());
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                context,
                icon: Iconsax.document_text,
                title: "Documents".tr,
                color: ConstantColors.blue,
                isDarkMode: isDarkMode,
                onTap: () {
                  Get.to(() => DocumentStatusScreen());
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                context,
                icon: Iconsax.car,
                title: "Vehicle Info".tr,
                color: ConstantColors.blue,
                isDarkMode: isDarkMode,
                onTap: () {
                  Get.to(() => const VehicleInfoScreen());
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                context,
                icon: Iconsax.setting_2,
                title: "Settings".tr,
                color: ConstantColors.blue,
                isDarkMode: isDarkMode,
                onTap: () {
                  // Navigate to settings tab
                  Get.find<BottomNavController>().updateIndex(3);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(BuildContext context,
      {required IconData icon,
      required String title,
      required Color color,
      required bool isDarkMode,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              isDarkMode ? AppThemeData.surface50Dark : AppThemeData.surface50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? AppThemeData.grey300Dark.withOpacity(0.3)
                : AppThemeData.grey200,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            CustomText(
              text: title,
              size: 14,
              weight: FontWeight.w600,
              color:
                  isDarkMode ? AppThemeData.grey900Dark : AppThemeData.grey900,
            ),
          ],
        ),
      ),
    );
  }

  void showAlertDialog(BuildContext context, String type) {
    String title = "";

    if (type == "vehicleInformation") {
      title = "Please complete your vehicle information to go online.".tr;
    } else if (type == "document") {
      title = "Please upload and verify your documents to go online.".tr;
    }

    showDialog(
      barrierColor: Colors.black26,
      context: context,
      builder: (context) {
        return CustomAlertDialog(
          title: title,
          onPressNegative: () {
            Get.back();
          },
          negativeButtonText: 'Cancel'.tr,
          onPressPositive: () {
            Get.back();
            if (type == "vehicleInformation") {
              Get.to(() => const VehicleInfoScreen());
            } else if (type == "document") {
              Get.to(() => DocumentStatusScreen());
            }
          },
          positiveButtonText: type == "vehicleInformation"
              ? "Add Vehicle Info".tr
              : "View Documents".tr,
        );
      },
    );
  }
}

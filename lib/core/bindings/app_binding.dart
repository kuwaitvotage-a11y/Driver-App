import 'package:get/get.dart';
import 'package:mshwar_app_driver/features/dashboard/controller/dash_board_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // Register DashBoardController as a singleton (permanent)
    // This ensures only ONE instance exists throughout the app
    Get.put(DashBoardController(), permanent: true);
  }
}

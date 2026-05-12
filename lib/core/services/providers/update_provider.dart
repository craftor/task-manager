import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../update_service.dart';
import '../../constants/app_constants.dart';

final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) async {
  return UpdateService.checkForUpdate(AppConstants.appVersion);
});

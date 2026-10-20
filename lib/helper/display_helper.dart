import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/helper/responsive_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

void customPrint(String message) {
  if(kDebugMode) {
    print(message);
  }
}

void showCustomSnackBar(String message, {bool isError = true, int seconds = 3, String? subMessage}) {
  // Version robuste (compatible Flutter recent) : SnackBar Material au lieu de GetSnackBar.
  try {
    final BuildContext? ctx = Get.overlayContext ?? Get.context;
    final ScaffoldMessengerState? messenger = ctx != null ? ScaffoldMessenger.maybeOf(ctx) : null;
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: seconds),
        backgroundColor: isError ? const Color(0xFFB3261E) : const Color(0xFF1B7F4B),
        margin: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message, style: textMedium.copyWith(color: Colors.white)),
          if (subMessage != null)
            Text(subMessage, style: textMedium.copyWith(color: Colors.white.withOpacity(0.85))),
        ]),
      ));
      return;
    }
  } catch (_) {}
  // Secours : ancienne methode
  try {
    Get.closeCurrentSnackbar();
    Get.snackbar(isError ? 'Erreur' : 'OK', message, duration: Duration(seconds: seconds), snackPosition: SnackPosition.TOP);
  } catch (_) {}
}

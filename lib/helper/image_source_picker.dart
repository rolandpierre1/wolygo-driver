import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Petit menu: prendre une photo avec la caméra ou choisir dans la galerie.
/// Si [allowFile] est vrai, ajoute « Choisir un fichier » (documents PDF, etc.).
/// Retourne 'camera', 'gallery', 'file' ou null si l'utilisateur annule.
Future<String?> chooseUploadSource({bool allowFile = false}) {
  return Get.bottomSheet<String>(
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_camera),
          title: Text('vehicle_photo_take'.tr),
          onTap: () => Get.back(result: 'camera'),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: Text('vehicle_photo_gallery'.tr),
          onTap: () => Get.back(result: 'gallery'),
        ),
        if (allowFile)
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text('vehicle_doc_file'.tr),
            onTap: () => Get.back(result: 'file'),
          ),
      ])),
    ),
  );
}

/// Choisit la source puis retourne la photo (caméra ou galerie), ou null.
Future<XFile?> pickPhotoWithChoice() async {
  final s = await chooseUploadSource();
  if (s == null) return null;
  try {
    return await ImagePicker().pickImage(
      source: s == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85, maxWidth: 2000, maxHeight: 2000,
    );
  } catch (_) {
    return null;
  }
}

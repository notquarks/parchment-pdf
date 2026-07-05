import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageHelper {
  StorageHelper._();

  static Future<bool> isStoragePermissionGranted() async {
    if (!Platform.isAndroid) return true;
    return await Permission.manageExternalStorage.status.isGranted;
  }

  static Future<bool> ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;
    final result = await Permission.manageExternalStorage.request();
    return result.isGranted;
  }

  static Future<String?> pickFolder() {
    return FilePicker.getDirectoryPath(dialogTitle: 'Select Save Location');
  }
}

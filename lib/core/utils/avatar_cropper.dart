import 'dart:io';
import 'dart:ui';

import 'package:image_cropper/image_cropper.dart';

/// Opens the native cropper UI tuned for avatar editing: square, locked
/// aspect ratio, JPEG output at 90% quality. Returns the cropped [File]
/// or null if the user cancels.
Future<File?> cropAvatar({
  required String sourcePath,
  Color? toolbarColor,
  Color? activeControlsWidgetColor,
}) async {
  final cropped = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop avatar',
        toolbarColor: toolbarColor,
        toolbarWidgetColor: const Color(0xFFFFFFFF),
        activeControlsWidgetColor: activeControlsWidgetColor,
        initAspectRatio: CropAspectRatioPreset.square,
        lockAspectRatio: true,
        hideBottomControls: false,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
      ),
      IOSUiSettings(
        title: 'Crop avatar',
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
        rotateButtonsHidden: false,
        rotateClockwiseButtonHidden: false,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
      ),
    ],
  );
  if (cropped == null) return null;
  return File(cropped.path);
}

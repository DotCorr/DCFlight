import unittest
from dcflight.backends import android_camera,android_device,android_map

class AndroidDeviceTests(unittest.TestCase):
 def test_camera_lifecycle_and_supported_focus(self):
  source=android_camera.NATIVE
  for value in ('CONTROL_AF_AVAILABLE_MODES','CONTROL_AF_MODE_OFF','registerDisplayListener','unregisterDisplayListener','onDisplayChanged','captureGeneration!=generation.get()','bufferedTimestamp!=expectedTimestamp','attempt==captureId'):
   self.assertIn(value,source)
 def test_camera_placeholder_uses_vertical_center_and_logical_start(self):
  # Box defaults to TopStart, unlike the shared vertically centered frame.
  # Cover both loading and failure in the same aligned parent, without
  # changing the native preview's full-size surface.
  source=android_camera.NATIVE
  self.assertIn('Box(modifier,contentAlignment=androidx.compose.ui.Alignment.CenterStart)',source)
  self.assertIn('modifier=androidx.compose.ui.Modifier.matchParentSize()',source)
  self.assertIn('if(!ready){if(failed)failure()else loading()}',source)
 def test_location_numeric_and_availability_parity(self):
  source=android_device.NATIVE
  for value in ('floor(value+0.5)','ceil(value-0.5)','ceil(location.accuracy.toDouble())','location.elapsedRealtimeNanos<started','manager.isLocationEnabled','getCameraDisabled(null)'):
   self.assertIn(value,source)
 def test_map_invalid_rows_recover_and_async_callbacks_dispose(self):
  source=android_map.NATIVE
  for value in ('annotationFailed','85051128','fontScale','annotationKeys','live.get()'):
   self.assertIn(value,source)

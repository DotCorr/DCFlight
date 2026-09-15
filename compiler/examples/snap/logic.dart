/* Copyright (c) Dotcorr Studio. and affiliates. PolyForm Noncommercial License 1.0.0. */
import 'prelude.dart';

@bare
u32 canSendMessage(u32 textCodePoints, u32 hasPhoto) {
  if (textCodePoints > u32(2000)) return u32(0);
  if (textCodePoints > u32(0)) return u32(1);
  if (hasPhoto == u32(1)) return u32(1);
  return u32(0);
}

@bare
u32 canUploadPhoto(u32 byteCount) {
  if (byteCount == u32(0)) return u32(0);
  if (byteCount > u32(8388608)) return u32(0);
  return u32(1);
}

@bare
u32 remainingStorySeconds(u32 ageSeconds) {
  if (ageSeconds >= u32(86400)) return u32(0);
  return u32(86400) - ageSeconds;
}

@bare
u32 shouldPublishLocation(u32 consent, u32 permission) {
  if (consent != u32(1)) return u32(0);
  if (permission != u32(1)) return u32(0);
  return u32(1);
}

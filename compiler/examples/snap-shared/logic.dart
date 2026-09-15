/* Copyright (c) Dotcorr Studio. and affiliates. PolyForm Noncommercial License 1.0.0. */
import 'prelude.dart';

// One shared decision source for both native apps.
// Codes: 0 invalid username, 1 invalid password, 2 invalid display name,
// 3 proceed. The server independently validates content and authorization.
@bare
u32 decideLogin(u64 usernameAddress, u32 usernameLength, u32 passwordLength) {
  if (usernameLength < u32(3)) return u32(0);
  if (usernameLength > u32(24)) return u32(0);
  // Exact username contents, shared with both native apps. The input pointer
  // is borrowed for this call only and is never retained or modified.
  var index = u32(0);
  while (index < usernameLength) {
    final byte = Pointer<u8>.fromAddress(usernameAddress + index.toU64()).value;
    var allowed = u32(0);
    if (byte == u8(95)) allowed = u32(1);
    if (byte >= u8(65)) { if (byte <= u8(90)) allowed = u32(1); }
    if (byte >= u8(97)) { if (byte <= u8(122)) allowed = u32(1); }
    if (byte >= u8(48)) { if (byte <= u8(57)) allowed = u32(1); }
    if (allowed == u32(0)) return u32(0);
    index = index + u32(1);
  }
  if (passwordLength < u32(12)) return u32(1);
  if (passwordLength > u32(128)) return u32(1);
  return u32(3);
}

@bare
u32 decideRegister(u64 usernameAddress, u32 usernameLength, u32 passwordLength, u32 displayNameLength) {
  final login = decideLogin(usernameAddress, usernameLength, passwordLength);
  if (login != u32(3)) return login;
  if (displayNameLength == u32(0)) return u32(2);
  if (displayNameLength > u32(60)) return u32(2);
  return u32(3);
}

@bare
u32 decideProfile(u32 displayNameLength) {
  if (displayNameLength == u32(0)) return u32(2);
  if (displayNameLength > u32(60)) return u32(2);
  return u32(3);
}

// Failure categories: 0 connection/decoding, 1 credentials/session,
// 2 username conflict, 3 rejected input, 4 request throttled, 5 other.
@bare
u32 classifyFailure(u32 status) {
  if (status == u32(0)) return u32(0);
  if (status == u32(401)) return u32(1);
  if (status == u32(409)) return u32(2);
  if (status == u32(422)) return u32(3);
  if (status == u32(429)) return u32(4);
  return u32(5);
}

@bare
u32 decideRestore(u32 tokenLength) {
  if (tokenLength == u32(0)) return u32(0);
  return u32(1);
}

@bare
u32 decideSearch(u32 length) {
  if (length < u32(2)) return u32(0);
  if (length > u32(24)) return u32(0);
  return u32(1);
}

@bare
u32 decideMessage(u32 length) {
  if (length == u32(0)) return u32(0);
  if (length > u32(2000)) return u32(0);
  return u32(1);
}

@bare
u32 decidePhoto(u32 bytes, u32 captionLength, u32 destination) {
  if (bytes == u32(0)) return u32(0);
  if (bytes > u32(8388608)) return u32(1);
  if (destination > u32(1)) return u32(4);
  if (captionLength > u32(2000)) return u32(2);
  if (destination == u32(1)) { if (captionLength > u32(240)) return u32(2); }
  return u32(3);
}
@bare
u32 decidePhotoDestination(u32 destination) {
  if (destination < u32(2)) return destination;
  return u32(2);
}
@bare
u32 decideStoryExpiry(u32 visible, u32 now, u32 expires) {
  if (visible == u32(0)) return u32(0);
  if (now >= expires) return u32(1);
  return u32(0);
}

@bare
u32 decideCapture(u32 cameraReady, u32 idle) {
  if (cameraReady != u32(1)) return u32(0);
  if (idle != u32(1)) return u32(0);
  return u32(1);
}
@bare
u32 decideLocation(u32 consent, u32 accuracyMeters) {
  if (consent != u32(1)) return u32(0);
  if (accuracyMeters > u32(2000)) return u32(1);
  return u32(2);
}

@bare
u32 decideMapExpiry(u32 now, u32 earliestExpiry) {
  if (earliestExpiry == u32(0)) return u32(0);
  if (now >= earliestExpiry) return u32(1);
  return u32(0);
}


// Buffers are borrowed for this synchronous call. No pointer is retained.
@bare
u32 canonicalHandle(u64 input, u32 length, u64 output, u32 capacity) {
  if (length < u32(3)) return u32(4294967295);
  if (length > u32(24)) return u32(4294967295);
  if (length > capacity) return u32(4294967295);
  var index = u32(0);
  while (index < length) {
    var byte = Pointer<u8>.fromAddress(input + index.toU64()).value;
    var allowed = u32(0);
    if (byte == u8(95)) allowed = u32(1);
    if (byte >= u8(48)) { if (byte <= u8(57)) allowed = u32(1); }
    if (byte >= u8(97)) { if (byte <= u8(122)) allowed = u32(1); }
    if (byte >= u8(65)) {
      if (byte <= u8(90)) { allowed = u32(1); byte = byte + u8(32); }
    }
    if (allowed == u32(0)) return u32(4294967295);
    Pointer<u8>.fromAddress(output + index.toU64()).value = byte;
    index = index + u32(1);
  }
  return length;
}

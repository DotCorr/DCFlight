import 'prelude.dart';
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

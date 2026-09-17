import 'prelude.dart';
@bare
u32 transform(u64 input, u32 length, u32 mode, u64 output, u32 capacity) {
  if (mode == u32(1)) return capacity + u32(1);
  if (mode == u32(2)) { Pointer<u8>.fromAddress(output).value = u8(255); return u32(1); }
  if (mode == u32(3)) return u32(4294967295);
  if (length > capacity) return u32(4294967295);
  var index = u32(0);
  while (index < length) {
    final byte = Pointer<u8>.fromAddress(input + index.toU64()).value;
    Pointer<u8>.fromAddress(output + index.toU64()).value = byte;
    index = index + u32(1);
  }
  return length;
}
@bare
u32 empty(u64 output, u32 capacity) { return u32(0); }

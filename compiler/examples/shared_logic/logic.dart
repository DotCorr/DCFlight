/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */
import 'prelude.dart';

@bare
u32 increment(u32 count) => count + u32(1);

@bare
u32 discountedTotal(u32 unitPrice, u32 quantity, u32 discountPercent) {
  if (discountPercent > u32(100)) {
    return u32(0);
  }
  return (unitPrice * quantity) * (u32(100) - discountPercent) ~/ u32(100);
}

@bare
u32 greatestCommonDivisor(u32 a, u32 b) {
  while (b != u32(0)) {
    final next = a % b;
    a = b;
    b = next;
  }
  return a;
}

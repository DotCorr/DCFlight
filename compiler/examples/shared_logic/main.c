#include "logic.h"
#include <stdio.h>
int main(void) {
    if (increment(41) != 42) return 1;
    if (discountedTotal(2500, 3, 20) != 6000) return 2;
    if (discountedTotal(2500, 3, 101) != 0) return 3;
    if (greatestCommonDivisor(48, 18) != 6) return 4;
    if (greatestCommonDivisor(0, 0) != 0) return 5;
    puts("Shared DC Dart native logic: 5 checks passed");
    return 0;
}

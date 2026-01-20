# Plasm Compiler - Standard Library Integration Guide

## Overview

The Plasm standard library is fully integrated with the compiler through a flexible binding system that supports multiple runtime environments.

## External Bindings

### Declaration in Plasm

External functions are declared using naming convention:

```plasm
// Procedure (void return) - prefixed with $__external_
proc $__external_println(any value) void {}

// Function (with return) - prefixed with __external_
fn __external_readLine() any { return 0; }
```

### Implementation in Host

Bindings are provided by:
- **Browser**: stdlib.js
- **Node.js**: tools/wasi_runner.js  
- **WASI**: Native WASI imports

## See Also

- stdlib/README.md
- stdlib/WASI.md
- stdlib.js

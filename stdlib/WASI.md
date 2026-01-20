# Plasm Standard Library - WASI Bindings

This document describes how Plasm stdlib modules integrate with WASI (WebAssembly System Interface) for native execution.

## Overview

The Plasm standard library is implemented in Plasm itself, with external function declarations that are linked to host implementations. For native execution, these bindings are provided through WASI.

## WASI Integration Strategy

### 1. External Function Bindings

Plasm stdlib modules declare external functions using a naming convention:
- `$__external_*` for procedures (void return)
- `__external_*` for functions (with return value)

These are linked to WASI functions at instantiation time.

### 2. I/O Module WASI Bindings

The `stdlib/io` module maps to WASI fd_write and fd_read:

```
$__external_println -> WASI fd_write (fd=1, stdout with newline)
$__external_print   -> WASI fd_write (fd=1, stdout without newline)
__external_readLine -> WASI fd_read (fd=0, stdin)
```

### 3. Map Module WASI Bindings

The `stdlib/map` module uses WASI memory management:

```
Map storage is managed in linear memory with hash table implementation
__external_map_put    -> Direct memory operations
__external_map_get    -> Direct memory operations
__external_map_remove -> Direct memory operations
```

## Running with WASI Runtime

### Using Wasmtime

```bash
# Compile Plasm to WASM
dart run bin/plasm.dart myapp.plasm myapp.wasm

# Run with wasmtime
wasmtime --dir=. myapp.wasm
```

### Using Wasmer

```bash
# Run with wasmer
wasmer run myapp.wasm
```

### Using Node.js with WASI

```javascript
const { WASI } = require('wasi');
const fs = require('fs');

const wasi = new WASI({
  args: process.argv,
  env: process.env,
  preopens: {
    '/': '.'
  }
});

const wasmBytes = fs.readFileSync('./myapp.wasm');

WebAssembly.instantiate(wasmBytes, {
  wasi_snapshot_preview1: wasi.wasiImport,
  env: {
    // Plasm stdlib bindings
    __external_println: (ptr) => {
      // Convert ptr to string and print
      const str = readStringFromMemory(ptr);
      console.log(str);
    },
    // ... other bindings
  }
}).then(({ instance }) => {
  wasi.start(instance);
});
```

## Implementation Notes

### String Handling

Strings in Plasm are passed as pointers to memory. The WASI bindings need to:
1. Read the string length from memory (first 4 bytes at ptr)
2. Read the string bytes (following the length)
3. Decode as UTF-8

### Memory Management

The Plasm runtime provides a garbage collector. WASI bindings should:
- Use the exported `memory` from the WASM module
- Allocate via the `__plasm_alloc` export
- Free via the `__plasm_free` export

### Type Marshalling

For `any` type parameters, the WASI bindings need to:
1. Check the type tag (first byte at ptr)
2. Read the appropriate type based on tag:
   - 0: i64
   - 1: f64
   - 2: bool
   - 3: string (pointer)
   - 4: object (pointer)

## Example: Complete WASI Runner

See `tools/wasi_runner.js` for a complete implementation of a WASI runner with full stdlib support.

## Future Enhancements

1. **Async I/O**: Support for async/await with WASI async proposal
2. **File System**: Extend stdlib with file I/O module
3. **Networking**: Add stdlib/net module with WASI sockets
4. **Threading**: Support for WASI threads when available

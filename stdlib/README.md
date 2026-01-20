# Plasm Standard Library

The Plasm standard library provides core functionality for I/O, data structures, and system integration.

## Philosophy

The Plasm stdlib is:
1. **Written in Plasm** - All stdlib modules are implemented in Plasm itself
2. **Host-agnostic** - Uses external bindings that can be provided by any host (browser, Node.js, WASI)
3. **Minimal** - Focuses on essential functionality
4. **Type-safe** - Leverages Plasm's type system for safety

## Modules

### stdlib/io

Provides console input/output functionality.

```plasm
import stdlib/io;

pub proc $main() void {
  io.$println("Hello, World!");
  io.$print("Enter your name: ");
  final name = io.readLine();
  io.$println("Hello, ${name}!");
}
```

**Exports:**
- `$println(any value)` - Print value with newline
- `$print(any value)` - Print value without newline
- `readLine() -> any` - Read a line from input

### stdlib/map

Provides generic key-value map functionality.

```plasm
import stdlib/map;

pub proc $main() void {
  final cache = Map<u64, u64>();
  
  cache.$put(1, 100);
  cache.$put(2, 200);
  
  final value, exists = cache.get(1);
  if (exists) {
    io.$println("Value: ${value}");
  }
}
```

**Exports:**
- `Map<K, V>` - Generic map class
  - `constructor()` - Create new map
  - `$put(K key, V value)` - Insert/update entry
  - `get(K key) -> (V, bool)` - Get value (returns value and exists flag)
  - `contains(K key) -> bool` - Check if key exists
  - `$remove(K key)` - Remove entry
  - `size() -> u64` - Get number of entries
  - `$clear()` - Remove all entries
  - `resolve(K key) -> (V, bool)` - Alias for `get`

## Runtime Integration

### Browser (stdlib.js)

```javascript
import PlasmRuntime from './stdlib.js';

const runtime = new PlasmRuntime();
await runtime.loadModule('./myapp.wasm');
runtime.call('main');
```

### Node.js with WASI

```bash
node tools/wasi_runner.js myapp.wasm
```

### Native WASI Runtimes

```bash
# Wasmtime
wasmtime myapp.wasm

# Wasmer
wasmer run myapp.wasm
```

## External Bindings

Stdlib modules use external function declarations that are linked at runtime:

```plasm
// Internal implementation detail
proc $__external_println(any value) void {}
```

These are provided by:
- **Browser**: `stdlib.js` via WebAssembly imports
- **Node.js**: `tools/wasi_runner.js` 
- **WASI**: Native WASI bindings (see `stdlib/WASI.md`)

## Adding New Modules

To add a new stdlib module:

1. Create directory: `stdlib/mymodule/`
2. Implement in Plasm: `stdlib/mymodule/mymodule.plasm`
3. Declare external bindings: `proc $__external_*` or `fn __external_*`
4. Add bindings to `stdlib.js` and `tools/wasi_runner.js`
5. Document in this README

## Implementation Notes

### Type System

The `any` type is used for external bindings to support runtime polymorphism. The host environment handles type conversion.

### Memory Management

Stdlib relies on Plasm's garbage collector. External bindings should:
- Use exported memory from WASM module
- Follow pointer conventions (length-prefixed strings, type tags)
- Let Plasm GC handle allocation/deallocation

### Performance

Calls to external bindings cross the WASM boundary. For performance:
- Batch operations when possible
- Use native Plasm implementations where feasible
- Cache frequently accessed values

## Future Modules

Planned stdlib modules:
- `stdlib/fs` - File system operations
- `stdlib/net` - Network/HTTP
- `stdlib/json` - JSON parsing/serialization
- `stdlib/string` - String manipulation
- `stdlib/math` - Mathematical functions
- `stdlib/time` - Date/time operations

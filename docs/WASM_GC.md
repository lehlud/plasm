# WebAssembly GC Implementation

This document describes the implementation of WebAssembly GC (Garbage Collection) support in the Plasm compiler.

## Overview

The Plasm compiler now supports two compilation modes:

1. **Linear Memory Mode** (legacy): Uses linear memory for all allocations
2. **GC Mode** (default): Uses WebAssembly GC proposal for automatic memory management

## WebAssembly GC Proposal

The implementation follows the [WebAssembly GC MVP proposal](https://github.com/WebAssembly/gc), which provides:

- **Struct types**: Heterogeneous, fixed-size aggregates
- **Array types**: Homogeneous, dynamically-sized sequences
- **Reference types**: Typed references with nullable variants
- **RTT (Runtime Type Information)**: For type checking and casting
- **Automatic garbage collection**: No manual memory management required

## Architecture

### IR Extensions

The IR has been extended with GC-specific types and operations:

**Types** (`lib/src/ir/ir.dart`):
- `IrType.struct()`: Define struct types with named fields
- `IrType.array()`: Define array types with element type
- `IrType.ref()`: Reference types (nullable or non-nullable)
- `IrFieldType`: Field definitions for structs

**Opcodes**:
- Struct operations: `structNew`, `structGet`, `structSet`
- Array operations: `arrayNew`, `arrayNewDefault`, `arrayGet`, `arraySet`, `arrayLen`
- Reference operations: `refNull`, `refIsNull`, `refEq`, `refCast`
- RTT operations: `rttCanon`, `rttSub`
- Unboxed scalars: `i31New`, `i31GetS`, `i31GetU`

### WAT Generation

Two WAT generators are provided:

1. **`WatGenerator`** (`lib/src/codegen/wat_generator.dart`): 
   - Legacy linear memory mode
   - Compatible with older WASM runtimes
   - Uses `(memory 1)` and load/store instructions

2. **`WatGeneratorGC`** (`lib/src/codegen/wat_generator_gc.dart`):
   - Modern GC mode (default)
   - Emits type section with struct/array definitions
   - Uses GC instructions for allocation and access
   - Optional linear memory (only if needed)

## Usage

### Compiler API

```dart
import 'package:plasm/plasm.dart';

// Use GC mode (default)
final compiler = Compiler(useGC: true, verbose: true);
await compiler.compile('input.plasm', 'output.wasm');

// Use linear memory mode
final legacyCompiler = Compiler(useGC: false);
await legacyCompiler.compile('input.plasm', 'output.wasm');
```

### Command Line

```bash
# Compile with GC (default)
dart run bin/plasm.dart myfile.plasm output.wasm

# Run with GC
dart run bin/plasm.dart run myfile.plasm
```

## Language Mappings

### Arrays

Plasm arrays map directly to WebAssembly GC arrays:

**Plasm**:
```plasm
final arr = new u64[10];
arr[0] = 42;
final x = arr[0];
```

**WAT (GC)**:
```wat
(type $u64_array (array (mut i64)))

;; new u64[10]
(i64.const 0)  ;; init value
(i32.const 10) ;; length
(array.new $u64_array)

;; arr[0] = 42
(local.get $arr)
(i32.const 0)
(i64.const 42)
(array.set $u64_array)

;; arr[0]
(local.get $arr)
(i32.const 0)
(array.get $u64_array)
```

### Classes and Structs

Plasm classes map to WebAssembly GC structs:

**Plasm**:
```plasm
class Point {
  u64 x;
  u64 y;
  
  constructor(u64 x, u64 y) {
    this.x = x;
    this.y = y;
  }
}

final p = Point(10, 20);
final x = p.x;
```

**WAT (GC)**:
```wat
(type $Point (struct
  (field $x (mut i64))
  (field $y (mut i64))
))

;; Point(10, 20)
(i64.const 10)
(i64.const 20)
(struct.new $Point)

;; p.x
(local.get $p)
(struct.get $Point $x)
```

### Type Casting

Plasm's `as` operator maps to `ref.cast`:

**Plasm**:
```plasm
final obj: any = someValue;
final point = obj as Point;
```

**WAT (GC)**:
```wat
(local.get $obj)
(rtt.canon $Point)
(ref.cast)
```

## Runtime Requirements

### Browser

Modern browsers with WebAssembly GC support:
- Chrome/Edge 119+ (with `--js-flags=--experimental-wasm-gc`)
- Firefox 120+ (with `javascript.options.wasm_gc` enabled)
- Safari (experimental, TBD)

Load modules with GC:

```javascript
const runtime = new PlasmRuntime();
runtime.loadModule('app.wasm').then(() => {
  runtime.call('main');
});
```

### Node.js

Node.js 20+ with GC flag:

```bash
node --experimental-wasm-gc tools/wasi_runner.js app.wasm
```

### Native Runtimes

- **Wasmtime**: `wasmtime run --wasm-features=gc app.wasm`
- **Wasmer**: Support coming soon

## Benefits of GC Mode

1. **Automatic Memory Management**: No manual allocation/deallocation needed
2. **Type Safety**: Reference types prevent memory corruption
3. **Smaller Code**: No need for custom allocator
4. **Better Performance**: Engine's GC is highly optimized
5. **Language Interop**: Easier integration with JavaScript objects

## Limitations

1. **Runtime Support**: Not all WASM runtimes support GC yet
2. **No Manual Control**: Cannot control GC timing
3. **Limited Optimizations**: Some low-level optimizations harder to express

## Future Enhancements

- [ ] Optimization passes for GC code
- [ ] Support for inheritance and polymorphism with RTTs
- [ ] Shared types for inter-module communication
- [ ] Integration with JavaScript WeakMap/WeakRef
- [ ] Advanced features from GC post-MVP

## References

- [WebAssembly GC Proposal](https://github.com/WebAssembly/gc)
- [GC MVP Specification](https://github.com/WebAssembly/gc/blob/main/proposals/gc/MVP.md)
- [Reference Types Proposal](https://github.com/WebAssembly/reference-types)
- [Typed Function References](https://github.com/WebAssembly/function-references)

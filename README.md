# Plasm

**Portable Language for Abstract System Modeling**

Plasm is a modern, statically-typed programming language that compiles to WebAssembly with automatic garbage collection. Designed for systems programming with safety and performance in mind, Plasm brings high-level language features to WebAssembly while maintaining predictable, efficient code generation.

## Features

### Type-Safe and Fast
- **Static typing** with type inference for cleaner code
- **Generic types** for reusable data structures
- **Implicit upcasting** for safe numeric type conversions
- **Explicit casting** with the `as` keyword for controlled type conversions
- **Compile-time error detection** catches bugs before runtime

### Modern Memory Management
- **WebAssembly GC integration** for automatic memory management
- **Zero-cost abstractions** - no runtime overhead for unused features
- **Structured types** with structs and arrays managed by the engine's GC
- **Reference types** with nullable/non-nullable variants for safety

### Array and Collection Support
- **Dynamic arrays** with `new Type[size]` syntax
- **Array indexing** with bounds checking
- **Array literals** `[1, 2, 3]` for convenient initialization
- **Standard library collections** including generic `Map<K,V>`

### Flexible Function System
- **Functions** (`fn`) - pure computations without side effects
- **Procedures** (`proc`) - operations that can have side effects (prefixed with `$`)
- **Generic parameters** for polymorphic code
- **First-class functions** and closures (planned)

### Standard Library
- **stdlib/io** - Console I/O with `$println`, `$print`, `readLine`
- **stdlib/map** - Generic hash map implementation in pure Plasm
- More modules coming soon!

## Quick Start

### Installation

Ensure you have Dart SDK installed, then:

```bash
# Clone the repository
git clone https://github.com/lehlud/plasm.git
cd plasm

# Install dependencies
dart pub get

# Build the compiler
dart compile exe bin/plasm.dart -o plasm
```

### Hello World

Create `hello.plasm`:

```plasm
import stdlib/io;

pub proc $main() void {
  io.$println("Hello, Plasm!");
}
```

Compile and run:

```bash
# Compile and run in one step
./plasm run hello.plasm

# Or compile to WebAssembly
./plasm hello.plasm hello.wasm

# Then run with Node.js
node --experimental-wasm-gc tools/wasi_runner.js hello.wasm
```

### Fibonacci Example

```plasm
import stdlib/io;

fn fib(u64 n) u64 {
  if (n <= 1) {
    return n;
  }
  return fib(n - 1) + fib(n - 2);
}

pub proc $main() void {
  final result = fib(10);
  io.$println("fib(10) = ");
  io.$println(result);
}
```

## Language Syntax

### Types

#### Primitive Types
- **Unsigned integers**: `u8`, `u16`, `u32`, `u64`
- **Signed integers**: `i8`, `i16`, `i32`, `i64`
- **Floating point**: `f32`, `f64`
- **Boolean**: `bool`
- **Void**: `void` (for procedures)

#### Arrays
```plasm
final arr = new u64[10];      // Allocate array of 10 u64s
arr[0] = 42;                   // Set element
final x = arr[0];              // Get element
final nums = [1, 2, 3, 4, 5]; // Array literal
```

#### Type Casting
```plasm
// Implicit upcasting (automatic)
final u8 small = 10;
final u64 large = small;  // u8 → u64 allowed

// Explicit casting (required for downcasts)
final u64 big = 1000;
final u8 tiny = big as u8;  // Explicit downcast
```

### Functions and Procedures

```plasm
// Function: pure, no side effects
fn add(u64 a, u64 b) u64 {
  return a + b;
}

// Procedure: can have side effects (name starts with $)
proc $print_sum(u64 a, u64 b) void {
  final result = add(a, b);
  io.$println(result);
}
```

### Control Flow

```plasm
// If-else
if (x > 0) {
  // then branch
} else {
  // else branch
}

// While loop
while (i < 10) {
  i = i + 1;
}

// Return statement
return value;
```

### Variable Declarations

```plasm
// Mutable variable with explicit type
u64 x = 42;

// Immutable variable (type inferred)
final y = 100;

// Immutable with explicit type
final u32 z = 200;
```

### Classes (Planned)

```plasm
class Point {
  f64 x;
  f64 y;
  
  fn distance(Point other) f64 {
    final dx = other.x - x;
    final dy = other.y - y;
    return sqrt(dx * dx + dy * dy);
  }
}
```

## Standard Library

### stdlib/io

Console I/O operations:

```plasm
import stdlib/io;

// Print with newline
io.$println("Hello, World!");
io.$println(42);

// Print without newline
io.$print("Enter name: ");

// Read line from input
final name = io.readLine();
```

### stdlib/map

Generic hash map implementation:

```plasm
import stdlib/map;

// Create a map
final cache = Map<u64, u64>();

// Put key-value pairs
cache.$put(1, 100);
cache.$put(2, 200);

// Get values (returns value and exists flag)
final value, exists = cache.get(1);
if (exists) {
  io.$println(value);  // Prints: 100
}

// Check if key exists
if (cache.contains(2)) {
  // ...
}

// Remove key
cache.$remove(1);

// Get size
final size = cache.size();

// Clear all entries
cache.$clear();
```

## Compiler Architecture

Plasm uses a multi-phase compiler pipeline:

1. **Lexer** - Tokenizes source code
2. **Parser** - Builds Abstract Syntax Tree (AST)
3. **Name Analysis** - Resolves symbols and scopes
4. **Type Analysis** - Type checking and inference
5. **IR Generation** - SSA-form intermediate representation
6. **Optimization** - IR transformation passes (planned)
7. **Code Generation** - Emits WebAssembly Text (WAT) format
8. **Assembly** - Converts WAT to binary WASM using `wat2wasm`

## Runtime Support

### Browser

Plasm compiles to WebAssembly and can run in modern browsers:

```html
<script src="stdlib.js"></script>
<script>
  const runtime = new PlasmRuntime();
  runtime.loadModule('myapp.wasm').then(() => {
    runtime.call('main');
  });
</script>
```

**Browser Requirements**:
- Chrome/Edge 119+ with `--js-flags=--experimental-wasm-gc`
- Firefox 120+ with `javascript.options.wasm_gc` enabled

### Node.js

```bash
node --experimental-wasm-gc tools/wasi_runner.js myapp.wasm
```

**Requires**: Node.js 20+

### Native Runtimes

```bash
# Wasmtime
wasmtime run --wasm-features=gc myapp.wasm

# Wasmer (when GC support is available)
wasmer run --enable-gc myapp.wasm
```

## CLI Reference

### Compile Command

```bash
plasm <source.plasm> [output.wasm]

# Examples
plasm hello.plasm                # Outputs hello.wasm
plasm hello.plasm output.wasm    # Custom output name
plasm -v hello.plasm             # Verbose compilation
```

### Run Command

```bash
plasm run <source.plasm> [args...]

# Examples
plasm run hello.plasm                # Compile and run
plasm run myapp.plasm arg1 arg2      # Pass arguments
plasm run -v test.plasm              # Verbose mode
```

### Options

- `-v, --verbose` - Enable verbose output showing all compilation phases
- `-h, --help` - Show help message

## Development

### Project Structure

```
plasm/
├── bin/
│   └── plasm.dart          # CLI entry point
├── lib/
│   ├── plasm.dart          # Library exports
│   └── src/
│       ├── parser/         # Lexer and parser
│       ├── ast/            # AST node definitions
│       ├── analysis/       # Semantic analysis
│       ├── ir/             # Intermediate representation
│       └── codegen/        # Code generation
├── stdlib/
│   ├── io/                 # I/O module
│   └── map/                # Map collection
├── tools/
│   └── wasi_runner.js      # Node.js WASI runner
├── examples/               # Example programs
├── test/                   # Unit tests
└── docs/                   # Documentation
```

### Running Tests

```bash
# Run all tests
dart test

# Run specific test file
dart test test/plasm_test.dart

# Run with verbose output
dart test --reporter=verbose
```

### Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Ensure all tests pass
5. Submit a pull request

## Roadmap

### Current Status (v0.1)

- ✅ Hand-written recursive descent parser
- ✅ Complete AST representation
- ✅ Name and type analysis
- ✅ SSA-style IR with optimization framework
- ✅ WebAssembly GC code generation
- ✅ Standard library (io, map)
- ✅ CLI compiler with run command

### Planned Features

- [ ] Lambdas and closures
- [ ] Operator overloading
- [ ] Pattern matching
- [ ] Generics with constraints
- [ ] Trait system
- [ ] Module system with imports
- [ ] Standard library expansion (collections, strings, math)
- [ ] IR optimization passes (constant folding, DCE, inlining)
- [ ] Debug information generation
- [ ] Error recovery and better error messages
- [ ] IDE integration (LSP)

## WebAssembly GC

Plasm uses the [WebAssembly GC proposal](https://github.com/WebAssembly/gc) for automatic memory management. This provides:

- **Automatic garbage collection** - No manual memory management
- **Type safety** - Prevents memory corruption
- **Performance** - Leverages optimized engine GCs
- **Smaller binaries** - No custom allocator needed
- **Interoperability** - Seamless JavaScript integration

See `docs/WASM_GC.md` for implementation details.

## License

[License information to be added]

## Credits

Developed by the Plasm team. See the repository for the full list of contributors.

## Links

- **Repository**: https://github.com/lehlud/plasm
- **Issue Tracker**: https://github.com/lehlud/plasm/issues
- **Documentation**: [docs/](docs/)

## Contact

For questions or feedback, please open an issue on GitHub.

---

**Plasm** - Building a safer, faster future for systems programming with WebAssembly.

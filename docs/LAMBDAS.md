# Lambda and Closure Support in Plasm

## Overview

Plasm now supports first-class functions through lambda expressions and closures. This enables functional programming patterns like higher-order functions, function composition, and callbacks.

## Syntax

### Lambda Expression Body

The simplest form uses the arrow syntax with a single expression:

```plasm
final add = @(u64 x, u64 y) => x + y;
```

### Lambda Block Body

For more complex logic, use a block with explicit return:

```plasm
final compute = @(u64 x, u64 y) {
  final temp = x * 2;
  final result = temp + y;
  return result;
};
```

### Lambda with No Parameters

Lambdas can have zero parameters:

```plasm
final getConstant = @() => 42;
final value = getConstant();
```

## Type System

Lambdas have function types that specify parameter and return types:

```plasm
// Function type: (u64, u64) -> u64
final add: (u64, u64) -> u64 = @(u64 x, u64 y) => x + y;

// Function taking a function
fn applyOp(u64 a, u64 b, (u64, u64) -> u64 op) u64 {
  return op(a, b);
}
```

## Closures

Lambdas can capture variables from their enclosing scope:

```plasm
fn makeMultiplier(u64 factor) (u64) -> u64 {
  return @(u64 x) => x * factor;  // Captures 'factor'
}

fn example() void {
  final times5 = makeMultiplier(5);
  final result = times5(10);  // Returns 50
}
```

### Lexical Scoping

Closures capture variables by value at the time of creation:

```plasm
fn createCounters() void {
  u64 count = 0;
  
  final increment = @() {
    count = count + 1;
    return count;
  };
  
  io.$println(increment());  // Prints 1
  io.$println(increment());  // Prints 2
  io.$println(increment());  // Prints 3
}
```

## Higher-Order Functions

Functions can accept lambdas as parameters and return lambdas:

```plasm
// Map function for arrays
fn map(u64[] arr, (u64) -> u64 transform) u64[] {
  final result = new u64[arr.length];
  u64 i = 0;
  while (i < arr.length) {
    result[i] = transform(arr[i]);
    i = i + 1;
  }
  return result;
}

// Filter function
fn filter(u64[] arr, (u64) -> bool predicate) u64[] {
  // Implementation...
}

// Usage
fn example() void {
  final numbers = [1, 2, 3, 4, 5];
  
  // Double all numbers
  final doubled = map(numbers, @(u64 x) => x * 2);
  
  // Filter even numbers
  final evens = filter(numbers, @(u64 x) => x % 2 == 0);
}
```

## Function Composition

Lambdas enable composing functions:

```plasm
fn compose(
  (u64) -> u64 f,
  (u64) -> u64 g
) (u64) -> u64 {
  return @(u64 x) => f(g(x));
}

fn example() void {
  final double = @(u64 x) => x * 2;
  final addOne = @(u64 x) => x + 1;
  
  final doubleThenAddOne = compose(addOne, double);
  final result = doubleThenAddOne(5);  // (5 * 2) + 1 = 11
}
```

## Practical Examples

### Event Callbacks

```plasm
class Button {
  () -> void onClick;
  
  proc $setOnClick(() -> void handler) void {
    self.onClick = handler;
  }
  
  proc $click() void {
    if (self.onClick != null) {
      self.onClick();
    }
  }
}

fn example() void {
  final button = Button();
  
  button.$setOnClick(@() {
    io.$println("Button clicked!");
  });
  
  button.$click();  // Prints "Button clicked!"
}
```

### Array Sorting with Custom Comparator

```plasm
fn sort(u64[] arr, (u64, u64) -> bool lessThan) u64[] {
  // Sorting implementation using the comparator
}

fn example() void {
  final numbers = [5, 2, 8, 1, 9];
  
  // Sort ascending
  final ascending = sort(numbers, @(u64 a, u64 b) => a < b);
  
  // Sort descending
  final descending = sort(numbers, @(u64 a, u64 b) => a > b);
}
```

## Implementation Details

### IR Representation

Lambdas are compiled into separate functions with unique names:

```
Lambda: @(u64 x) => x + 1

Compiles to:
function __lambda_0(u64 x) -> u64 {
  return x + 1
}
```

### Closure Capture

Variables captured by closures are stored in a closure environment structure that is passed to the lambda function.

### WebAssembly Generation

Lambdas use WebAssembly's function reference types (`funcref`) and indirect calls (`call_indirect`) for dynamic dispatch.

## Limitations (Current Implementation)

1. **Closure capture is by-value**: Captured variables are copied, not referenced
2. **No mutable capture**: Cannot modify captured variables from outer scope
3. **Limited type inference**: Parameter types must be explicitly specified
4. **No recursive lambdas**: Lambdas cannot directly call themselves

## See Also

- [Operator Overloading Documentation](OPERATOR_OVERLOADING.md)
- [Examples](../examples/lambda_examples.plasm)
- [Type System Documentation](TYPE_SYSTEM.md)

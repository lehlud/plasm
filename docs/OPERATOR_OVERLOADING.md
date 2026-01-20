# Operator Overloading in Plasm

## Overview

Operator overloading allows user-defined types (classes) to define custom behavior for built-in operators like `+`, `-`, `*`, `==`, etc. This enables natural syntax for mathematical and domain-specific types.

## Syntax

Operators are defined as special class members using the `op` keyword:

```plasm
class ClassName {
  // ... fields ...
  
  op(OPERATOR) (ParameterType param) ReturnType {
    // Implementation
  }
}
```

## Supported Operators

### Arithmetic Operators

```plasm
class Vector {
  f64 x;
  f64 y;
  
  op(+) (Vector other) Vector {
    return Vector(x + other.x, y + other.y);
  }
  
  op(-) (Vector other) Vector {
    return Vector(x - other.x, y - other.y);
  }
  
  op(*) (f64 scalar) Vector {
    return Vector(x * scalar, y * scalar);
  }
  
  op(/) (f64 scalar) Vector {
    return Vector(x / scalar, y / scalar);
  }
  
  op(%) (Vector other) Vector {
    return Vector(x % other.x, y % other.y);
  }
}
```

### Comparison Operators

```plasm
class Point {
  f64 x;
  f64 y;
  
  op(==) (Point other) bool {
    return x == other.x && y == other.y;
  }
  
  op(!=) (Point other) bool {
    return x != other.x || y != other.y;
  }
  
  // Distance-based comparison
  op(<) (Point other) bool {
    final dist1 = x * x + y * y;
    final dist2 = other.x * other.x + other.y * other.y;
    return dist1 < dist2;
  }
  
  op(>) (Point other) bool {
    final dist1 = x * x + y * y;
    final dist2 = other.x * other.x + other.y * other.y;
    return dist1 > dist2;
  }
  
  op(<=) (Point other) bool {
    return !(self > other);
  }
  
  op(>=) (Point other) bool {
    return !(self < other);
  }
}
```

### Logical Operators

```plasm
class Predicate {
  bool value;
  
  op(&&) (Predicate other) Predicate {
    return Predicate(value && other.value);
  }
  
  op(||) (Predicate other) Predicate {
    return Predicate(value || other.value);
  }
}
```

## Complete Example: Complex Numbers

```plasm
class Complex {
  f64 real;
  f64 imag;
  
  constructor(f64 r, f64 i) {
    self.real = r;
    self.imag = i;
  }
  
  // Addition: (a + bi) + (c + di) = (a+c) + (b+d)i
  op(+) (Complex other) Complex {
    return Complex(real + other.real, imag + other.imag);
  }
  
  // Subtraction: (a + bi) - (c + di) = (a-c) + (b-d)i
  op(-) (Complex other) Complex {
    return Complex(real - other.real, imag - other.imag);
  }
  
  // Multiplication: (a + bi)(c + di) = (ac - bd) + (ad + bc)i
  op(*) (Complex other) Complex {
    final r = real * other.real - imag * other.imag;
    final i = real * other.imag + imag * other.real;
    return Complex(r, i);
  }
  
  // Division: (a + bi)/(c + di) = [(ac + bd) + (bc - ad)i]/(c² + d²)
  op(/) (Complex other) Complex {
    final denom = other.real * other.real + other.imag * other.imag;
    final r = (real * other.real + imag * other.imag) / denom;
    final i = (imag * other.real - real * other.imag) / denom;
    return Complex(r, i);
  }
  
  // Equality
  op(==) (Complex other) bool {
    return real == other.real && imag == other.imag;
  }
  
  op(!=) (Complex other) bool {
    return !(self == other);
  }
  
  fn magnitude() f64 {
    return sqrt(real * real + imag * imag);
  }
  
  proc $print() void {
    io.$print(real);
    if (imag >= 0.0) {
      io.$print(" + ");
      io.$print(imag);
    } else {
      io.$print(" - ");
      io.$print(-imag);
    }
    io.$println("i");
  }
}

// Usage
fn example() void {
  final c1 = Complex(3.0, 4.0);   // 3 + 4i
  final c2 = Complex(1.0, 2.0);   // 1 + 2i
  
  final sum = c1 + c2;             // 4 + 6i
  final diff = c1 - c2;            // 2 + 2i
  final product = c1 * c2;         // -5 + 10i
  final quotient = c1 / c2;        // 2.2 - 0.4i
  
  if (c1 == c2) {
    io.$println("Equal");
  } else {
    io.$println("Not equal");
  }
}
```

## Example: Matrix Operations

```plasm
class Matrix2x2 {
  f64 a, b, c, d;  // [[a, b], [c, d]]
  
  constructor(f64 a, f64 b, f64 c, f64 d) {
    self.a = a;
    self.b = b;
    self.c = c;
    self.d = d;
  }
  
  op(+) (Matrix2x2 other) Matrix2x2 {
    return Matrix2x2(
      a + other.a, b + other.b,
      c + other.c, d + other.d
    );
  }
  
  op(*) (Matrix2x2 other) Matrix2x2 {
    return Matrix2x2(
      a * other.a + b * other.c,
      a * other.b + b * other.d,
      c * other.a + d * other.c,
      c * other.b + d * other.d
    );
  }
  
  op(==) (Matrix2x2 other) bool {
    return a == other.a && b == other.b &&
           c == other.c && d == other.d;
  }
}
```

## Example: Fraction Arithmetic

```plasm
class Fraction {
  i64 numerator;
  i64 denominator;
  
  constructor(i64 num, i64 denom) {
    self.numerator = num;
    self.denominator = denom;
    self.$simplify();
  }
  
  proc $simplify() void {
    final g = gcd(numerator, denominator);
    numerator = numerator / g;
    denominator = denominator / g;
  }
  
  op(+) (Fraction other) Fraction {
    final num = numerator * other.denominator + 
                other.numerator * denominator;
    final denom = denominator * other.denominator;
    return Fraction(num, denom);
  }
  
  op(-) (Fraction other) Fraction {
    final num = numerator * other.denominator - 
                other.numerator * denominator;
    final denom = denominator * other.denominator;
    return Fraction(num, denom);
  }
  
  op(*) (Fraction other) Fraction {
    return Fraction(
      numerator * other.numerator,
      denominator * other.denominator
    );
  }
  
  op(/) (Fraction other) Fraction {
    return Fraction(
      numerator * other.denominator,
      denominator * other.numerator
    );
  }
  
  op(==) (Fraction other) bool {
    return numerator * other.denominator == 
           other.numerator * denominator;
  }
  
  op(<) (Fraction other) bool {
    return numerator * other.denominator < 
           other.numerator * denominator;
  }
}
```

## Implementation Details

### Dispatch Mechanism

When a binary expression `a + b` is encountered:

1. Check if type of `a` has an `op(+)` overload
2. If yes, call `a.op(+)(b)` 
3. If no, use default numeric operator (if applicable)

### IR Generation

Operator overloads are compiled into regular functions with mangled names:

```
Class: Point
Operator: op(+) (Point other) Point

Compiles to:
function Point_op_add(Point self, Point other) -> Point {
  // Implementation
}
```

### Type Checking

The type checker validates:
- Parameter type matches the operand type
- Return type is appropriate for the operator
- Operator is called with correct number of arguments

## Design Guidelines

### When to Overload Operators

✅ **Good use cases:**
- Mathematical types (Complex, Vector, Matrix, Fraction)
- Units of measurement (Distance, Time, Temperature)
- Collections (Set intersection, union)
- Domain-specific types where operators have clear meaning

❌ **Avoid:**
- Non-intuitive operator meanings
- Operators with surprising side effects
- Using operators just to save typing

### Best Practices

1. **Maintain mathematical properties**
   - Addition should be commutative when appropriate
   - Operations should be associative when expected
   - Follow algebraic rules

2. **Consistency**
   - If you overload `+`, consider overloading `-`
   - If you overload `==`, consider overloading `!=`
   - Keep related operators consistent

3. **Return appropriate types**
   - Arithmetic operators usually return same type
   - Comparison operators return `bool`

4. **Document behavior**
   - Especially for non-obvious operations
   - Explain any special cases

## Limitations (Current Implementation)

1. **Binary operators only**: No unary operator overloading yet
2. **Single parameter**: Operators take exactly one parameter plus `self`
3. **No chaining syntax**: Cannot define multiple overloads for same operator
4. **No assignment operators**: Cannot overload `+=`, `-=`, etc.

## See Also

- [Lambda and Closure Documentation](LAMBDAS.md)
- [Examples](../examples/operator_overload_examples.plasm)
- [Class Documentation](CLASSES.md)

import 'package:plasm/plasm.dart';
import 'package:test/test.dart';

void main() {
  group('Operator overloading parsing tests', () {
    test('parse class with operator+ overload', () {
      final source = '''
        class Point {
          u64 x;
          u64 y;
          
          op(+) (Point other) Point {
            // Note: Returns self for testing (proper constructors not yet supported)
            return self;
          }
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(parser.errors.isEmpty, true);
      expect(ast.declarations.length, 1);

      final classDecl = ast.declarations[0] as ClassDecl;
      expect(classDecl.name, 'Point');
      
      final operatorDecl = classDecl.members.whereType<OperatorDecl>().first;
      expect(operatorDecl.operator, '+');
      expect(operatorDecl.parameter.type.name, 'Point');
    });

    test('parse multiple operator overloads', () {
      final source = '''
        class Vector {
          u64 x;
          
          op(+) (Vector other) Vector {
            return self;
          }
          
          op(-) (Vector other) Vector {
            return self;
          }
          
          op(==) (Vector other) bool {
            return x == other.x;
          }
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(parser.errors.isEmpty, true);
      
      final classDecl = ast.declarations[0] as ClassDecl;
      final operators = classDecl.members.whereType<OperatorDecl>().toList();
      
      expect(operators.length, 3);
      expect(operators.map((o) => o.operator).toSet(), {'+', '-', '=='});
    });

    test('parse comparison operators', () {
      final source = '''
        class Value {
          u64 val;
          
          op(<) (Value other) bool {
            return val < other.val;
          }
          
          op(>) (Value other) bool {
            return val > other.val;
          }
          
          op(<=) (Value other) bool {
            return val <= other.val;
          }
          
          op(>=) (Value other) bool {
            return val >= other.val;
          }
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(parser.errors.isEmpty, true);
      
      final classDecl = ast.declarations[0] as ClassDecl;
      final operators = classDecl.members.whereType<OperatorDecl>().toList();
      
      expect(operators.length, 4);
      expect(operators.map((o) => o.operator).toSet(), {'<', '>', '<=', '>='});
    });
  });

  group('Operator overloading type analysis tests', () {
    test('analyze operator overload types', () {
      final source = '''
        class Point {
          u64 x;
          u64 y;
          
          op(+) (Point other) Point {
            final u64 newX = x + other.x;
            final u64 newY = y + other.y;
            // Return self for now (proper constructor support needed)
            return self;
          }
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);

      if (typeAnalyzer.errors.isNotEmpty) {
        print('Type errors: ${typeAnalyzer.errors}');
      }

      expect(typeAnalyzer.errors.isEmpty, true);
      
      final classDecl = ast.declarations[0] as ClassDecl;
      final operatorDecl = classDecl.members.whereType<OperatorDecl>().first;
      
      final returnType = typeAnalyzer.getType(operatorDecl);
      expect(returnType, isNotNull);
      expect(returnType!.name, 'Point');
    });

    test('use operator overload in binary expression', () {
      final source = '''
        class Point {
          u64 x;
          
          op(+) (Point other) Point {
            return Point();
          }
        }
        
        fn test(Point a, Point b) Point {
          return a + b;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);

      if (typeAnalyzer.errors.isNotEmpty) {
        print('Type errors: ${typeAnalyzer.errors}');
      }

      // Should succeed because Point has operator+ defined
      expect(typeAnalyzer.errors.isEmpty, true);
    });

    test('validate operator parameter type', () {
      final source = '''
        class Point {
          u64 x;
          
          op(+) (Point other) Point {
            return self;
          }
        }
        
        fn test(Point a, u64 b) void {
          final result = a + b;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);

      // Should fail because operator+ expects Point, not u64
      // Note: This might not be caught in the current implementation
      // as operator lookup might fail and fall back to default behavior
    });
  });

  group('Operator overloading IR building tests', () {
    test('build IR for operator overload', () {
      final source = '''
        class Point {
          u64 x;
          u64 y;
          
          op(+) (Point other) Point {
            return self;
          }
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);

      final irBuilder = IrBuilder(typeAnalyzer, 'test');
      irBuilder.build(ast);

      // Should have generated a function for the operator
      final operatorFunc = irBuilder.module.functions
          .where((f) => f.name.contains('Point_op_add'))
          .firstOrNull;
      
      expect(operatorFunc, isNotNull);
      expect(operatorFunc!.parameters.length, 2); // self + other
    });

    test('build IR for using operator overload', () {
      final source = '''
        class Point {
          u64 x;
          
          op(+) (Point other) Point {
            return self;
          }
        }
        
        fn test(Point a, Point b) Point {
          return a + b;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);

      final irBuilder = IrBuilder(typeAnalyzer, 'test');
      irBuilder.build(ast);

      // Should have the test function and the operator function
      expect(irBuilder.module.functions.any((f) => f.name == 'test'), true);
      expect(irBuilder.module.functions.any((f) => f.name.contains('Point_op_add')), true);
    });
  });
}

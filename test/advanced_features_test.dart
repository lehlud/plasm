import 'package:plasm/plasm.dart';
import 'package:test/test.dart';

void main() {
  group('Explicit casting with as keyword', () {
    test('parse u32 as u64 cast', () {
      final source = '''
        fn test(u32 x) u64 {
          return x as u64;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(parser.errors.isEmpty, true);
      expect(ast.declarations.length, 1);

      final func = ast.declarations[0] as FunctionDecl;
      final returnStmt = func.body.statements[0] as ReturnStatement;
      expect(returnStmt.value, isA<CastExpr>());
    });

    test('parse value as i64 cast', () {
      final source = '''
        fn test() i64 {
          final x = 42 as i64;
          return x;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(parser.errors.isEmpty, true);
    });
  });

  group('Strict semicolon enforcement', () {
    test('reject missing semicolon after return', () {
      final source = '''
        fn test() u64 {
          return 42
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      parser.parse();

      expect(parser.errors.isNotEmpty, true);
      expect(
        parser.errors.any((e) => e.contains('Expected ; after return')),
        true,
      );
    });

    test('reject missing semicolon after expression statement', () {
      final source = '''
        proc \$test() void {
          final x = 42
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      parser.parse();

      expect(parser.errors.isNotEmpty, true);
    });

    test('accept proper semicolons', () {
      final source = '''
        fn test() u64 {
          final x = 42;
          return x;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(parser.errors.isEmpty, true);
    });
  });

  group('Implicit upcasting semantics', () {
    test('u8 to u16 implicit upcast', () {
      final source = '''
        fn test() u16 {
          final u8 x = 10;
          final u16 y = x;
          return y;
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
        // Test canImplicitlyUpcastTo directly
        final u8Type = PlasmType.u8;
        final u16Type = PlasmType.u16;
        print('u8 can upcast to u16: ${u8Type.canImplicitlyUpcastTo(u16Type)}');
        print(
          'u8 isUnsigned: ${u8Type.isUnsigned()}, getBitWidth: ${u8Type.getBitWidth()}',
        );
        print(
          'u16 isUnsigned: ${u16Type.isUnsigned()}, getBitWidth: ${u16Type.getBitWidth()}',
        );
      }

      expect(typeAnalyzer.errors.isEmpty, true);
    });

    test('u32 to i64 implicit upcast', () {
      final source = '''
        fn test() i64 {
          final u32 x = 100;
          final i64 y = x;
          return y;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);

      expect(typeAnalyzer.errors.isEmpty, true);
    });

    test('reject u64 to i64 implicit cast', () {
      final source = '''
        fn test() i64 {
          final u64 x = 100;
          final i64 y = x;
          return y;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);

      expect(typeAnalyzer.errors.isNotEmpty, true);
      expect(typeAnalyzer.errors.any((e) => e.contains('cannot assign')), true);
    });

    test('reject downcast without explicit cast', () {
      final source = '''
        fn test() u8 {
          final u64 x = 100;
          final u8 y = x;
          return y;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);

      expect(typeAnalyzer.errors.isNotEmpty, true);
    });

    test('allow explicit downcast with as keyword', () {
      final source = '''
        fn test() u8 {
          final u64 x = 100;
          return x as u8;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(parser.errors.isEmpty, true);
    });
  });

  group('Edge cases', () {
    test('nested casts', () {
      final source = '''
        fn test() i64 {
          final u8 x = 10;
          return (x as u32) as i64;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(parser.errors.isEmpty, true);
    });

    test('cast in expression', () {
      final source = '''
        fn test() u64 {
          final u32 x = 10;
          return (x as u64) + 20;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(parser.errors.isEmpty, true);
    });

    test('complex type compatibility', () {
      final source = '''
        fn test() void {
          final u8 a = 1;
          final u16 b = 2;
          final u32 c = 3;
          final u64 d = 4;

          final u64 result = a + b + c + d;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      // This should parse successfully
      expect(parser.errors.isEmpty, true);
    });

    test('signed to unsigned requires explicit cast', () {
      final source = '''
        fn test() u32 {
          final i32 x = -10;
          final u32 y = x;
          return y;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);

      // Should error - signed to unsigned not allowed implicitly
      expect(typeAnalyzer.errors.isNotEmpty, true);
    });
  });
}

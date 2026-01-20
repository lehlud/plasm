import 'package:plasm/plasm.dart';
import 'package:test/test.dart';

void main() {
  group('Lexer tests', () {
    test('tokenize simple program', () {
      final source = '''
        const x = 42;
        fn add(u64 a, u64 b) u64 {
          return a + b;
        }
      ''';
      
      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      
      expect(tokens.isNotEmpty, true);
      expect(lexer.errors.isEmpty, true);
    });
  });

  group('Parser tests', () {
    test('parse const declaration', () {
      final source = 'const x = 42;';
      
      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();
      
      expect(ast.declarations.length, 1);
      expect(ast.declarations[0], isA<ConstDecl>());
      expect(parser.errors.isEmpty, true);
    });

    test('parse function declaration', () {
      final source = '''
        fn add(u64 a, u64 b) u64 {
          return a + b;
        }
      ''';
      
      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();
      
      expect(ast.declarations.length, 1);
      expect(ast.declarations[0], isA<FunctionDecl>());
      expect(parser.errors.isEmpty, true);
    });
  });

  group('Name analysis tests', () {
    test('detect undefined variable', () {
      final source = '''
        fn test() u64 {
          return x;
        }
      ''';
      
      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();
      
      final analyzer = NameAnalyzer();
      analyzer.analyze(ast);
      
      expect(analyzer.errors.isNotEmpty, true);
      expect(analyzer.errors.any((e) => e.contains('Undefined')), true);
    });

    test('allow defined variable', () {
      final source = '''
        const x = 42;
        fn test() u64 {
          return x;
        }
      ''';
      
      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();
      
      final analyzer = NameAnalyzer();
      analyzer.analyze(ast);
      
      expect(analyzer.errors.isEmpty, true);
    });
  });

  group('Type analysis tests', () {
    test('infer literal types', () {
      final source = '''
        fn test() i64 {
          return 42;
        }
      ''';
      
      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();
      
      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);
      
      // Print errors for debugging
      if (typeAnalyzer.errors.isNotEmpty) {
        print('Type analysis errors:');
        for (final error in typeAnalyzer.errors) {
          print('  $error');
        }
      }
      
      expect(typeAnalyzer.errors.isEmpty, true);
    });
  });
}

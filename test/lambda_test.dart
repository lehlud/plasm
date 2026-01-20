import 'package:plasm/plasm.dart';
import 'package:test/test.dart';

void main() {
  group('Lambda parsing tests', () {
    test('parse simple lambda with expression body', () {
      final source = '''
        fn test() void {
          final f = @(u64 x) => x + 1;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(parser.errors.isEmpty, true);
      expect(ast.declarations.length, 1);

      final func = ast.declarations[0] as FunctionDecl;
      final varDecl = func.body.statements[0] as VarDecl;
      expect(varDecl.bindings[0].initializer, isA<LambdaExpr>());
      
      final lambda = varDecl.bindings[0].initializer as LambdaExpr;
      expect(lambda.parameters.length, 1);
      expect(lambda.body, isA<BinaryExpr>());
    });

    test('parse lambda with block body', () {
      final source = '''
        fn test() void {
          final f = @(u64 x, u64 y) {
            return x + y;
          };
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(parser.errors.isEmpty, true);
      
      final func = ast.declarations[0] as FunctionDecl;
      final varDecl = func.body.statements[0] as VarDecl;
      final lambda = varDecl.bindings[0].initializer as LambdaExpr;
      
      expect(lambda.parameters.length, 2);
      expect(lambda.body, isA<Block>());
    });

    test('parse lambda with no parameters', () {
      final source = '''
        fn test() void {
          final f = @() => 42;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(parser.errors.isEmpty, true);
      
      final func = ast.declarations[0] as FunctionDecl;
      final varDecl = func.body.statements[0] as VarDecl;
      final lambda = varDecl.bindings[0].initializer as LambdaExpr;
      
      expect(lambda.parameters.length, 0);
    });
  });

  group('Lambda type analysis tests', () {
    test('infer lambda type from expression body', () {
      final source = '''
        fn test() void {
          final f = @(u64 x) => x + 1;
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
      
      // Check lambda has function type
      final func = ast.declarations[0] as FunctionDecl;
      final varDecl = func.body.statements[0] as VarDecl;
      final lambda = varDecl.bindings[0].initializer as LambdaExpr;
      
      final lambdaType = typeAnalyzer.getType(lambda);
      expect(lambdaType, isNotNull);
      expect(lambdaType!.name, 'function');
      expect(lambdaType.functionParams, isNotNull);
      expect(lambdaType.functionParams!.length, 1);
    });

    test('validate lambda parameter types', () {
      final source = '''
        fn test() void {
          final f = @(u64 x, bool flag) => flag;
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);

      expect(typeAnalyzer.errors.isEmpty, true);
      
      final func = ast.declarations[0] as FunctionDecl;
      final varDecl = func.body.statements[0] as VarDecl;
      final lambda = varDecl.bindings[0].initializer as LambdaExpr;
      
      final lambdaType = typeAnalyzer.getType(lambda);
      expect(lambdaType!.functionParams!.length, 2);
      expect(lambdaType.functionParams![0].name, 'u64');
      expect(lambdaType.functionParams![1].name, 'bool');
      expect(lambdaType.functionReturn!.name, 'bool');
    });

    test('call lambda with correct arguments', () {
      final source = '''
        fn test() u64 {
          final f = @(u64 x) => x + 1;
          return f(42 as u64);
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
    });

    test('reject lambda call with wrong argument count', () {
      final source = '''
        fn test() u64 {
          final f = @(u64 x, u64 y) => x + y;
          return f(42);
        }
      ''';

      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);

      expect(typeAnalyzer.errors.isNotEmpty, true);
      expect(typeAnalyzer.errors.any((e) => e.contains('argument count')), true);
    });
  });

  group('Lambda IR building tests', () {
    test('build IR for simple lambda', () {
      final source = '''
        fn test() void {
          final f = @(u64 x) => x + 1;
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

      // Should have the main function and the lambda function
      expect(irBuilder.module.functions.length, 2);
      expect(irBuilder.module.functions.any((f) => f.name == 'test'), true);
      expect(irBuilder.module.functions.any((f) => f.name.startsWith('__lambda_')), true);
    });
  });
}

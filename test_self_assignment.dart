import 'package:plasm/plasm.dart';

void main() {
  final source = '''
    class Point {
      final f64 x;
      
      constructor() {
        self.x = 0.0;
      }
    }
  ''';

  print('Creating lexer...');
  final lexer = Lexer(source);
  final tokens = lexer.tokenize();
  print('Lexer errors: ${lexer.errors}');
  
  print('Creating parser...');
  final parser = Parser(tokens);
  final ast = parser.parse();
  print('Parser errors: ${parser.errors}');
  
  print('Creating type analyzer...');
  final typeAnalyzer = TypeAnalyzer();
  print('Analyzing...');
  typeAnalyzer.analyze(ast);
  print('Type errors: ${typeAnalyzer.errors}');
  
  print('Done!');
}

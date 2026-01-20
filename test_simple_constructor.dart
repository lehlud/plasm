import 'package:plasm/plasm.dart';

void main() {
  final source = '''
    class Point {
      constructor() {}
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
  print('Declarations: ${ast.declarations.length}');
  
  if (ast.declarations.isNotEmpty && ast.declarations[0] is ClassDecl) {
    final classDecl = ast.declarations[0] as ClassDecl;
    print('Class name: ${classDecl.name}');
    print('Members: ${classDecl.members.length}');
  }
  
  print('Creating type analyzer...');
  final typeAnalyzer = TypeAnalyzer();
  print('Analyzing...');
  typeAnalyzer.analyze(ast);
  print('Type errors: ${typeAnalyzer.errors}');
  
  print('Done!');
}

import 'dart:io';
import 'package:plasm/plasm.dart';

void main() async {
  final source = await File('examples/fib.plasm').readAsString();
  
  print('Lexing...');
  final lexer = Lexer(source);
  final tokens = lexer.tokenize();
  print('Lexed ${tokens.length} tokens');
  
  if (lexer.errors.isNotEmpty) {
    print('Lexer errors:');
    for (final error in lexer.errors) {
      print('  $error');
    }
  }
  
  print('\nParsing...');
  final parser = Parser(tokens);
  final ast = parser.parse();
  print('Parsed ${ast.declarations.length} declarations');
  
  if (parser.errors.isNotEmpty) {
    print('Parser errors:');
    for (final error in parser.errors) {
      print('  $error');
    }
  }
  
  print('\nDone!');
}

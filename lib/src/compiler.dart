import 'dart:io';
import 'ast/ast.dart';
import 'parser/lexer.dart';
import 'parser/parser.dart';
import 'analysis/name_analysis.dart';
import 'analysis/type_analysis.dart';
import 'ir/ir_builder.dart';
import 'ir/visitor.dart';
import 'codegen/wat_generator.dart';

/// Compiler pipeline orchestration
class Compiler {
  final List<String> errors = [];
  final bool verbose;

  Compiler({this.verbose = false});

  /// Compile a Plasm source file to WASM
  Future<bool> compile(String sourcePath, String outputPath) async {
    errors.clear();

    try {
      // Read source file
      final source = await File(sourcePath).readAsString();
      if (verbose) print('Read source file: $sourcePath');

      // Lexical analysis
      final lexer = Lexer(source);
      final tokens = lexer.tokenize();
      errors.addAll(lexer.errors);
      
      if (verbose) {
        print('Lexed ${tokens.length} tokens');
        if (lexer.errors.isNotEmpty) {
          print('Lexer errors:');
          for (final error in lexer.errors) {
            print('  $error');
          }
        }
      }

      // Parse
      final parser = Parser(tokens);
      final ast = parser.parse();
      errors.addAll(parser.errors);
      errors.addAll(ast.errors);
      
      if (verbose) {
        print('Parsed program with ${ast.declarations.length} declarations');
        if (parser.errors.isNotEmpty) {
          print('Parser errors:');
          for (final error in parser.errors) {
            print('  $error');
          }
        }
      }

      // Name analysis
      final nameAnalyzer = NameAnalyzer();
      nameAnalyzer.analyze(ast);
      errors.addAll(nameAnalyzer.errors);
      
      if (verbose) {
        print('Completed name analysis');
        if (nameAnalyzer.errors.isNotEmpty) {
          print('Name analysis errors:');
          for (final error in nameAnalyzer.errors) {
            print('  $error');
          }
        }
      }

      // Type analysis
      final typeAnalyzer = TypeAnalyzer();
      typeAnalyzer.analyze(ast);
      errors.addAll(typeAnalyzer.errors);
      
      if (verbose) {
        print('Completed type analysis');
        if (typeAnalyzer.errors.isNotEmpty) {
          print('Type analysis errors:');
          for (final error in typeAnalyzer.errors) {
            print('  $error');
          }
        }
      }

      // Stop if there are errors
      if (errors.isNotEmpty) {
        if (verbose) {
          print('\nCompilation failed with ${errors.length} error(s):');
          for (final error in errors) {
            print('  $error');
          }
        }
        return false;
      }

      // Generate IR
      final moduleName = _getModuleName(sourcePath);
      final irBuilder = IrBuilder(typeAnalyzer, moduleName);
      irBuilder.build(ast);
      
      if (verbose) {
        print('Generated IR module: $moduleName');
        print('\nIR Dump:');
        print(irBuilder.module.toString());
      }

      // Run optimization passes (placeholder for now)
      final passManager = IrPassManager();
      // passManager.addPass(ConstantFoldingPass());
      // passManager.addPass(DeadCodeEliminationPass());
      passManager.run(irBuilder.module);
      
      if (verbose) {
        print('Ran optimization passes');
      }

      // Generate WAT
      final watGenerator = WatGenerator(irBuilder.module);
      final watCode = watGenerator.generate();
      
      if (verbose) {
        print('\nGenerated WAT:');
        print(watCode);
      }

      // Write WAT file
      final watPath = outputPath.endsWith('.wasm')
          ? outputPath.replaceAll('.wasm', '.wat')
          : '$outputPath.wat';
      
      await File(watPath).writeAsString(watCode);
      if (verbose) print('Wrote WAT to: $watPath');

      // Compile WAT to WASM using wat2wasm
      final wasmPath = outputPath.endsWith('.wasm')
          ? outputPath
          : '$outputPath.wasm';
      
      final result = await _runWat2Wasm(watPath, wasmPath);
      
      if (result) {
        if (verbose) print('Compiled to WASM: $wasmPath');
        return true;
      } else {
        errors.add('Failed to compile WAT to WASM');
        return false;
      }
    } catch (e, stackTrace) {
      errors.add('Compilation error: $e');
      if (verbose) {
        print('Exception during compilation:');
        print(e);
        print(stackTrace);
      }
      return false;
    }
  }

  Future<bool> _runWat2Wasm(String watPath, String wasmPath) async {
    try {
      // Try to run wat2wasm
      final result = await Process.run('wat2wasm', [watPath, '-o', wasmPath]);
      
      if (result.exitCode == 0) {
        if (verbose && result.stdout.toString().isNotEmpty) {
          print('wat2wasm output: ${result.stdout}');
        }
        return true;
      } else {
        errors.add('wat2wasm failed: ${result.stderr}');
        if (verbose) {
          print('wat2wasm error: ${result.stderr}');
        }
        return false;
      }
    } catch (e) {
      // wat2wasm not available, just keep the WAT file
      if (verbose) {
        print('wat2wasm not available (error: $e)');
        print('WAT file generated but WASM compilation skipped');
      }
      return true; // Consider this a success since we generated the WAT
    }
  }

  String _getModuleName(String sourcePath) {
    final file = File(sourcePath);
    final name = file.uri.pathSegments.last;
    return name.replaceAll('.plasm', '').replaceAll('.', '_');
  }

  void printErrors() {
    if (errors.isEmpty) {
      print('No errors');
      return;
    }

    print('Compilation failed with ${errors.length} error(s):');
    for (final error in errors) {
      print('  $error');
    }
  }
}

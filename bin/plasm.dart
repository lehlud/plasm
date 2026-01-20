import 'dart:io';
import 'package:plasm/plasm.dart';

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Usage: plasm <source.plasm> [output.wasm]');
    print('');
    print('Options:');
    print('  -v, --verbose    Enable verbose output');
    print('  -h, --help       Show this help message');
    exit(1);
  }

  var verbose = false;
  var sourcePath = '';
  var outputPath = '';

  // Parse arguments
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    
    if (arg == '-v' || arg == '--verbose') {
      verbose = true;
    } else if (arg == '-h' || arg == '--help') {
      print('Plasm Compiler - WebAssembly compiler for the Plasm language');
      print('');
      print('Usage: plasm <source.plasm> [output.wasm]');
      print('');
      print('Options:');
      print('  -v, --verbose    Enable verbose output');
      print('  -h, --help       Show this help message');
      exit(0);
    } else if (sourcePath.isEmpty) {
      sourcePath = arg;
    } else if (outputPath.isEmpty) {
      outputPath = arg;
    }
  }

  if (sourcePath.isEmpty) {
    print('Error: No source file specified');
    exit(1);
  }

  // Check if source file exists
  if (!File(sourcePath).existsSync()) {
    print('Error: Source file not found: $sourcePath');
    exit(1);
  }

  // Determine output path
  if (outputPath.isEmpty) {
    outputPath = sourcePath.replaceAll('.plasm', '');
  }

  // Compile
  final compiler = Compiler(verbose: verbose);
  
  print('Compiling $sourcePath...');
  final success = await compiler.compile(sourcePath, outputPath);

  if (success) {
    print('✓ Compilation successful!');
    exit(0);
  } else {
    print('✗ Compilation failed!');
    compiler.printErrors();
    exit(1);
  }
}

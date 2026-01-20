import 'dart:io';
import 'package:plasm/plasm.dart';

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    printUsage();
    exit(1);
  }

  final command = arguments[0];

  // Handle subcommands
  if (command == 'run') {
    await runCommand(arguments.sublist(1));
  } else if (command == '-h' || command == '--help') {
    printUsage();
    exit(0);
  } else {
    // Default: compile mode
    await compileCommand(arguments);
  }
}

void printUsage() {
  print('Plasm Compiler - WebAssembly compiler for the Plasm language');
  print('');
  print('Usage:');
  print('  plasm <source.plasm> [output.wasm]      Compile Plasm to WebAssembly');
  print('  plasm run <source.plasm> [args...]      Compile and run Plasm program');
  print('');
  print('Options:');
  print('  -v, --verbose    Enable verbose output');
  print('  -h, --help       Show this help message');
  print('');
  print('Examples:');
  print('  plasm hello.plasm                       Compile to hello.wasm');
  print('  plasm hello.plasm output.wasm           Compile to specific output');
  print('  plasm run hello.plasm                   Compile and run');
  print('  plasm run hello.plasm arg1 arg2         Compile and run with arguments');
}

Future<void> compileCommand(List<String> arguments) async {
  var verbose = false;
  var sourcePath = '';
  var outputPath = '';

  // Parse arguments
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    
    if (arg == '-v' || arg == '--verbose') {
      verbose = true;
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
  
  if (verbose) {
    print('Compiling $sourcePath...');
  }
  final success = await compiler.compile(sourcePath, outputPath);

  if (success) {
    if (verbose) {
      print('✓ Compilation successful!');
    }
    exit(0);
  } else {
    print('✗ Compilation failed!');
    compiler.printErrors();
    exit(1);
  }
}

Future<void> runCommand(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Error: No source file specified for run command');
    print('Usage: plasm run <source.plasm> [args...]');
    exit(1);
  }

  var verbose = false;
  var sourcePath = '';
  final programArgs = <String>[];

  // Parse arguments
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    
    if (arg == '-v' || arg == '--verbose') {
      verbose = true;
    } else if (sourcePath.isEmpty) {
      sourcePath = arg;
    } else {
      // Remaining arguments are passed to the program
      programArgs.add(arg);
    }
  }

  // Check if source file exists
  if (!File(sourcePath).existsSync()) {
    print('Error: Source file not found: $sourcePath');
    exit(1);
  }

  // Create temporary output path
  final tempDir = Directory.systemTemp.createTempSync('plasm_run_');
  final baseName = sourcePath.split('/').last.replaceAll('.plasm', '');
  final outputPath = '${tempDir.path}/$baseName';

  try {
    // Compile
    final compiler = Compiler(verbose: verbose);
    
    if (verbose) {
      print('Compiling $sourcePath...');
    }
    final success = await compiler.compile(sourcePath, outputPath);

    if (!success) {
      print('✗ Compilation failed!');
      compiler.printErrors();
      exit(1);
    }

    if (verbose) {
      print('✓ Compilation successful!');
      print('Running $baseName...');
      print('---');
    }

    // Check if WASM file was generated
    final wasmFile = File('$outputPath.wasm');
    if (!wasmFile.existsSync()) {
      print('Error: WASM file not generated: $outputPath.wasm');
      exit(1);
    }

    // Try to run with Node.js WASI runner
    final nodeResult = await Process.run('which', ['node']);
    if (nodeResult.exitCode == 0) {
      // Node.js is available, use WASI runner
      // Find the script relative to this executable or in the current directory
      final scriptPath = Platform.script.resolve('../tools/wasi_runner.js').toFilePath();
      final fallbackScriptPath = 'tools/wasi_runner.js';
      
      String wasiRunnerPath;
      if (File(scriptPath).existsSync()) {
        wasiRunnerPath = scriptPath;
      } else if (File(fallbackScriptPath).existsSync()) {
        wasiRunnerPath = fallbackScriptPath;
      } else {
        print('Error: WASI runner not found');
        print('Tried:');
        print('  - $scriptPath');
        print('  - $fallbackScriptPath');
        exit(1);
      }

      final runArgs = ['node', wasiRunnerPath, wasmFile.path, ...programArgs];
      final result = await Process.run(runArgs[0], runArgs.sublist(1));
      
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      exit(result.exitCode);
    } else {
      // Try wasmtime
      final wasmtimeResult = await Process.run('which', ['wasmtime']);
      if (wasmtimeResult.exitCode == 0) {
        final runArgs = ['wasmtime', wasmFile.path, ...programArgs];
        final result = await Process.run(runArgs[0], runArgs.sublist(1));
        
        stdout.write(result.stdout);
        stderr.write(result.stderr);
        exit(result.exitCode);
      } else {
        print('Error: No WASM runtime found');
        print('Please install one of the following:');
        print('  - Node.js (with WASI support)');
        print('  - wasmtime');
        print('  - wasmer');
        exit(1);
      }
    }
  } finally {
    // Clean up temporary directory
    try {
      tempDir.deleteSync(recursive: true);
    } catch (e) {
      // Ignore cleanup errors
      if (verbose) {
        print('Warning: Could not clean up temporary directory: $tempDir');
      }
    }
  }
}

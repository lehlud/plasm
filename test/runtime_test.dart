import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import '../lib/src/compiler.dart';

/// Runtime tests that compile and execute Plasm programs
void main() {
  final testDir = path.join(Directory.current.path, 'test', 'runtime');
  
  // Find all .plasm test files
  final testFiles = Directory(testDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.plasm'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  group('Runtime Tests', () {
    for (final testFile in testFiles) {
      final testName = path.basenameWithoutExtension(testFile.path);
      final expectedFile = File(path.join(testDir, '$testName.expected'));

      test(testName, () async {
        // Create temporary output directory
        final tempDir = await Directory.systemTemp.createTemp('plasm_runtime_test_');
        final outputWat = path.join(tempDir.path, '$testName.wat');
        final outputWasm = path.join(tempDir.path, '$testName.wasm');

        try {
          // Compile the Plasm source
          final compiler = Compiler();
          final result = await compiler.compile(testFile.path, outputWasm);

          // Check for compilation errors
          if (!result) {
            fail('Compilation failed for ${testFile.path}');
          }

          // Verify WAT file was generated
          expect(File(outputWat).existsSync(), isTrue,
              reason: 'WAT file should be generated');

          // Verify WASM file was generated
          expect(File(outputWasm).existsSync(), isTrue,
              reason: 'WASM file should be generated');

          // TODO: Execute the WASM file and compare output with expected
          // For now, just verify successful compilation
          
          // If we get here, the test passed (compilation successful)
          // When runtime execution is implemented, we'll check stdout against .expected file

        } finally {
          // Cleanup temporary directory
          try {
            await tempDir.delete(recursive: true);
          } catch (e) {
            // Ignore cleanup errors
          }
        }
      }, timeout: Timeout(Duration(seconds: 30)));
    }
  });

  test('All runtime tests have expected output files', () {
    for (final testFile in testFiles) {
      final testName = path.basenameWithoutExtension(testFile.path);
      final expectedFile = File(path.join(testDir, '$testName.expected'));
      expect(expectedFile.existsSync(), isTrue,
          reason: 'Expected output file missing for $testName');
    }
  });
}

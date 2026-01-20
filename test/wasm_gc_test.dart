import 'package:plasm/plasm.dart';
import 'package:test/test.dart';

void main() {
  group('WebAssembly GC - Basic Tests', () {
    test('WAT generator can be created', () {
      final module = IrModule('test');

      // Create WAT generator (always uses GC)
      final generator = WatGenerator(module);

      expect(generator, isNotNull);

      // Generate should not throw
      final wat = generator.generate();

      expect(wat, contains('(module'));
      expect(wat, contains(')'));
    });

    test('WAT generator handles empty module', () {
      final module = IrModule('empty');
      final generator = WatGenerator(module);
      final wat = generator.generate();

      expect(wat, contains('(module'));
      expect(wat, contains(')'));
    });

    test('WAT generator handles function with parameters', () {
      final module = IrModule('test');

      final param = IrParameter(0, 'x', IrType.i64);
      final func = IrFunction('add', [param], IrType.i64);
      module.addFunction(func);

      final generator = WatGenerator(module);
      final wat = generator.generate();

      expect(wat, contains('\$add'));
      expect(wat, contains('param'));
      expect(wat, contains('result'));
    });

    test('Compiler can be created', () {
      final compiler = Compiler();
      expect(compiler, isNotNull);
    });

    test('IR module basics', () {
      final module = IrModule('test');
      expect(module.name, 'test');
      expect(module.functions, isEmpty);
      expect(module.globals, isEmpty);
    });
  });
}

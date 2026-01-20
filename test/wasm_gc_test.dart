import 'package:plasm/plasm.dart';
import 'package:test/test.dart';

void main() {
  group('WASM GC Tests', () {
    test('IR type system supports GC types', () {
      // Test struct type
      final structType = IrType.struct('Point', [
        IrFieldType(IrType.i64, name: 'x', mutable: true),
        IrFieldType(IrType.i64, name: 'y', mutable: true),
      ]);
      
      expect(structType.kind, IrTypeKind.struct);
      expect(structType.isGcType, true);
      expect(structType.fields!.length, 2);
      
      // Test array type
      final arrayType = IrType.array('u64_array', IrType.u64);
      
      expect(arrayType.kind, IrTypeKind.array);
      expect(arrayType.isGcType, true);
      expect(arrayType.elementType, IrType.u64);
      
      // Test reference type
      final refType = IrType.ref('Point', nullable: true);
      
      expect(refType.kind, IrTypeKind.ref);
      expect(refType.isGcType, true);
      expect(refType.nullable, true);
    });

    test('IR module supports type definitions', () {
      final module = IrModule('test');
      
      // Add a struct type
      final pointType = IrTypeDef('Point', IrType.struct('Point', [
        IrFieldType(IrType.i64, name: 'x'),
        IrFieldType(IrType.i64, name: 'y'),
      ]));
      
      module.addType(pointType);
      
      expect(module.types.length, 1);
      expect(module.types[0].name, 'Point');
    });

    test('IR opcodes include GC operations', () {
      // Test that GC opcodes exist
      expect(IrOpcode.values.contains(IrOpcode.structNew), true);
      expect(IrOpcode.values.contains(IrOpcode.structGet), true);
      expect(IrOpcode.values.contains(IrOpcode.structSet), true);
      expect(IrOpcode.values.contains(IrOpcode.arrayNew), true);
      expect(IrOpcode.values.contains(IrOpcode.arrayGet), true);
      expect(IrOpcode.values.contains(IrOpcode.arraySet), true);
      expect(IrOpcode.values.contains(IrOpcode.arrayLen), true);
      expect(IrOpcode.values.contains(IrOpcode.refNull), true);
      expect(IrOpcode.values.contains(IrOpcode.refEq), true);
      expect(IrOpcode.values.contains(IrOpcode.i31New), true);
    });

    test('WAT generator can be created with GC mode', () {
      final module = IrModule('test');
      
      // Create GC-enabled WAT generator
      final generator = WatGeneratorGC(module, useGC: true);
      
      expect(generator, isNotNull);
      
      // Generate should not throw
      final wat = generator.generate();
      
      expect(wat, contains('(module'));
      expect(wat, contains(')'));
    });

    test('WAT generator with struct types', () {
      final module = IrModule('test');
      
      // Add a struct type
      final pointType = IrTypeDef('Point', IrType.struct('Point', [
        IrFieldType(IrType.i64, name: 'x'),
        IrFieldType(IrType.i64, name: 'y'),
      ]));
      
      module.addType(pointType);
      
      final generator = WatGeneratorGC(module, useGC: true);
      final wat = generator.generate();
      
      expect(wat, contains('(type \$Point'));
      expect(wat, contains('struct'));
      expect(wat, contains('field'));
    });

    test('WAT generator with array types', () {
      final module = IrModule('test');
      
      // Add an array type
      final arrayType = IrTypeDef('u64_array', 
        IrType.array('u64_array', IrType.u64));
      
      module.addType(arrayType);
      
      final generator = WatGeneratorGC(module, useGC: true);
      final wat = generator.generate();
      
      expect(wat, contains('(type \$u64_array'));
      expect(wat, contains('array'));
      expect(wat, contains('mut'));
    });

    test('Compiler supports GC mode option', () {
      // Test that compiler can be created with GC option
      final compilerGC = Compiler(useGC: true);
      expect(compilerGC.useGC, true);
      
      final compilerNoGC = Compiler(useGC: false);
      expect(compilerNoGC.useGC, false);
    });
  });
}

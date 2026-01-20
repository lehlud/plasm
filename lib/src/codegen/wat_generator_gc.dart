import '../ir/ir.dart';

/// Generates WAT (WebAssembly Text Format) from IR with GC support
class WatGeneratorGC {
  final IrModule module;
  final StringBuffer _output = StringBuffer();
  int _indentLevel = 0;
  bool _useGC = true;  // Enable GC by default

  WatGeneratorGC(this.module, {bool useGC = true}) : _useGC = useGC;

  String generate() {
    _output.clear();
    _indentLevel = 0;

    _writeLine('(module');
    _indentLevel++;

    // Generate type section for GC types
    if (_useGC && module.types.isNotEmpty) {
      for (final typeDef in module.types) {
        _generateTypeDef(typeDef);
      }
      _writeLine();
    }

    // Generate memory section (optional if using GC)
    if (!_useGC || _needsLinearMemory()) {
      _writeLine('(memory 1)');
      _writeLine('(export "memory" (memory 0))');
      _writeLine();
    }

    // Generate globals
    for (final global in module.globals) {
      _generateGlobal(global);
    }

    if (module.globals.isNotEmpty) {
      _writeLine();
    }

    // Generate functions
    for (final function in module.functions) {
      _generateFunction(function);
      _writeLine();
    }

    _indentLevel--;
    _writeLine(')');

    return _output.toString();
  }

  void _generateTypeDef(IrTypeDef typeDef) {
    final type = typeDef.type;
    
    switch (type.kind) {
      case IrTypeKind.struct:
        _write('(type \$${typeDef.name} (struct');
        if (type.fields != null && type.fields!.isNotEmpty) {
          for (final field in type.fields!) {
            _write(' (field');
            if (field.name != null) {
              _write(' \$${field.name}');
            }
            if (field.mutable) {
              _write(' (mut ${_convertType(field.type)})');
            } else {
              _write(' ${_convertType(field.type)}');
            }
            _write(')');
          }
        }
        _writeLine('))');
        break;

      case IrTypeKind.array:
        final elemType = type.elementType!;
        _writeLine('(type \$${typeDef.name} (array (mut ${_convertType(elemType)})))');
        break;

      default:
        _writeLine(';; Unsupported type kind: ${type.kind}');
    }
  }

  bool _needsLinearMemory() {
    // Check if any instruction uses linear memory
    for (final function in module.functions) {
      for (final block in function.blocks) {
        for (final inst in [...block.instructions, if (block.terminator != null) block.terminator!]) {
          if (inst.opcode == IrOpcode.load || inst.opcode == IrOpcode.store || inst.opcode == IrOpcode.alloca) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _generateGlobal(IrGlobal global) {
    final watType = _convertType(global.type!);
    final initValue = global.initializer != null
        ? _getConstantValue(global.initializer!)
        : _getDefaultValue(global.type!);

    if (global.isConstant) {
      _writeLine('(global \$${global.name} $watType $initValue)');
    } else {
      _writeLine('(global \$${global.name} (mut $watType) $initValue)');
    }
  }

  void _generateFunction(IrFunction function) {
    final params = function.parameters
        .map((p) => '(param \$${p.name} ${_convertType(p.type!)})')
        .join(' ');
    
    final returnType = function.returnType.name != 'void'
        ? '(result ${_convertType(function.returnType)})'
        : '';

    final exportAttr = function.name.startsWith('\$main')
        ? ' (export "_start")'
        : '';

    _write('(func \$${function.name}$exportAttr');
    if (params.isNotEmpty) {
      _write(' $params');
    }
    if (returnType.isNotEmpty) {
      _write(' $returnType');
    }
    _writeLine();
    _indentLevel++;

    // Generate local variables
    final locals = _collectLocals(function);
    for (final local in locals.entries) {
      _writeLine('(local ${local.key} ${local.value})');
    }

    // Generate function body
    for (final block in function.blocks) {
      _generateBlock(block);
    }

    _indentLevel--;
    _writeLine(')');
  }

  Map<String, String> _collectLocals(IrFunction function) {
    final locals = <String, String>{};
    // Analyze function to determine local variables
    // For now, return empty
    return locals;
  }

  void _generateBlock(IrBasicBlock block) {
    if (block.label != null && block.label != 'entry') {
      _writeLine('(block \$${block.label}');
      _indentLevel++;
    }

    for (final instruction in block.instructions) {
      _generateInstruction(instruction);
    }

    if (block.terminator != null) {
      _generateInstruction(block.terminator!);
    }

    if (block.label != null && block.label != 'entry') {
      _indentLevel--;
      _writeLine(')');
    }
  }

  void _generateInstruction(IrInstruction instruction) {
    switch (instruction.opcode) {
      // Arithmetic
      case IrOpcode.add:
        _generateBinaryOp(instruction, 'add');
        break;
      case IrOpcode.sub:
        _generateBinaryOp(instruction, 'sub');
        break;
      case IrOpcode.mul:
        _generateBinaryOp(instruction, 'mul');
        break;
      case IrOpcode.div:
        _generateBinaryOp(instruction, 'div_s');
        break;
      case IrOpcode.mod:
        _generateBinaryOp(instruction, 'rem_s');
        break;

      // Comparison
      case IrOpcode.eq:
        _generateBinaryOp(instruction, 'eq');
        break;
      case IrOpcode.neq:
        _generateBinaryOp(instruction, 'ne');
        break;
      case IrOpcode.lt:
        _generateBinaryOp(instruction, 'lt_s');
        break;
      case IrOpcode.gt:
        _generateBinaryOp(instruction, 'gt_s');
        break;
      case IrOpcode.lte:
        _generateBinaryOp(instruction, 'le_s');
        break;
      case IrOpcode.gte:
        _generateBinaryOp(instruction, 'ge_s');
        break;

      // Logical
      case IrOpcode.and:
        _generateBinaryOp(instruction, 'and');
        break;
      case IrOpcode.or:
        _generateBinaryOp(instruction, 'or');
        break;
      case IrOpcode.neg:
        _generateUnaryOp(instruction, 'neg');
        break;
      case IrOpcode.not:
        _generateUnaryOp(instruction, 'eqz');
        break;

      // Linear memory operations
      case IrOpcode.load:
        _generateLoad(instruction);
        break;
      case IrOpcode.store:
        _generateStore(instruction);
        break;

      // Control flow
      case IrOpcode.ret:
        if (instruction.operands.isNotEmpty) {
          _generateValue(instruction.operands[0]);
          _writeLine('return');
        } else {
          _writeLine('return');
        }
        break;
      case IrOpcode.call:
        _generateCall(instruction);
        break;
      case IrOpcode.br:
        _writeLine('br 0');
        break;
      case IrOpcode.condBr:
        _generateValue(instruction.operands[0]);
        _writeLine('if');
        _indentLevel++;
        _writeLine('br 1');
        _indentLevel--;
        _writeLine('end');
        break;

      // GC: Struct operations
      case IrOpcode.structNew:
        _generateStructNew(instruction);
        break;
      case IrOpcode.structGet:
        _generateStructGet(instruction);
        break;
      case IrOpcode.structSet:
        _generateStructSet(instruction);
        break;

      // GC: Array operations
      case IrOpcode.arrayNew:
        _generateArrayNew(instruction);
        break;
      case IrOpcode.arrayNewDefault:
        _generateArrayNewDefault(instruction);
        break;
      case IrOpcode.arrayGet:
        _generateArrayGet(instruction);
        break;
      case IrOpcode.arraySet:
        _generateArraySet(instruction);
        break;
      case IrOpcode.arrayLen:
        _generateArrayLen(instruction);
        break;

      // GC: Reference operations
      case IrOpcode.refNull:
        _generateRefNull(instruction);
        break;
      case IrOpcode.refIsNull:
        _generateRefIsNull(instruction);
        break;
      case IrOpcode.refEq:
        _generateRefEq(instruction);
        break;
      case IrOpcode.refCast:
        _generateRefCast(instruction);
        break;

      // GC: RTT operations
      case IrOpcode.rttCanon:
        _generateRttCanon(instruction);
        break;

      // GC: i31 operations
      case IrOpcode.i31New:
        _generateI31New(instruction);
        break;
      case IrOpcode.i31GetS:
        _generateI31GetS(instruction);
        break;
      case IrOpcode.i31GetU:
        _generateI31GetU(instruction);
        break;

      default:
        _writeLine(';; Unsupported instruction: ${instruction.opcode}');
    }
  }

  // GC instruction generators

  void _generateStructNew(IrInstruction instruction) {
    // struct.new $type <field-values>
    final typeName = instruction.name ?? 'struct';
    for (final operand in instruction.operands) {
      _generateValue(operand);
    }
    _writeLine('struct.new \$$typeName');
  }

  void _generateStructGet(IrInstruction instruction) {
    // struct.get $type $field <struct-ref>
    if (instruction.operands.length >= 2) {
      final typeName = instruction.name ?? 'struct';
      final fieldIndex = (instruction.operands[1] as IrConstant?)?.value ?? 0;
      _generateValue(instruction.operands[0]); // struct ref
      _writeLine('struct.get \$$typeName $fieldIndex');
    }
  }

  void _generateStructSet(IrInstruction instruction) {
    // struct.set $type $field <struct-ref> <value>
    if (instruction.operands.length >= 3) {
      final typeName = instruction.name ?? 'struct';
      final fieldIndex = (instruction.operands[1] as IrConstant?)?.value ?? 0;
      _generateValue(instruction.operands[0]); // struct ref
      _generateValue(instruction.operands[2]); // value
      _writeLine('struct.set \$$typeName $fieldIndex');
    }
  }

  void _generateArrayNew(IrInstruction instruction) {
    // array.new $type <init-value> <length>
    if (instruction.operands.length >= 2) {
      final typeName = instruction.name ?? 'array';
      _generateValue(instruction.operands[0]); // init value
      _generateValue(instruction.operands[1]); // length
      _writeLine('array.new \$$typeName');
    }
  }

  void _generateArrayNewDefault(IrInstruction instruction) {
    // array.new_default $type <length>
    if (instruction.operands.isNotEmpty) {
      final typeName = instruction.name ?? 'array';
      _generateValue(instruction.operands[0]); // length
      _writeLine('array.new_default \$$typeName');
    }
  }

  void _generateArrayGet(IrInstruction instruction) {
    // array.get $type <array-ref> <index>
    if (instruction.operands.length >= 2) {
      final typeName = instruction.name ?? 'array';
      _generateValue(instruction.operands[0]); // array ref
      _generateValue(instruction.operands[1]); // index
      _writeLine('array.get \$$typeName');
    }
  }

  void _generateArraySet(IrInstruction instruction) {
    // array.set $type <array-ref> <index> <value>
    if (instruction.operands.length >= 3) {
      final typeName = instruction.name ?? 'array';
      _generateValue(instruction.operands[0]); // array ref
      _generateValue(instruction.operands[1]); // index
      _generateValue(instruction.operands[2]); // value
      _writeLine('array.set \$$typeName');
    }
  }

  void _generateArrayLen(IrInstruction instruction) {
    // array.len <array-ref>
    if (instruction.operands.isNotEmpty) {
      _generateValue(instruction.operands[0]);
      _writeLine('array.len');
    }
  }

  void _generateRefNull(IrInstruction instruction) {
    final typeName = instruction.name ?? 'any';
    _writeLine('ref.null \$$typeName');
  }

  void _generateRefIsNull(IrInstruction instruction) {
    if (instruction.operands.isNotEmpty) {
      _generateValue(instruction.operands[0]);
      _writeLine('ref.is_null');
    }
  }

  void _generateRefEq(IrInstruction instruction) {
    if (instruction.operands.length >= 2) {
      _generateValue(instruction.operands[0]);
      _generateValue(instruction.operands[1]);
      _writeLine('ref.eq');
    }
  }

  void _generateRefCast(IrInstruction instruction) {
    if (instruction.operands.length >= 2) {
      _generateValue(instruction.operands[0]); // ref
      _generateValue(instruction.operands[1]); // rtt
      _writeLine('ref.cast');
    }
  }

  void _generateRttCanon(IrInstruction instruction) {
    final typeName = instruction.name ?? 'any';
    _writeLine('rtt.canon \$$typeName');
  }

  void _generateI31New(IrInstruction instruction) {
    if (instruction.operands.isNotEmpty) {
      _generateValue(instruction.operands[0]);
      _writeLine('ref.i31');
    }
  }

  void _generateI31GetS(IrInstruction instruction) {
    if (instruction.operands.isNotEmpty) {
      _generateValue(instruction.operands[0]);
      _writeLine('i31.get_s');
    }
  }

  void _generateI31GetU(IrInstruction instruction) {
    if (instruction.operands.isNotEmpty) {
      _generateValue(instruction.operands[0]);
      _writeLine('i31.get_u');
    }
  }

  // Standard instruction generators

  void _generateBinaryOp(IrInstruction instruction, String op) {
    if (instruction.operands.length >= 2) {
      _generateValue(instruction.operands[0]);
      _generateValue(instruction.operands[1]);
      final type = _convertType(instruction.type ?? IrType.i64);
      _writeLine('$type.$op');
    }
  }

  void _generateUnaryOp(IrInstruction instruction, String op) {
    if (instruction.operands.isNotEmpty) {
      _generateValue(instruction.operands[0]);
      final type = _convertType(instruction.type ?? IrType.i64);
      _writeLine('$type.$op');
    }
  }

  void _generateLoad(IrInstruction instruction) {
    if (instruction.operands.isNotEmpty) {
      _generateValue(instruction.operands[0]);
      final type = _convertType(instruction.type ?? IrType.i64);
      _writeLine('$type.load');
    }
  }

  void _generateStore(IrInstruction instruction) {
    if (instruction.operands.length >= 2) {
      _generateValue(instruction.operands[1]); // address
      _generateValue(instruction.operands[0]); // value
      final type = _convertType(instruction.operands[0].type ?? IrType.i64);
      _writeLine('$type.store');
    }
  }

  void _generateCall(IrInstruction instruction) {
    if (instruction.operands.isEmpty) return;

    // Generate arguments
    for (int i = 1; i < instruction.operands.length; i++) {
      _generateValue(instruction.operands[i]);
    }

    // Generate call
    final callee = instruction.operands[0];
    if (callee.name != null) {
      _writeLine('call \$${callee.name}');
    }
  }

  void _generateValue(IrValue value) {
    if (value is IrConstant) {
      final type = _convertType(value.type!);
      if (value.type!.isGcType) {
        // For GC types, handle differently
        if (value.value == null) {
          _writeLine('ref.null $type');
        } else {
          _writeLine(';; Complex GC constant: ${value.value}');
        }
      } else {
        _writeLine('($type.const ${value.value})');
      }
    } else if (value is IrGlobal) {
      _writeLine('global.get \$${value.name}');
    } else if (value.name != null) {
      _writeLine('local.get \$${value.name}');
    }
  }

  String _getConstantValue(IrValue value) {
    if (value is IrConstant) {
      return value.value.toString();
    }
    return '0';
  }

  String _getDefaultValue(IrType type) {
    if (type.isGcType) {
      return '(ref.null ${_convertType(type)})';
    }
    switch (type.name) {
      case 'i8':
      case 'i16':
      case 'i32':
      case 'u8':
      case 'u16':
      case 'u32':
      case 'bool':
        return '(i32.const 0)';
      case 'i64':
      case 'u64':
        return '(i64.const 0)';
      case 'f32':
        return '(f32.const 0)';
      case 'f64':
        return '(f64.const 0)';
      default:
        return '(i32.const 0)';
    }
  }

  String _convertType(IrType type) {
    switch (type.kind) {
      case IrTypeKind.ref:
        // Reference types
        if (type.nullable) {
          return '(ref null \$${type.name})';
        }
        return '(ref \$${type.name})';

      case IrTypeKind.struct:
      case IrTypeKind.array:
        // These should be referenced, not used directly
        return '(ref \$${type.name})';

      case IrTypeKind.value:
        // Primitive value types
        switch (type.name) {
          case 'i8':
          case 'i16':
          case 'i32':
          case 'u8':
          case 'u16':
          case 'u32':
            return 'i32';
          case 'i64':
          case 'u64':
            return 'i64';
          case 'f32':
            return 'f32';
          case 'f64':
            return 'f64';
          case 'bool':
            return 'i32';
          case 'anyref':
            return 'anyref';
          case 'eqref':
            return 'eqref';
          case 'i31ref':
            return 'i31ref';
          case 'funcref':
            return 'funcref';
          case 'externref':
            return 'externref';
          default:
            return 'i32'; // Default to i32 for unknown types
        }
    }
  }

  void _write(String text) {
    _output.write(text);
  }

  void _writeLine([String text = '']) {
    if (text.isEmpty) {
      _output.write('\n');
    } else {
      _output.write('${'  ' * _indentLevel}$text\n');
    }
  }
}

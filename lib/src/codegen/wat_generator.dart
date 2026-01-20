import '../ir/ir.dart';

/// Generates WAT (WebAssembly Text Format) from IR
class WatGenerator {
  final IrModule module;
  final StringBuffer _output = StringBuffer();
  int _indentLevel = 0;

  WatGenerator(this.module);

  String generate() {
    _output.clear();
    _indentLevel = 0;

    _writeLine('(module');
    _indentLevel++;

    // Generate memory section
    _writeLine('(memory 1)');
    _writeLine('(export "memory" (memory 0))');
    _writeLine();

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

  void _generateGlobal(IrGlobal global) {
    final watType = _convertType(global.type!);
    final initValue = global.initializer != null
        ? _getConstantValue(global.initializer!)
        : '0';

    if (global.isConstant) {
      _writeLine('(global \$${global.name} $watType (${watType}.const $initValue))');
    } else {
      _writeLine('(global \$${global.name} (mut $watType) (${watType}.const $initValue))');
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

    // Generate local variables (simplified)
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
    // This would analyze the function to determine local variables
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
      case IrOpcode.load:
        _generateLoad(instruction);
        break;
      case IrOpcode.store:
        _generateStore(instruction);
        break;
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
      default:
        _writeLine(';; Unsupported instruction: ${instruction.opcode}');
    }
  }

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
    if (callee is IrValue && callee.name != null) {
      _writeLine('call \$${callee.name}');
    }
  }

  void _generateValue(IrValue value) {
    if (value is IrConstant) {
      final type = _convertType(value.type!);
      _writeLine('($type.const ${value.value})');
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

  String _convertType(IrType type) {
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
      default:
        return 'i32'; // Default to i32 for unknown types
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

import '../ir/ir.dart';

/// Generates WAT (WebAssembly Text Format) from IR with GC support
/// Always uses WebAssembly GC proposal features
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

    // Generate type definitions for GC (structs and arrays)
    _generateTypeDefinitions();
    
    // Note: No linear memory needed when using GC
    // Memory is managed by the WebAssembly GC runtime

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

  void _generateTypeDefinitions() {
    // TODO: Generate type definitions for GC types (structs, arrays)
    // For now, this is a placeholder until IR fully supports GC types
    // GC type definitions would go here when IR module has typeDefinitions property
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

    // Generate function body by analyzing blocks and reconstructing control flow
    _generateFunctionBody(function);

    _indentLevel--;
    _writeLine(')');
  }

  void _generateFunctionBody(IrFunction function) {
    if (function.blocks.isEmpty) return;

    final visited = <int>{};
    _generateBlockStructured(function.blocks[0], function.blocks, visited);
  }

  void _generateBlockStructured(IrBasicBlock block, List<IrBasicBlock> allBlocks, Set<int> visited) {
    if (visited.contains(block.id)) return;
    visited.add(block.id);

    // Generate instructions in this block
    for (final instruction in block.instructions) {
      _generateInstruction(instruction);
    }

    // Handle terminator
    if (block.terminator != null) {
      final terminator = block.terminator!;
      
      if (terminator.opcode == IrOpcode.condBr) {
        // Conditional branch - reconstruct if-then-else
        _generateValue(terminator.operands[0]);
        _writeLine('if');
        _indentLevel++;

        // Find the then and else blocks (next blocks after current)
        final currentIndex = allBlocks.indexOf(block);
        if (currentIndex + 1 < allBlocks.length) {
          final thenBlock = allBlocks[currentIndex + 1];
          
          // Check if it's a 'then' or 'merge' block
          if (thenBlock.label == 'then') {
            _generateBlockStructured(thenBlock, allBlocks, visited);
            
            // Check for else block
            final thenIndex = allBlocks.indexOf(thenBlock);
            if (thenIndex + 1 < allBlocks.length) {
              final nextBlock = allBlocks[thenIndex + 1];
              if (nextBlock.label == 'else') {
                _indentLevel--;
                _writeLine('else');
                _indentLevel++;
                _generateBlockStructured(nextBlock, allBlocks, visited);
              }
            }
          }
        }

        _indentLevel--;
        _writeLine('end');
        
        // Continue with merge block
        final mergeIndex = allBlocks.indexWhere((b) => b.label == 'merge' && !visited.contains(b.id));
        if (mergeIndex >= 0) {
          _generateBlockStructured(allBlocks[mergeIndex], allBlocks, visited);
        }
      } else if (terminator.opcode == IrOpcode.ret) {
        if (terminator.operands.isNotEmpty) {
          _generateValue(terminator.operands[0]);
        }
        _writeLine('return');
      } else if (terminator.opcode == IrOpcode.br) {
        // Unconditional branch - just continue to next block
        final currentIndex = allBlocks.indexOf(block);
        if (currentIndex + 1 < allBlocks.length && !visited.contains(allBlocks[currentIndex + 1].id)) {
          _generateBlockStructured(allBlocks[currentIndex + 1], allBlocks, visited);
        }
      }
    }
  }

  Map<String, String> _collectLocals(IrFunction function) {
    final locals = <String, String>{};
    // This would analyze the function to determine local variables
    // For now, return empty
    return locals;
  }

  void _generateBlock(IrBasicBlock block) {
    // Don't wrap entry block
    if (block.label == 'entry') {
      for (final instruction in block.instructions) {
        _generateInstruction(instruction);
      }
      if (block.terminator != null) {
        _generateInstruction(block.terminator!);
      }
      return;
    }

    // For other blocks, just generate instructions inline
    // The structured control flow is handled by if/loop/block constructs
    for (final instruction in block.instructions) {
      _generateInstruction(instruction);
    }

    if (block.terminator != null) {
      _generateInstruction(block.terminator!);
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
        // Unconditional branch - just continue to next block
        break;
      case IrOpcode.condBr:
        // Conditional branch is handled by building proper if-then-else
        // This simplified version just falls through
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
    if (callee is IrConstant && callee.type?.name == 'string') {
      // Function name as string constant
      _writeLine('call \$${callee.value}');
    } else if (callee is IrValue && callee.name != null) {
      _writeLine('call \$${callee.name}');
    }
    
    // If this instruction has no users and returns a value, add drop
    // This handles void procedure calls that invoke non-void functions
    if (instruction.type != null && instruction.type!.name != 'void') {
      // Check if the result is actually used
      // For now, we conservatively don't add drop as the IR should handle this
      // TODO: Add proper liveness analysis to determine if drop is needed
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

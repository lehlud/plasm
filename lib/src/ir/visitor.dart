import 'ir.dart';

/// Visitor interface for IR traversal
abstract class IrVisitor {
  void visitModule(IrModule module);
  void visitFunction(IrFunction function);
  void visitBasicBlock(IrBasicBlock block);
  void visitInstruction(IrInstruction instruction);
  void visitValue(IrValue value);
}

/// Base IR visitor with default implementations
class BaseIrVisitor implements IrVisitor {
  @override
  void visitModule(IrModule module) {
    for (final global in module.globals) {
      visitValue(global);
    }
    for (final function in module.functions) {
      visitFunction(function);
    }
  }

  @override
  void visitFunction(IrFunction function) {
    for (final param in function.parameters) {
      visitValue(param);
    }
    for (final block in function.blocks) {
      visitBasicBlock(block);
    }
  }

  @override
  void visitBasicBlock(IrBasicBlock block) {
    for (final instruction in block.instructions) {
      visitInstruction(instruction);
    }
    if (block.terminator != null) {
      visitInstruction(block.terminator!);
    }
  }

  @override
  void visitInstruction(IrInstruction instruction) {
    for (final operand in instruction.operands) {
      visitValue(operand);
    }
  }

  @override
  void visitValue(IrValue value) {
    // Default: do nothing
  }
}

/// IR pass interface
abstract class IrPass {
  String get name;
  bool run(IrModule module);
}

/// Dead code elimination pass (example optimization)
class DeadCodeEliminationPass extends BaseIrVisitor implements IrPass {
  @override
  String get name => 'Dead Code Elimination';

  final Set<IrValue> _usedValues = {};
  bool _modified = false;

  @override
  bool run(IrModule module) {
    _modified = false;
    _usedValues.clear();

    // First pass: mark used values
    visitModule(module);

    // Second pass: remove unused instructions (would be implemented here)
    // For now, just return whether any modifications were made
    return _modified;
  }

  @override
  void visitInstruction(IrInstruction instruction) {
    _usedValues.add(instruction);
    super.visitInstruction(instruction);
  }

  @override
  void visitValue(IrValue value) {
    _usedValues.add(value);
  }
}

/// Constant folding pass (example optimization)
class ConstantFoldingPass extends BaseIrVisitor implements IrPass {
  @override
  String get name => 'Constant Folding';

  bool _modified = false;

  @override
  bool run(IrModule module) {
    _modified = false;
    visitModule(module);
    return _modified;
  }

  @override
  void visitInstruction(IrInstruction instruction) {
    // Check if all operands are constants
    if (instruction.operands.every((op) => op is IrConstant)) {
      // Could fold the instruction here
      // This is a placeholder for the optimization
    }
    super.visitInstruction(instruction);
  }
}

/// Pass manager for running optimization passes
class IrPassManager {
  final List<IrPass> _passes = [];

  void addPass(IrPass pass) {
    _passes.add(pass);
  }

  void run(IrModule module) {
    for (final pass in _passes) {
      pass.run(module);
    }
  }
}

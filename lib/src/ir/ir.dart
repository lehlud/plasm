/// IR instruction types
enum IrOpcode {
  // Arithmetic
  add,
  sub,
  mul,
  div,
  mod,
  neg,

  // Comparison
  eq,
  neq,
  lt,
  gt,
  lte,
  gte,

  // Logical
  and,
  or,
  not,

  // Memory
  load,
  store,
  alloca,

  // Control flow
  br,
  condBr,
  ret,
  call,

  // Constants
  constInt,
  constFloat,
  constBool,
  constString,

  // Phi (for SSA)
  phi,

  // Cast
  cast,
}

/// IR value (SSA value)
abstract class IrValue {
  final int id;
  String? name;
  IrType? type;

  IrValue(this.id, {this.name, this.type});

  @override
  String toString() => name ?? '%$id';
}

/// IR parameter value
class IrParameter extends IrValue {
  IrParameter(int id, String name, IrType type)
      : super(id, name: name, type: type);
}

/// IR constant value
class IrConstant extends IrValue {
  final dynamic value;

  IrConstant(int id, this.value, IrType type) : super(id, type: type);

  @override
  String toString() {
    if (type?.name == 'string') {
      return '"$value"';
    }
    return value.toString();
  }
}

/// IR instruction
class IrInstruction extends IrValue {
  final IrOpcode opcode;
  final List<IrValue> operands;

  IrInstruction(int id, this.opcode, this.operands, {String? name, IrType? type})
      : super(id, name: name, type: type);

  @override
  String toString() {
    final nameStr = name ?? '%$id';
    return '$nameStr = ${opcode.toString().split('.').last} ${operands.join(', ')}';
  }
}

/// IR basic block
class IrBasicBlock {
  final int id;
  String? label;
  final List<IrInstruction> instructions = [];
  IrInstruction? terminator;

  IrBasicBlock(this.id, {this.label});

  void add(IrInstruction instruction) {
    instructions.add(instruction);
  }

  void setTerminator(IrInstruction instruction) {
    terminator = instruction;
  }

  @override
  String toString() {
    final labelStr = label ?? 'block_$id';
    final buffer = StringBuffer('$labelStr:\n');
    for (final inst in instructions) {
      buffer.write('  $inst\n');
    }
    if (terminator != null) {
      buffer.write('  $terminator\n');
    }
    return buffer.toString();
  }
}

/// IR function
class IrFunction {
  final String name;
  final List<IrValue> parameters;
  final IrType returnType;
  final List<IrBasicBlock> blocks = [];
  
  IrFunction(this.name, this.parameters, this.returnType);

  void addBlock(IrBasicBlock block) {
    blocks.add(block);
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    final paramStr = parameters.map((p) => '${p.type} ${p.name}').join(', ');
    buffer.write('function $name($paramStr) -> $returnType {\n');
    for (final block in blocks) {
      buffer.write(block.toString());
    }
    buffer.write('}\n');
    return buffer.toString();
  }
}

/// IR global value
class IrGlobal extends IrValue {
  final bool isConstant;
  IrValue? initializer;

  IrGlobal(int id, String name, IrType type, {this.isConstant = false})
      : super(id, name: name, type: type);

  @override
  String toString() => '@$name';
}

/// IR module (compilation unit)
class IrModule {
  final String name;
  final List<IrGlobal> globals = [];
  final List<IrFunction> functions = [];

  IrModule(this.name);

  void addGlobal(IrGlobal global) {
    globals.add(global);
  }

  void addFunction(IrFunction function) {
    functions.add(function);
  }

  @override
  String toString() {
    final buffer = StringBuffer('module $name {\n\n');
    
    for (final global in globals) {
      buffer.write('global $global : ${global.type}\n');
    }
    
    if (globals.isNotEmpty) {
      buffer.write('\n');
    }
    
    for (final function in functions) {
      buffer.write(function.toString());
      buffer.write('\n');
    }
    
    buffer.write('}\n');
    return buffer.toString();
  }
}

/// IR type system
class IrType {
  final String name;
  final List<IrType>? typeArguments;

  IrType(this.name, [this.typeArguments]);

  static final void_ = IrType('void');
  static final i8 = IrType('i8');
  static final i16 = IrType('i16');
  static final i32 = IrType('i32');
  static final i64 = IrType('i64');
  static final u8 = IrType('u8');
  static final u16 = IrType('u16');
  static final u32 = IrType('u32');
  static final u64 = IrType('u64');
  static final f32 = IrType('f32');
  static final f64 = IrType('f64');
  static final bool_ = IrType('bool');
  static final string = IrType('string');

  @override
  String toString() {
    if (typeArguments == null || typeArguments!.isEmpty) {
      return name;
    }
    return '$name<${typeArguments!.join(', ')}>';
  }
}

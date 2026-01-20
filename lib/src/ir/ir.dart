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

  // Memory (linear memory)
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

  // WASM GC: Struct operations
  structNew,      // struct.new $type <field-values>
  structGet,      // struct.get $type $field <struct-ref>
  structSet,      // struct.set $type $field <struct-ref> <value>

  // WASM GC: Array operations
  arrayNew,       // array.new $type <init-value> <length>
  arrayNewDefault, // array.new_default $type <length>
  arrayGet,       // array.get $type <array-ref> <index>
  arraySet,       // array.set $type <array-ref> <index> <value>
  arrayLen,       // array.len <array-ref>

  // WASM GC: Reference operations
  refNull,        // ref.null $type
  refIsNull,      // ref.is_null <ref>
  refEq,          // ref.eq <ref1> <ref2>
  refCast,        // ref.cast <ref> <rtt>
  refTest,        // ref.test <ref> <rtt>

  // WASM GC: RTT operations (Runtime Type)
  rttCanon,       // rtt.canon $type
  rttSub,         // rtt.sub $type <parent-rtt>

  // WASM GC: i31 (unboxed scalars)
  i31New,         // ref.i31 <i32>
  i31GetS,        // i31.get_s <i31ref>
  i31GetU,        // i31.get_u <i31ref>

  // Function values and closures
  funcRef,        // ref.func <function-index>
  lambda,         // Lambda expression (will be lowered to function)
  callIndirect,   // call_indirect <function-type> <callee> <args>
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
  final List<IrTypeDef> types = [];  // GC type definitions
  final List<IrGlobal> globals = [];
  final List<IrFunction> functions = [];

  IrModule(this.name);

  void addType(IrTypeDef type) {
    types.add(type);
  }

  void addGlobal(IrGlobal global) {
    globals.add(global);
  }

  void addFunction(IrFunction function) {
    functions.add(function);
  }

  @override
  String toString() {
    final buffer = StringBuffer('module $name {\n\n');
    
    for (final type in types) {
      buffer.write('$type\n');
    }
    
    if (types.isNotEmpty) {
      buffer.write('\n');
    }
    
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
  final IrTypeKind kind;

  // For struct types: field types
  final List<IrFieldType>? fields;
  
  // For array types: element type
  final IrType? elementType;
  
  // For reference types: nullability
  final bool nullable;

  IrType(this.name, [this.typeArguments])
      : kind = IrTypeKind.value,
        fields = null,
        elementType = null,
        nullable = false;

  IrType.struct(this.name, this.fields)
      : kind = IrTypeKind.struct,
        typeArguments = null,
        elementType = null,
        nullable = false;

  IrType.array(this.name, this.elementType)
      : kind = IrTypeKind.array,
        typeArguments = null,
        fields = null,
        nullable = false;

  IrType.ref(this.name, {this.nullable = false, this.typeArguments})
      : kind = IrTypeKind.ref,
        fields = null,
        elementType = null;

  // Primitive value types
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

  // WASM GC reference types
  static final anyref = IrType.ref('anyref', nullable: true);
  static final eqref = IrType.ref('eqref', nullable: true);
  static final i31ref = IrType.ref('i31ref');
  static final funcref = IrType.ref('funcref', nullable: true);
  static final externref = IrType.ref('externref', nullable: true);

  bool get isGcType => kind == IrTypeKind.struct || 
                       kind == IrTypeKind.array || 
                       kind == IrTypeKind.ref;

  @override
  String toString() {
    switch (kind) {
      case IrTypeKind.struct:
        return 'struct $name';
      case IrTypeKind.array:
        return 'array<${elementType}>';
      case IrTypeKind.ref:
        final nullStr = nullable ? ' null' : '';
        return '(ref$nullStr $name)';
      case IrTypeKind.value:
        if (typeArguments == null || typeArguments!.isEmpty) {
          return name;
        }
        return '$name<${typeArguments!.join(', ')}>';
    }
  }
}

/// Type kind for IR types
enum IrTypeKind {
  value,   // Primitive value types (i32, f64, etc.)
  struct,  // GC struct type
  array,   // GC array type
  ref,     // GC reference type
}

/// Field type for struct types
class IrFieldType {
  final String? name;
  final IrType type;
  final bool mutable;

  IrFieldType(this.type, {this.name, this.mutable = true});

  @override
  String toString() {
    final mutStr = mutable ? 'mut ' : '';
    final nameStr = name != null ? '$name: ' : '';
    return '$nameStr$mutStr$type';
  }
}

/// Type definition for GC types (stored in module)
class IrTypeDef {
  final String name;
  final IrType type;

  IrTypeDef(this.name, this.type);

  @override
  String toString() => '(type \$$name $type)';
}

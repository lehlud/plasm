import '../ast/ast.dart';

/// Type information
class PlasmType {
  final String name;
  final List<PlasmType>? typeArguments;

  PlasmType(this.name, [this.typeArguments]);

  static final void_ = PlasmType('void');
  static final any = PlasmType('any');
  static final u8 = PlasmType('u8');
  static final u16 = PlasmType('u16');
  static final u32 = PlasmType('u32');
  static final u64 = PlasmType('u64');
  static final i8 = PlasmType('i8');
  static final i16 = PlasmType('i16');
  static final i32 = PlasmType('i32');
  static final i64 = PlasmType('i64');
  static final f32 = PlasmType('f32');
  static final f64 = PlasmType('f64');
  static final bool_ = PlasmType('bool');
  static final string = PlasmType('string');

  bool isNumeric() {
    return name == 'u8' || name == 'u16' || name == 'u32' || name == 'u64' ||
           name == 'i8' || name == 'i16' || name == 'i32' || name == 'i64' ||
           name == 'f32' || name == 'f64';
  }

  bool isInteger() {
    return name == 'u8' || name == 'u16' || name == 'u32' || name == 'u64' ||
           name == 'i8' || name == 'i16' || name == 'i32' || name == 'i64';
  }

  bool isFloatingPoint() {
    return name == 'f32' || name == 'f64';
  }

  bool isUnsigned() {
    return name == 'u8' || name == 'u16' || name == 'u32' || name == 'u64';
  }

  bool isSigned() {
    return name == 'i8' || name == 'i16' || name == 'i32' || name == 'i64';
  }

  int getBitWidth() {
    switch (name) {
      case 'u8':
      case 'i8':
        return 8;
      case 'u16':
      case 'i16':
        return 16;
      case 'u32':
      case 'i32':
      case 'f32':
        return 32;
      case 'u64':
      case 'i64':
      case 'f64':
        return 64;
      default:
        return 0;
    }
  }

  /// Check if this type can be implicitly upcast to another type
  /// Rules:
  /// - Unsigned to larger unsigned: u8->u16->u32->u64
  /// - Unsigned to larger signed: u8->i16, u16->i32, u32->i64
  /// - Signed to larger signed: i8->i16->i32->i64
  /// - NOT allowed: u64->i64, signed to unsigned, larger to smaller
  bool canImplicitlyUpcastTo(PlasmType other) {
    if (name == other.name) return true;
    if (name == 'any' || other.name == 'any') return true;

    // Unsigned to larger unsigned
    if (isUnsigned() && other.isUnsigned()) {
      return getBitWidth() < other.getBitWidth();
    }

    // Unsigned to larger signed (with room for sign bit)
    if (isUnsigned() && other.isSigned()) {
      return getBitWidth() < other.getBitWidth();
    }

    // Signed to larger signed
    if (isSigned() && other.isSigned()) {
      return getBitWidth() < other.getBitWidth();
    }

    // Integer to float (may lose precision, but allowed)
    if (isInteger() && other.isFloatingPoint()) {
      return getBitWidth() <= other.getBitWidth();
    }

    // f32 to f64
    if (name == 'f32' && other.name == 'f64') {
      return true;
    }

    return false;
  }

  bool isCompatibleWith(PlasmType other) {
    if (name == 'any' || other.name == 'any') return true;
    if (name != other.name) return false;
    
    if (typeArguments != null && other.typeArguments != null) {
      if (typeArguments!.length != other.typeArguments!.length) return false;
      for (int i = 0; i < typeArguments!.length; i++) {
        if (!typeArguments![i].isCompatibleWith(other.typeArguments![i])) {
          return false;
        }
      }
    }
    
    return true;
  }

  @override
  String toString() {
    if (typeArguments == null || typeArguments!.isEmpty) {
      return name;
    }
    return '$name<${typeArguments!.map((t) => t.toString()).join(', ')}>';
  }

  @override
  bool operator ==(Object other) {
    if (other is! PlasmType) return false;
    return name == other.name && 
           typeArguments?.length == other.typeArguments?.length;
  }

  @override
  int get hashCode => name.hashCode;
}

/// Type environment for type checking
class TypeEnvironment {
  final TypeEnvironment? parent;
  final Map<String, PlasmType> _types = {};

  TypeEnvironment([this.parent]);

  void bind(String name, PlasmType type) {
    _types[name] = type;
  }

  PlasmType? lookup(String name) {
    if (_types.containsKey(name)) {
      return _types[name];
    }
    return parent?.lookup(name);
  }
}

/// Type analysis pass
class TypeAnalyzer implements AstVisitor {
  final List<String> errors = [];
  TypeEnvironment _env;
  final Map<AstNode, PlasmType> _nodeTypes = {};
  final Map<String, PlasmType> _functionReturnTypes = {};
  PlasmType? _currentFunctionReturnType;

  TypeAnalyzer() : _env = TypeEnvironment();

  void analyze(Program program) {
    // Analyze all declarations
    for (final decl in program.declarations) {
      try {
        decl.accept(this);
      } catch (e) {
        // Continue analyzing even if one declaration fails
        errors.add('Type analysis error: $e');
      }
    }
  }

  PlasmType? getType(AstNode node) => _nodeTypes[node];

  void _setType(AstNode node, PlasmType type) {
    _nodeTypes[node] = type;
  }

  void _enterScope() {
    _env = TypeEnvironment(_env);
  }

  void _exitScope() {
    _env = _env.parent!;
  }

  void _error(String message, int line, int column) {
    errors.add('Type error at $line:$column: $message');
  }

  PlasmType _resolveTypeSpec(TypeSpec spec) {
    if (spec.isVoid) return PlasmType.void_;
    if (spec.isAny) return PlasmType.any;

    switch (spec.name) {
      case 'u8': return PlasmType.u8;
      case 'u16': return PlasmType.u16;
      case 'u32': return PlasmType.u32;
      case 'u64': return PlasmType.u64;
      case 'i8': return PlasmType.i8;
      case 'i16': return PlasmType.i16;
      case 'i32': return PlasmType.i32;
      case 'i64': return PlasmType.i64;
      case 'f32': return PlasmType.f32;
      case 'f64': return PlasmType.f64;
      case 'bool': return PlasmType.bool_;
      default:
        if (spec.typeArguments != null) {
          final typeArgs = spec.typeArguments!.map((t) => _resolveTypeSpec(t)).toList();
          return PlasmType(spec.name, typeArgs);
        }
        return PlasmType(spec.name);
    }
  }

  @override
  void visitProgram(Program node) {
    for (final decl in node.declarations) {
      decl.accept(this);
    }
  }

  @override
  void visitImportDecl(ImportDecl node) {
    // Import type checking would happen here
  }

  @override
  void visitConstDecl(ConstDecl node) {
    node.value.accept(this);
    final valueType = _nodeTypes[node.value];
    
    if (valueType != null) {
      _env.bind(node.name, valueType);
      _setType(node, valueType);
    }
  }

  @override
  void visitFunctionDecl(FunctionDecl node) {
    final returnType = _resolveTypeSpec(node.returnType);
    _functionReturnTypes[node.name] = returnType;
    
    _enterScope();

    _currentFunctionReturnType = returnType;

    for (final param in node.parameters) {
      final paramType = _resolveTypeSpec(param.type);
      _env.bind(param.name, paramType);
      _setType(param, paramType);
    }

    node.body.accept(this);

    _currentFunctionReturnType = null;
    _exitScope();

    _setType(node, returnType);
  }

  @override
  void visitProcedureDecl(ProcedureDecl node) {
    final returnType = _resolveTypeSpec(node.returnType);
    _functionReturnTypes[node.name] = returnType;
    
    _enterScope();

    _currentFunctionReturnType = returnType;

    for (final param in node.parameters) {
      final paramType = _resolveTypeSpec(param.type);
      _env.bind(param.name, paramType);
      _setType(param, paramType);
    }

    node.body.accept(this);

    _currentFunctionReturnType = null;
    _exitScope();

    _setType(node, returnType);
  }

  @override
  void visitClassDecl(ClassDecl node) {
    _enterScope();

    for (final member in node.members) {
      if (member is FieldDecl) {
        PlasmType? fieldType;
        if (member.type != null) {
          fieldType = _resolveTypeSpec(member.type!);
        } else if (member.initializer != null) {
          member.initializer!.accept(this);
          fieldType = _nodeTypes[member.initializer];
        }
        
        if (fieldType != null) {
          _env.bind(member.name, fieldType);
          _setType(member, fieldType);
        }
      }
    }

    for (final member in node.members) {
      member.accept(this);
    }

    _exitScope();
  }

  @override
  void visitFieldDecl(FieldDecl node) {
    PlasmType? fieldType;
    
    if (node.type != null) {
      fieldType = _resolveTypeSpec(node.type!);
    }

    if (node.initializer != null) {
      node.initializer!.accept(this);
      final initType = _nodeTypes[node.initializer];
      
      if (fieldType != null && initType != null) {
        // Allow implicit upcasting
        if (!initType.canImplicitlyUpcastTo(fieldType) && !initType.isCompatibleWith(fieldType)) {
          _error('Type mismatch: cannot assign $initType to $fieldType (no implicit conversion available)', 
                 node.line, node.column);
        }
      } else if (fieldType == null) {
        fieldType = initType;
      }
    }

    if (fieldType != null) {
      _setType(node, fieldType);
    }
  }

  @override
  void visitConstructorDecl(ConstructorDecl node) {
    _enterScope();

    for (final param in node.parameters) {
      final paramType = _resolveTypeSpec(param.type);
      _env.bind(param.name, paramType);
      _setType(param, paramType);
    }

    node.body.accept(this);

    _exitScope();
  }

  @override
  void visitOperatorDecl(OperatorDecl node) {
    _enterScope();

    final paramType = _resolveTypeSpec(node.parameter.type);
    _env.bind(node.parameter.name, paramType);
    _setType(node.parameter, paramType);

    final returnType = _resolveTypeSpec(node.returnType);
    _currentFunctionReturnType = returnType;

    node.body.accept(this);

    _currentFunctionReturnType = null;
    _exitScope();

    _setType(node, returnType);
  }

  @override
  void visitParameter(Parameter node) {
    // Already handled in function/procedure declarations
  }

  @override
  void visitTypeSpec(TypeSpec node) {
    // Type specs don't need type checking themselves
  }

  @override
  void visitBlock(Block node) {
    _enterScope();
    
    for (final stmt in node.statements) {
      stmt.accept(this);
    }
    
    _exitScope();
  }

  @override
  void visitVarDecl(VarDecl node) {
    PlasmType? declaredType;
    
    if (node.type != null) {
      declaredType = _resolveTypeSpec(node.type!);
    }

    for (final binding in node.bindings) {
      PlasmType? varType = declaredType;
      
      if (binding.initializer != null) {
        binding.initializer!.accept(this);
        final initType = _nodeTypes[binding.initializer];
        
        if (varType != null && initType != null) {
          // Special case: Allow integer literals to be implicitly downcast to target type
          if (binding.initializer is LiteralExpr) {
            final literal = binding.initializer as LiteralExpr;
            if (literal.type == LiteralType.integer && varType.isInteger()) {
              // Override the literal's type to match the declared type
              _setType(binding.initializer!, varType);
            } else if (!initType.canImplicitlyUpcastTo(varType) && !initType.isCompatibleWith(varType)) {
              _error('Type mismatch: cannot assign $initType to $varType (no implicit conversion available)', 
                     node.line, node.column);
            }
          } else {
            // Allow implicit upcasting for non-literals
            if (!initType.canImplicitlyUpcastTo(varType) && !initType.isCompatibleWith(varType)) {
              _error('Type mismatch: cannot assign $initType to $varType (no implicit conversion available)', 
                     node.line, node.column);
            }
          }
        } else if (varType == null) {
          varType = initType;
        }
      }

      if (varType != null) {
        _env.bind(binding.name, varType);
      } else {
        _error('Cannot infer type for variable ${binding.name}', 
               node.line, node.column);
      }
    }
  }

  @override
  void visitIfStatement(IfStatement node) {
    node.condition.accept(this);
    
    final condType = _nodeTypes[node.condition];
    if (condType != null && !condType.isCompatibleWith(PlasmType.bool_)) {
      _error('If condition must be boolean, got $condType', 
             node.line, node.column);
    }

    node.thenBlock.accept(this);
    node.elseStatement?.accept(this);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    node.condition.accept(this);
    
    final condType = _nodeTypes[node.condition];
    if (condType != null && !condType.isCompatibleWith(PlasmType.bool_)) {
      _error('While condition must be boolean, got $condType', 
             node.line, node.column);
    }

    node.body.accept(this);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    if (node.value != null) {
      node.value!.accept(this);
      final valueType = _nodeTypes[node.value];
      
      if (_currentFunctionReturnType != null && valueType != null) {
        if (!valueType.isCompatibleWith(_currentFunctionReturnType!)) {
          _error('Return type mismatch: expected $_currentFunctionReturnType but got $valueType', 
                 node.line, node.column);
        }
      }
    } else {
      if (_currentFunctionReturnType != null && 
          !_currentFunctionReturnType!.isCompatibleWith(PlasmType.void_)) {
        _error('Return statement must return a value of type $_currentFunctionReturnType', 
               node.line, node.column);
      }
    }
  }

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    node.expression.accept(this);
  }

  @override
  void visitExpression(Expression node) {
    if (node is IdentifierExpr) {
      final type = _env.lookup(node.name);
      if (type != null) {
        _setType(node, type);
      }
    } else if (node is LiteralExpr) {
      switch (node.type) {
        case LiteralType.integer:
          _setType(node, PlasmType.i64); // Default to i64
          break;
        case LiteralType.float:
          _setType(node, PlasmType.f64); // Default to f64
          break;
        case LiteralType.boolean:
          _setType(node, PlasmType.bool_);
          break;
        case LiteralType.string:
          _setType(node, PlasmType.string);
          break;
      }
    } else if (node is BinaryExpr) {
      node.left.accept(this);
      node.right.accept(this);
      
      final leftType = _nodeTypes[node.left];
      final rightType = _nodeTypes[node.right];
      
      if (leftType != null && rightType != null) {
        switch (node.operator) {
          case '+':
          case '-':
          case '*':
          case '/':
          case '%':
            if (leftType.isNumeric() && rightType.isNumeric()) {
              _setType(node, leftType); // Use left type for arithmetic
            } else {
              _error('Arithmetic operators require numeric types', 
                     node.line, node.column);
            }
            break;
          case '<':
          case '>':
          case '<=':
          case '>=':
            if (leftType.isNumeric() && rightType.isNumeric()) {
              _setType(node, PlasmType.bool_);
            } else {
              _error('Comparison operators require numeric types', 
                     node.line, node.column);
            }
            break;
          case '==':
          case '!=':
            _setType(node, PlasmType.bool_);
            break;
          case '&&':
          case '||':
            if (leftType.isCompatibleWith(PlasmType.bool_) && 
                rightType.isCompatibleWith(PlasmType.bool_)) {
              _setType(node, PlasmType.bool_);
            } else {
              _error('Logical operators require boolean operands', 
                     node.line, node.column);
            }
            break;
        }
      }
    } else if (node is UnaryExpr) {
      node.operand.accept(this);
      
      final operandType = _nodeTypes[node.operand];
      if (operandType != null) {
        switch (node.operator) {
          case '-':
            if (operandType.isNumeric()) {
              _setType(node, operandType);
            } else {
              _error('Unary minus requires numeric type', 
                     node.line, node.column);
            }
            break;
          case '!':
            if (operandType.isCompatibleWith(PlasmType.bool_)) {
              _setType(node, PlasmType.bool_);
            } else {
              _error('Logical not requires boolean type', 
                     node.line, node.column);
            }
            break;
        }
      }
    } else if (node is CallExpr) {
      node.callee.accept(this);
      for (final arg in node.arguments) {
        arg.accept(this);
      }
      
      // Look up function return type
      if (node.callee is IdentifierExpr) {
        final funcName = (node.callee as IdentifierExpr).name;
        final returnType = _functionReturnTypes[funcName];
        if (returnType != null) {
          _setType(node, returnType);
        } else {
          _setType(node, PlasmType.void_);
        }
      } else {
        _setType(node, PlasmType.void_);
      }
    } else if (node is MemberAccessExpr) {
      node.object.accept(this);
      // Type would be determined by the member being accessed
      _setType(node, PlasmType.any);
    } else if (node is CastExpr) {
      node.expression.accept(this);
      final targetType = _resolveTypeSpec(node.type);
      _setType(node, targetType);
    } else if (node is AssignmentExpr) {
      node.value.accept(this);
      final varType = _env.lookup(node.name);
      final valueType = _nodeTypes[node.value];
      
      if (varType != null && valueType != null) {
        if (!valueType.isCompatibleWith(varType)) {
          _error('Assignment type mismatch: expected $varType but got $valueType', 
                 node.line, node.column);
        }
      }
      
      _setType(node, valueType ?? PlasmType.void_);
    } else if (node is IsExpr) {
      node.expression.accept(this);
      _setType(node, PlasmType.bool_);
    } else if (node is TupleExpr) {
      for (final element in node.elements) {
        element.accept(this);
      }
      // Tuple type would be a composite of element types
      _setType(node, PlasmType('tuple'));
    } else if (node is ConstructorCallExpr) {
      for (final arg in node.arguments) {
        arg.accept(this);
      }
      _setType(node, PlasmType(node.className));
    } else if (node is SelfExpr) {
      // Type would be the current class type
      _setType(node, PlasmType.any);
    } else if (node is StringInterpolationExpr) {
      for (final part in node.parts) {
        if (part is Expression) {
          part.accept(this);
        }
      }
      _setType(node, PlasmType.string);
    }
  }
}

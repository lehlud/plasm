import '../ast/ast.dart';
import '../analysis/type_analysis.dart';
import 'ir.dart';

/// Builds IR from AST
class IrBuilder {
  final TypeAnalyzer typeAnalyzer;
  final IrModule module;
  
  int _nextValueId = 0;
  int _nextBlockId = 0;
  
  IrFunction? _currentFunction;
  IrBasicBlock? _currentBlock;
  final Map<String, IrValue> _namedValues = {};

  IrBuilder(this.typeAnalyzer, String moduleName)
      : module = IrModule(moduleName);

  void build(Program program) {
    // Build globals (constants)
    for (final decl in program.declarations) {
      if (decl is ConstDecl) {
        _buildConstDecl(decl);
      }
    }

    // Build functions and procedures
    for (final decl in program.declarations) {
      if (decl is FunctionDecl) {
        _buildFunctionDecl(decl);
      } else if (decl is ProcedureDecl) {
        _buildProcedureDecl(decl);
      }
    }

    // Build classes (simplified for now)
    for (final decl in program.declarations) {
      if (decl is ClassDecl) {
        _buildClassDecl(decl);
      }
    }
  }

  void _buildConstDecl(ConstDecl node) {
    final type = typeAnalyzer.getType(node);
    if (type == null) return;

    final irType = _convertType(type);
    final global = IrGlobal(_nextValueId++, node.name, irType, isConstant: true);
    
    // Build initializer
    final initValue = _buildExpression(node.value);
    if (initValue != null) {
      global.initializer = initValue;
    }

    module.addGlobal(global);
    _namedValues[node.name] = global;
  }

  void _buildFunctionDecl(FunctionDecl node) {
    final returnType = _convertTypeSpec(node.returnType);
    final parameters = <IrValue>[];

    // Build parameters
    for (final param in node.parameters) {
      final paramType = _convertTypeSpec(param.type);
      final irParam = IrParameter(_nextValueId++, param.name, paramType);
      parameters.add(irParam);
    }

    final function = IrFunction(node.name, parameters, returnType);
    _currentFunction = function;

    // Save parameter values
    for (final param in parameters) {
      _namedValues[param.name!] = param;
    }

    // Create entry block
    final entryBlock = IrBasicBlock(_nextBlockId++, label: 'entry');
    function.addBlock(entryBlock);
    _currentBlock = entryBlock;

    // Build function body
    _buildBlock(node.body);

    // Clear state
    _currentFunction = null;
    _currentBlock = null;
    _namedValues.removeWhere((key, value) => parameters.contains(value));

    module.addFunction(function);
  }

  void _buildProcedureDecl(ProcedureDecl node) {
    final returnType = _convertTypeSpec(node.returnType);
    final parameters = <IrValue>[];

    // Build parameters
    for (final param in node.parameters) {
      final paramType = _convertTypeSpec(param.type);
      final irParam = IrParameter(_nextValueId++, param.name, paramType);
      parameters.add(irParam);
    }

    final function = IrFunction(node.name, parameters, returnType);
    _currentFunction = function;

    // Save parameter values
    for (final param in parameters) {
      _namedValues[param.name!] = param;
    }

    // Create entry block
    final entryBlock = IrBasicBlock(_nextBlockId++, label: 'entry');
    function.addBlock(entryBlock);
    _currentBlock = entryBlock;

    // Build function body
    _buildBlock(node.body);

    // Clear state
    _currentFunction = null;
    _currentBlock = null;
    _namedValues.removeWhere((key, value) => parameters.contains(value));

    module.addFunction(function);
  }

  void _buildClassDecl(ClassDecl node) {
    // Build class methods and operators
    for (final member in node.members) {
      if (member is FunctionDecl) {
        // Build as a method (with implicit self parameter in the future)
        _buildFunctionDecl(member);
      } else if (member is ProcedureDecl) {
        _buildProcedureDecl(member);
      } else if (member is OperatorDecl) {
        _buildOperatorDecl(node.name, member);
      }
    }
  }

  void _buildOperatorDecl(String className, OperatorDecl node) {
    final returnType = _convertTypeSpec(node.returnType);
    final parameters = <IrValue>[];

    // Add self parameter (implicit)
    final selfParam = IrParameter(_nextValueId++, 'self', IrType(className));
    parameters.add(selfParam);

    // Add the operator parameter
    final paramType = _convertTypeSpec(node.parameter.type);
    final irParam = IrParameter(_nextValueId++, node.parameter.name, paramType);
    parameters.add(irParam);

    // Generate a unique function name for the operator
    final operatorName = '${className}_op_${_sanitizeOperator(node.operator)}';
    final function = IrFunction(operatorName, parameters, returnType);
    _currentFunction = function;

    // Save parameter values
    _namedValues['self'] = selfParam;
    _namedValues[node.parameter.name] = irParam;

    // Create entry block
    final entryBlock = IrBasicBlock(_nextBlockId++, label: 'entry');
    function.addBlock(entryBlock);
    _currentBlock = entryBlock;

    // Build operator body
    _buildBlock(node.body);

    // Clear state
    _currentFunction = null;
    _currentBlock = null;
    _namedValues.remove('self');
    _namedValues.remove(node.parameter.name);

    module.addFunction(function);
  }

  String _sanitizeOperator(String op) {
    // Convert operators to valid identifier characters
    return op
        .replaceAll('+', 'add')
        .replaceAll('-', 'sub')
        .replaceAll('*', 'mul')
        .replaceAll('/', 'div')
        .replaceAll('%', 'mod')
        .replaceAll('==', 'eq')
        .replaceAll('!=', 'neq')
        .replaceAll('<=', 'lte')
        .replaceAll('>=', 'gte')
        .replaceAll('<', 'lt')
        .replaceAll('>', 'gt')
        .replaceAll('&&', 'and')
        .replaceAll('||', 'or');
  }

  void _buildBlock(Block node) {
    for (final stmt in node.statements) {
      _buildStatement(stmt);
    }
  }

  void _buildStatement(Statement stmt) {
    if (stmt is VarDecl) {
      _buildVarDecl(stmt);
    } else if (stmt is IfStatement) {
      _buildIfStatement(stmt);
    } else if (stmt is WhileStatement) {
      _buildWhileStatement(stmt);
    } else if (stmt is ReturnStatement) {
      _buildReturnStatement(stmt);
    } else if (stmt is ExpressionStatement) {
      _buildExpression(stmt.expression);
    } else if (stmt is Block) {
      _buildBlock(stmt);
    }
  }

  void _buildVarDecl(VarDecl node) {
    for (final binding in node.bindings) {
      IrValue? value;
      
      if (binding.initializer != null) {
        value = _buildExpression(binding.initializer!);
      } else {
        // Allocate uninitialized variable
        final type = node.type != null ? _convertTypeSpec(node.type!) : IrType.i64;
        value = _createInstruction(IrOpcode.alloca, [], type: type);
      }
      
      if (value != null) {
        _namedValues[binding.name] = value;
      }
    }
  }

  void _buildIfStatement(IfStatement node) {
    final condition = _buildExpression(node.condition);
    if (condition == null) return;

    final thenBlock = IrBasicBlock(_nextBlockId++, label: 'then');
    final elseBlock = node.elseStatement != null
        ? IrBasicBlock(_nextBlockId++, label: 'else')
        : null;
    final mergeBlock = IrBasicBlock(_nextBlockId++, label: 'merge');

    // Conditional branch
    final branchTarget = elseBlock ?? mergeBlock;
    _currentBlock?.setTerminator(
      IrInstruction(_nextValueId++, IrOpcode.condBr, [condition])
    );

    // Then block
    _currentFunction?.addBlock(thenBlock);
    _currentBlock = thenBlock;
    _buildBlock(node.thenBlock);
    if (_currentBlock?.terminator == null) {
      _currentBlock?.setTerminator(
        IrInstruction(_nextValueId++, IrOpcode.br, [])
      );
    }

    // Else block
    if (elseBlock != null && node.elseStatement != null) {
      _currentFunction?.addBlock(elseBlock);
      _currentBlock = elseBlock;
      _buildStatement(node.elseStatement!);
      if (_currentBlock?.terminator == null) {
        _currentBlock?.setTerminator(
          IrInstruction(_nextValueId++, IrOpcode.br, [])
        );
      }
    }

    // Merge block
    _currentFunction?.addBlock(mergeBlock);
    _currentBlock = mergeBlock;
  }

  void _buildWhileStatement(WhileStatement node) {
    final headerBlock = IrBasicBlock(_nextBlockId++, label: 'while_header');
    final bodyBlock = IrBasicBlock(_nextBlockId++, label: 'while_body');
    final exitBlock = IrBasicBlock(_nextBlockId++, label: 'while_exit');

    // Branch to header
    _currentBlock?.setTerminator(
      IrInstruction(_nextValueId++, IrOpcode.br, [])
    );

    // Header block
    _currentFunction?.addBlock(headerBlock);
    _currentBlock = headerBlock;
    final condition = _buildExpression(node.condition);
    if (condition != null) {
      _currentBlock?.setTerminator(
        IrInstruction(_nextValueId++, IrOpcode.condBr, [condition])
      );
    }

    // Body block
    _currentFunction?.addBlock(bodyBlock);
    _currentBlock = bodyBlock;
    _buildBlock(node.body);
    if (_currentBlock?.terminator == null) {
      _currentBlock?.setTerminator(
        IrInstruction(_nextValueId++, IrOpcode.br, [])
      );
    }

    // Exit block
    _currentFunction?.addBlock(exitBlock);
    _currentBlock = exitBlock;
  }

  void _buildReturnStatement(ReturnStatement node) {
    IrValue? returnValue;
    
    if (node.value != null) {
      returnValue = _buildExpression(node.value!);
    }

    final operands = returnValue != null ? [returnValue] : <IrValue>[];
    _currentBlock?.setTerminator(
      IrInstruction(_nextValueId++, IrOpcode.ret, operands)
    );
  }

  IrValue? _buildExpression(Expression expr) {
    if (expr is LiteralExpr) {
      return _buildLiteral(expr);
    } else if (expr is IdentifierExpr) {
      return _namedValues[expr.name];
    } else if (expr is BinaryExpr) {
      return _buildBinaryExpr(expr);
    } else if (expr is UnaryExpr) {
      return _buildUnaryExpr(expr);
    } else if (expr is CallExpr) {
      return _buildCallExpr(expr);
    } else if (expr is AssignmentExpr) {
      return _buildAssignmentExpr(expr);
    } else if (expr is CastExpr) {
      return _buildCastExpr(expr);
    } else if (expr is LambdaExpr) {
      return _buildLambdaExpr(expr);
    } else if (expr is ArrayAllocationExpr) {
      return _buildArrayAllocationExpr(expr);
    } else if (expr is ArrayIndexExpr) {
      return _buildArrayIndexExpr(expr);
    } else if (expr is ArrayLiteralExpr) {
      return _buildArrayLiteralExpr(expr);
    }

    return null;
  }

  IrValue _buildLiteral(LiteralExpr expr) {
    IrType type;
    IrOpcode opcode;

    switch (expr.type) {
      case LiteralType.integer:
        type = IrType.i64;
        opcode = IrOpcode.constInt;
        break;
      case LiteralType.float:
        type = IrType.f64;
        opcode = IrOpcode.constFloat;
        break;
      case LiteralType.boolean:
        type = IrType.bool_;
        opcode = IrOpcode.constBool;
        break;
      case LiteralType.string:
        type = IrType.string;
        opcode = IrOpcode.constString;
        break;
    }

    return IrConstant(_nextValueId++, expr.value, type);
  }

  IrValue? _buildBinaryExpr(BinaryExpr expr) {
    final left = _buildExpression(expr.left);
    final right = _buildExpression(expr.right);
    
    if (left == null || right == null) return null;

    // Check if this is an operator overload call
    final leftType = typeAnalyzer.getType(expr.left);
    if (leftType != null && !leftType.isNumeric()) {
      // Try to find operator overload
      final operatorName = '${leftType.name}_op_${_sanitizeOperator(expr.operator)}';
      // Check if operator function exists in module
      final operatorFunc = module.functions.where((f) => f.name == operatorName).firstOrNull;
      if (operatorFunc != null) {
        // Call the operator overload
        final funcRef = IrConstant(_nextValueId++, operatorName, IrType('string'));
        return _createInstruction(IrOpcode.call, [funcRef, left, right]);
      }
    }

    // Default operator behavior
    IrOpcode opcode;
    switch (expr.operator) {
      case '+':
        opcode = IrOpcode.add;
        break;
      case '-':
        opcode = IrOpcode.sub;
        break;
      case '*':
        opcode = IrOpcode.mul;
        break;
      case '/':
        opcode = IrOpcode.div;
        break;
      case '%':
        opcode = IrOpcode.mod;
        break;
      case '==':
        opcode = IrOpcode.eq;
        break;
      case '!=':
        opcode = IrOpcode.neq;
        break;
      case '<':
        opcode = IrOpcode.lt;
        break;
      case '>':
        opcode = IrOpcode.gt;
        break;
      case '<=':
        opcode = IrOpcode.lte;
        break;
      case '>=':
        opcode = IrOpcode.gte;
        break;
      case '&&':
        opcode = IrOpcode.and;
        break;
      case '||':
        opcode = IrOpcode.or;
        break;
      default:
        return null;
    }

    return _createInstruction(opcode, [left, right], type: left.type);
  }

  IrValue? _buildUnaryExpr(UnaryExpr expr) {
    final operand = _buildExpression(expr.operand);
    if (operand == null) return null;

    IrOpcode opcode;
    switch (expr.operator) {
      case '-':
        opcode = IrOpcode.neg;
        break;
      case '!':
        opcode = IrOpcode.not;
        break;
      default:
        return null;
    }

    return _createInstruction(opcode, [operand], type: operand.type);
  }

  IrValue? _buildCallExpr(CallExpr expr) {
    final args = <IrValue>[];
    for (final arg in expr.arguments) {
      final argValue = _buildExpression(arg);
      if (argValue != null) args.add(argValue);
    }

    // Check if callee is a lambda or function reference
    final calleeType = typeAnalyzer.getType(expr.callee);
    if (calleeType != null && calleeType.name == 'function') {
      // Indirect call through function reference
      final callee = _buildExpression(expr.callee);
      if (callee == null) return null;
      
      return _createInstruction(IrOpcode.callIndirect, [callee, ...args]);
    }
    
    // Handle direct function calls by name
    IrValue? callee;
    if (expr.callee is IdentifierExpr) {
      final funcName = (expr.callee as IdentifierExpr).name;
      // Create a constant with the function name (use string type)
      callee = IrConstant(_nextValueId++, funcName, IrType('string'));
    } else {
      callee = _buildExpression(expr.callee);
    }
    
    if (callee == null) return null;

    return _createInstruction(IrOpcode.call, [callee, ...args]);
  }

  IrValue? _buildAssignmentExpr(AssignmentExpr expr) {
    final value = _buildExpression(expr.value);
    if (value == null) return null;

    final variable = _namedValues[expr.name];
    if (variable == null) return null;

    _createInstruction(IrOpcode.store, [value, variable]);
    return value;
  }

  IrValue? _buildCastExpr(CastExpr expr) {
    final value = _buildExpression(expr.expression);
    if (value == null) return null;

    final targetType = _convertTypeSpec(expr.type);
    return _createInstruction(IrOpcode.cast, [value], type: targetType);
  }

  IrValue? _buildLambdaExpr(LambdaExpr expr) {
    // Generate a unique name for the lambda function using instance counter
    final lambdaName = '__lambda_${_nextValueId++}';

    // Save current function and block state
    final savedFunction = _currentFunction;
    final savedBlock = _currentBlock;
    final savedNamedValues = Map<String, IrValue>.from(_namedValues);

    // Build parameters
    final parameters = <IrValue>[];
    for (final param in expr.parameters) {
      final paramType = _convertTypeSpec(param.type);
      final irParam = IrParameter(_nextValueId++, param.name, paramType);
      parameters.add(irParam);
    }

    // Determine return type
    final exprType = typeAnalyzer.getType(expr);
    IrType returnType = IrType.void_;
    if (exprType != null && exprType.name == 'function' && exprType.functionReturn != null) {
      returnType = _convertType(exprType.functionReturn!);
    }

    // Create the lambda function
    final lambdaFunction = IrFunction(lambdaName, parameters, returnType);
    _currentFunction = lambdaFunction;

    // Clear and bind parameters
    _namedValues.clear();
    for (final param in parameters) {
      _namedValues[param.name!] = param;
    }

    // Create entry block
    final entryBlock = IrBasicBlock(_nextBlockId++, label: 'entry');
    lambdaFunction.addBlock(entryBlock);
    _currentBlock = entryBlock;

    // Build lambda body
    if (expr.body is Expression) {
      final bodyValue = _buildExpression(expr.body as Expression);
      if (bodyValue != null) {
        _currentBlock?.setTerminator(
          IrInstruction(_nextValueId++, IrOpcode.ret, [bodyValue])
        );
      }
    } else if (expr.body is Block) {
      _buildBlock(expr.body as Block);
    }

    // Add function to module
    module.addFunction(lambdaFunction);

    // Restore state
    _currentFunction = savedFunction;
    _currentBlock = savedBlock;
    _namedValues.clear();
    _namedValues.addAll(savedNamedValues);

    // Return a function reference
    final funcRef = IrConstant(_nextValueId++, lambdaName, IrType('funcref'));
    return _createInstruction(IrOpcode.funcRef, [funcRef], type: returnType);
  }

  IrValue? _buildArrayAllocationExpr(ArrayAllocationExpr expr) {
    final size = _buildExpression(expr.size);
    if (size == null) return null;

    final elementType = _convertTypeSpec(expr.elementType);
    return _createInstruction(IrOpcode.arrayNewDefault, [size], type: IrType('array', [elementType]));
  }

  IrValue? _buildArrayIndexExpr(ArrayIndexExpr expr) {
    final array = _buildExpression(expr.array);
    final index = _buildExpression(expr.index);
    if (array == null || index == null) return null;

    return _createInstruction(IrOpcode.arrayGet, [array, index], type: array.type);
  }

  IrValue? _buildArrayLiteralExpr(ArrayLiteralExpr expr) {
    // NOTE: This implementation creates each element individually,
    // which could be inefficient for large arrays. A more efficient approach
    // would be to use array.new with a function that initializes elements,
    // but this requires more sophisticated code generation.
    if (expr.elements.isEmpty) {
      return _createInstruction(IrOpcode.arrayNewDefault, 
        [IrConstant(_nextValueId++, 0, IrType.i32)],
        type: IrType('array', [IrType.any]));
    }

    final elements = <IrValue>[];
    for (final elem in expr.elements) {
      final value = _buildExpression(elem);
      if (value != null) elements.add(value);
    }

    // Create array with size
    final size = IrConstant(_nextValueId++, expr.elements.length, IrType.i32);
    final array = _createInstruction(IrOpcode.arrayNewDefault, [size],
      type: IrType('array', [elements.isNotEmpty ? elements[0].type! : IrType.any]));

    // Set each element (simplified - would need proper array.set calls)
    for (int i = 0; i < elements.length; i++) {
      final index = IrConstant(_nextValueId++, i, IrType.i32);
      _createInstruction(IrOpcode.arraySet, [array, index, elements[i]]);
    }

    return array;
  }

  IrInstruction _createInstruction(IrOpcode opcode, List<IrValue> operands, {IrType? type}) {
    final instruction = IrInstruction(_nextValueId++, opcode, operands, type: type);
    _currentBlock?.add(instruction);
    return instruction;
  }

  IrType _convertType(PlasmType type) {
    switch (type.name) {
      case 'void': return IrType.void_;
      case 'i8': return IrType.i8;
      case 'i16': return IrType.i16;
      case 'i32': return IrType.i32;
      case 'i64': return IrType.i64;
      case 'u8': return IrType.u8;
      case 'u16': return IrType.u16;
      case 'u32': return IrType.u32;
      case 'u64': return IrType.u64;
      case 'f32': return IrType.f32;
      case 'f64': return IrType.f64;
      case 'bool': return IrType.bool_;
      case 'string': return IrType.string;
      default: return IrType(type.name);
    }
  }

  IrType _convertTypeSpec(TypeSpec spec) {
    if (spec.isVoid) return IrType.void_;
    
    switch (spec.name) {
      case 'u8': return IrType.u8;
      case 'u16': return IrType.u16;
      case 'u32': return IrType.u32;
      case 'u64': return IrType.u64;
      case 'i8': return IrType.i8;
      case 'i16': return IrType.i16;
      case 'i32': return IrType.i32;
      case 'i64': return IrType.i64;
      case 'f32': return IrType.f32;
      case 'f64': return IrType.f64;
      case 'bool': return IrType.bool_;
      default: return IrType(spec.name);
    }
  }
}

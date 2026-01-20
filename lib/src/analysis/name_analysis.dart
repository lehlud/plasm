import '../ast/ast.dart';

/// Symbol table for name resolution
class SymbolTable {
  final SymbolTable? parent;
  final Map<String, Symbol> _symbols = {};

  SymbolTable([this.parent]);

  void define(String name, Symbol symbol) {
    _symbols[name] = symbol;
  }

  Symbol? resolve(String name) {
    if (_symbols.containsKey(name)) {
      return _symbols[name];
    }
    return parent?.resolve(name);
  }

  bool isDefined(String name) {
    return _symbols.containsKey(name);
  }
}

/// Symbol representing a declaration
class Symbol {
  final String name;
  final AstNode declaration;
  final SymbolKind kind;

  Symbol(this.name, this.declaration, this.kind);
}

enum SymbolKind {
  constant,
  function,
  procedure,
  class_,
  parameter,
  variable,
  field,
}

/// Name analysis pass
class NameAnalyzer implements AstVisitor {
  final List<String> errors = [];
  SymbolTable _currentScope;

  NameAnalyzer() : _currentScope = SymbolTable();

  void analyze(Program program) {
    // First pass: collect top-level declarations
    for (final decl in program.declarations) {
      _registerDeclaration(decl);
    }

    // Second pass: resolve names
    for (final decl in program.declarations) {
      decl.accept(this);
    }
  }

  void _registerDeclaration(Declaration decl) {
    if (decl is ConstDecl) {
      if (_currentScope.isDefined(decl.name)) {
        _error('Duplicate declaration: ${decl.name}', decl.line, decl.column);
      } else {
        _currentScope.define(decl.name, Symbol(decl.name, decl, SymbolKind.constant));
      }
    } else if (decl is FunctionDecl) {
      if (_currentScope.isDefined(decl.name)) {
        _error('Duplicate declaration: ${decl.name}', decl.line, decl.column);
      } else {
        _currentScope.define(decl.name, Symbol(decl.name, decl, SymbolKind.function));
      }
    } else if (decl is ProcedureDecl) {
      if (_currentScope.isDefined(decl.name)) {
        _error('Duplicate declaration: ${decl.name}', decl.line, decl.column);
      } else {
        _currentScope.define(decl.name, Symbol(decl.name, decl, SymbolKind.procedure));
      }
    } else if (decl is ClassDecl) {
      if (_currentScope.isDefined(decl.name)) {
        _error('Duplicate declaration: ${decl.name}', decl.line, decl.column);
      } else {
        _currentScope.define(decl.name, Symbol(decl.name, decl, SymbolKind.class_));
      }
    }
  }

  void _enterScope() {
    _currentScope = SymbolTable(_currentScope);
  }

  void _exitScope() {
    _currentScope = _currentScope.parent!;
  }

  void _error(String message, int line, int column) {
    errors.add('Name error at $line:$column: $message');
  }

  @override
  void visitProgram(Program node) {
    for (final import in node.imports) {
      import.accept(this);
    }
    for (final decl in node.declarations) {
      decl.accept(this);
    }
  }

  @override
  void visitImportDecl(ImportDecl node) {
    // Import resolution would happen here in a full implementation
    // For now, we just note that imports exist
  }

  @override
  void visitConstDecl(ConstDecl node) {
    node.value.accept(this);
  }

  @override
  void visitFunctionDecl(FunctionDecl node) {
    _enterScope();

    for (final param in node.parameters) {
      if (_currentScope.isDefined(param.name)) {
        _error('Duplicate parameter: ${param.name}', param.line, param.column);
      } else {
        _currentScope.define(param.name, Symbol(param.name, param, SymbolKind.parameter));
      }
      param.accept(this);
    }

    node.returnType.accept(this);
    node.body.accept(this);

    _exitScope();
  }

  @override
  void visitProcedureDecl(ProcedureDecl node) {
    _enterScope();

    for (final param in node.parameters) {
      if (_currentScope.isDefined(param.name)) {
        _error('Duplicate parameter: ${param.name}', param.line, param.column);
      } else {
        _currentScope.define(param.name, Symbol(param.name, param, SymbolKind.parameter));
      }
      param.accept(this);
    }

    node.returnType.accept(this);
    node.body.accept(this);

    _exitScope();
  }

  @override
  void visitClassDecl(ClassDecl node) {
    _enterScope();

    // Register class members
    for (final member in node.members) {
      if (member is FieldDecl) {
        if (_currentScope.isDefined(member.name)) {
          _error('Duplicate field: ${member.name}', member.line, member.column);
        } else {
          _currentScope.define(member.name, Symbol(member.name, member, SymbolKind.field));
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
    node.type?.accept(this);
    node.initializer?.accept(this);
  }

  @override
  void visitConstructorDecl(ConstructorDecl node) {
    _enterScope();

    for (final param in node.parameters) {
      if (_currentScope.isDefined(param.name)) {
        _error('Duplicate parameter: ${param.name}', param.line, param.column);
      } else {
        _currentScope.define(param.name, Symbol(param.name, param, SymbolKind.parameter));
      }
      param.accept(this);
    }

    node.body.accept(this);

    _exitScope();
  }

  @override
  void visitOperatorDecl(OperatorDecl node) {
    _enterScope();

    if (_currentScope.isDefined(node.parameter.name)) {
      _error('Duplicate parameter: ${node.parameter.name}', node.parameter.line, node.parameter.column);
    } else {
      _currentScope.define(node.parameter.name, Symbol(node.parameter.name, node.parameter, SymbolKind.parameter));
    }

    node.parameter.accept(this);
    node.returnType.accept(this);
    node.body.accept(this);

    _exitScope();
  }

  @override
  void visitParameter(Parameter node) {
    node.type.accept(this);
  }

  @override
  void visitTypeSpec(TypeSpec node) {
    // Type checking would happen in type analysis
    if (node.typeArguments != null) {
      for (final arg in node.typeArguments!) {
        arg.accept(this);
      }
    }
    if (node.functionParams != null) {
      for (final param in node.functionParams!) {
        param.accept(this);
      }
    }
    node.functionReturn?.accept(this);
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
    node.type?.accept(this);
    
    for (final binding in node.bindings) {
      if (_currentScope.isDefined(binding.name)) {
        _error('Duplicate variable: ${binding.name}', node.line, node.column);
      } else {
        _currentScope.define(binding.name, Symbol(binding.name, node, SymbolKind.variable));
      }
      
      binding.initializer?.accept(this);
    }
  }

  @override
  void visitIfStatement(IfStatement node) {
    node.condition.accept(this);
    node.thenBlock.accept(this);
    node.elseStatement?.accept(this);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    node.condition.accept(this);
    node.body.accept(this);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    node.value?.accept(this);
  }

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    node.expression.accept(this);
  }

  @override
  void visitExpression(Expression node) {
    if (node is IdentifierExpr) {
      final symbol = _currentScope.resolve(node.name);
      if (symbol == null) {
        _error('Undefined identifier: ${node.name}', node.line, node.column);
      }
    } else if (node is BinaryExpr) {
      node.left.accept(this);
      node.right.accept(this);
    } else if (node is UnaryExpr) {
      node.operand.accept(this);
    } else if (node is CallExpr) {
      node.callee.accept(this);
      for (final arg in node.arguments) {
        arg.accept(this);
      }
    } else if (node is MemberAccessExpr) {
      node.object.accept(this);
    } else if (node is LambdaExpr) {
      _enterScope();
      
      for (final param in node.parameters) {
        if (_currentScope.isDefined(param.name)) {
          _error('Duplicate parameter: ${param.name}', param.line, param.column);
        } else {
          _currentScope.define(param.name, Symbol(param.name, param, SymbolKind.parameter));
        }
        param.accept(this);
      }
      
      if (node.body is Expression) {
        (node.body as Expression).accept(this);
      } else if (node.body is Block) {
        (node.body as Block).accept(this);
      }
      
      _exitScope();
    } else if (node is CastExpr) {
      node.type.accept(this);
      node.expression.accept(this);
    } else if (node is AssignmentExpr) {
      final symbol = _currentScope.resolve(node.name);
      if (symbol == null) {
        _error('Undefined variable: ${node.name}', node.line, node.column);
      } else if (symbol.kind == SymbolKind.constant ||
                 symbol.kind == SymbolKind.function ||
                 symbol.kind == SymbolKind.procedure) {
        _error('Cannot assign to ${symbol.kind.toString().split('.').last}: ${node.name}', node.line, node.column);
      }
      node.value.accept(this);
    } else if (node is IsExpr) {
      node.expression.accept(this);
      node.type.accept(this);
    } else if (node is StringInterpolationExpr) {
      for (final part in node.parts) {
        if (part is Expression) {
          part.accept(this);
        }
      }
    } else if (node is TupleExpr) {
      for (final element in node.elements) {
        element.accept(this);
      }
    } else if (node is ConstructorCallExpr) {
      final symbol = _currentScope.resolve(node.className);
      if (symbol == null) {
        _error('Undefined class: ${node.className}', node.line, node.column);
      } else if (symbol.kind != SymbolKind.class_) {
        _error('${node.className} is not a class', node.line, node.column);
      }
      for (final arg in node.arguments) {
        arg.accept(this);
      }
    }
    // Other expression types would be handled here
  }
}

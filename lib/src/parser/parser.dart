import '../ast/ast.dart';
import 'lexer.dart';

/// Recursive descent parser for Plasm
class Parser {
  final List<Token> tokens;
  final List<String> errors = [];
  int _current = 0;

  Parser(this.tokens);

  Program parse() {
    final imports = <ImportDecl>[];
    final declarations = <Declaration>[];

    try {
      // Parse imports
      while (_match([TokenType.import_])) {
        final import = _parseImport();
        if (import != null) imports.add(import);
      }

      // Parse declarations
      while (!_isAtEnd()) {
        final decl = _parseDeclaration();
        if (decl != null) declarations.add(decl);
      }
    } catch (e) {
      errors.add('Parse error: $e');
    }

    return Program(imports, declarations, errors, 1, 1);
  }

  ImportDecl? _parseImport() {
    final line = _previous().line;
    final column = _previous().column;
    
    final path = <String>[];
    bool isRelative = false;

    if (_match([TokenType.dot])) {
      isRelative = true;
      _consume(TokenType.slash, 'Expected / after .');
    }

    if (!_check(TokenType.identifier)) {
      _error('Expected import path');
      return null;
    }

    path.add(_advance().lexeme);

    while (_match([TokenType.slash])) {
      if (!_check(TokenType.identifier)) {
        _error('Expected identifier after /');
        break;
      }
      path.add(_advance().lexeme);
    }

    _consume(TokenType.semicolon, 'Expected ; after import');
    return ImportDecl(path, isRelative, line, column);
  }

  Declaration? _parseDeclaration() {
    try {
      // Check for visibility modifiers
      Visibility? visibility;
      if (_match([TokenType.pub])) {
        visibility = Visibility.pub;
      } else if (_match([TokenType.prot])) {
        visibility = Visibility.prot;
      }

      // Check for static
      bool isStatic = false;
      if (_match([TokenType.static_])) {
        isStatic = true;
      }

      if (_match([TokenType.const_])) {
        return _parseConstDecl();
      } else if (_match([TokenType.fn])) {
        return _parseFunctionDecl(visibility);
      } else if (_match([TokenType.proc])) {
        return _parseProcedureDecl(visibility, isStatic);
      } else if (_match([TokenType.class_])) {
        return _parseClassDecl();
      }

      _error('Expected declaration');
      _synchronize();
      return null;
    } catch (e) {
      _error('Error parsing declaration: $e');
      _synchronize();
      return null;
    }
  }

  ConstDecl? _parseConstDecl() {
    final line = _previous().line;
    final column = _previous().column;

    if (!_check(TokenType.identifier)) {
      _error('Expected identifier after const');
      return null;
    }

    final name = _advance().lexeme;
    _consume(TokenType.assign, 'Expected = after const name');
    
    final value = _parseExpression();
    if (value == null) {
      _error('Expected expression after =');
      return null;
    }

    _consume(TokenType.semicolon, 'Expected ; after const declaration');
    return ConstDecl(name, value, line, column);
  }

  FunctionDecl? _parseFunctionDecl(Visibility? visibility) {
    final line = _previous().line;
    final column = _previous().column;

    if (!_check(TokenType.identifier)) {
      _error('Expected function name');
      return null;
    }

    final name = _advance().lexeme;
    _consume(TokenType.lparen, 'Expected ( after function name');

    final parameters = _parseParameterList();

    _consume(TokenType.rparen, 'Expected ) after parameters');

    final returnType = _parseTypeSpec();
    if (returnType == null) {
      _error('Expected return type');
      return null;
    }

    final body = _parseBlock();
    if (body == null) {
      _error('Expected function body');
      return null;
    }

    return FunctionDecl(visibility, name, parameters, returnType, body, line, column);
  }

  ProcedureDecl? _parseProcedureDecl(Visibility? visibility, bool isStatic) {
    final line = _previous().line;
    final column = _previous().column;

    if (!_check(TokenType.procIdentifier)) {
      _error('Expected procedure identifier starting with \$');
      return null;
    }

    final name = _advance().lexeme;
    _consume(TokenType.lparen, 'Expected ( after procedure name');

    final parameters = _parseParameterList();

    _consume(TokenType.rparen, 'Expected ) after parameters');

    final returnType = _parseTypeSpec();
    if (returnType == null) {
      _error('Expected return type');
      return null;
    }

    final body = _parseBlock();
    if (body == null) {
      _error('Expected procedure body');
      return null;
    }

    return ProcedureDecl(visibility, isStatic, name, parameters, returnType, body, line, column);
  }

  ClassDecl? _parseClassDecl() {
    final line = _previous().line;
    final column = _previous().column;

    if (!_check(TokenType.identifier)) {
      _error('Expected class name');
      return null;
    }

    final name = _advance().lexeme;
    _consume(TokenType.lbrace, 'Expected { after class name');

    final members = <AstNode>[];
    while (!_check(TokenType.rbrace) && !_isAtEnd()) {
      final member = _parseClassMember();
      if (member != null) members.add(member);
    }

    _consume(TokenType.rbrace, 'Expected } after class body');
    return ClassDecl(name, members, line, column);
  }

  AstNode? _parseClassMember() {
    try {
      Visibility? visibility;
      if (_match([TokenType.pub])) {
        visibility = Visibility.pub;
      } else if (_match([TokenType.prot])) {
        visibility = Visibility.prot;
      }

      bool isStatic = false;
      if (_match([TokenType.static_])) {
        isStatic = true;
      }

      if (_match([TokenType.final_, TokenType.let_])) {
        return _parseFieldDecl(visibility, _previous().type == TokenType.final_);
      } else if (_match([TokenType.constructor])) {
        return _parseConstructorDecl(visibility);
      } else if (_match([TokenType.fn])) {
        return _parseFunctionDecl(visibility);
      } else if (_match([TokenType.proc])) {
        return _parseProcedureDecl(visibility, isStatic);
      } else if (_match([TokenType.op])) {
        return _parseOperatorDecl(visibility);
      }

      _error('Expected class member');
      _synchronize();
      return null;
    } catch (e) {
      _error('Error parsing class member: $e');
      _synchronize();
      return null;
    }
  }

  FieldDecl? _parseFieldDecl(Visibility? visibility, bool isFinal) {
    final line = _previous().line;
    final column = _previous().column;

    TypeSpec? type;
    if (!_check(TokenType.identifier) || _isPrimitiveType(_peek())) {
      type = _parseTypeSpec();
    }

    if (!_check(TokenType.identifier)) {
      _error('Expected field name');
      return null;
    }

    final name = _advance().lexeme;

    Expression? initializer;
    if (_match([TokenType.assign])) {
      initializer = _parseExpression();
    }

    _consume(TokenType.semicolon, 'Expected ; after field declaration');
    return FieldDecl(visibility, isFinal, type, name, initializer, line, column);
  }

  ConstructorDecl? _parseConstructorDecl(Visibility? visibility) {
    final line = _previous().line;
    final column = _previous().column;

    _consume(TokenType.lparen, 'Expected ( after constructor');

    final parameters = _parseParameterList();

    _consume(TokenType.rparen, 'Expected ) after parameters');

    final body = _parseBlock();
    if (body == null) {
      _error('Expected constructor body');
      return null;
    }

    return ConstructorDecl(visibility, parameters, body, line, column);
  }

  OperatorDecl? _parseOperatorDecl(Visibility? visibility) {
    final line = _previous().line;
    final column = _previous().column;

    _consume(TokenType.lparen, 'Expected ( before operator');

    String? op;
    if (_match([TokenType.plus])) op = '+';
    else if (_match([TokenType.minus])) op = '-';
    else if (_match([TokenType.star])) op = '*';
    else if (_match([TokenType.slash])) op = '/';
    else if (_match([TokenType.percent])) op = '%';
    else if (_match([TokenType.eq])) op = '==';
    else if (_match([TokenType.neq])) op = '!=';
    else if (_match([TokenType.lt])) op = '<';
    else if (_match([TokenType.gt])) op = '>';
    else if (_match([TokenType.lte])) op = '<=';
    else if (_match([TokenType.gte])) op = '>=';
    else if (_match([TokenType.and])) op = '&&';
    else if (_match([TokenType.or])) op = '||';

    if (op == null) {
      _error('Expected operator');
      return null;
    }

    _consume(TokenType.rparen, 'Expected ) after operator');
    _consume(TokenType.lparen, 'Expected ( before parameter');

    final param = _parseParameter();
    if (param == null) {
      _error('Expected parameter');
      return null;
    }

    _consume(TokenType.rparen, 'Expected ) after parameter');

    final returnType = _parseTypeSpec();
    if (returnType == null) {
      _error('Expected return type');
      return null;
    }

    final body = _parseBlock();
    if (body == null) {
      _error('Expected operator body');
      return null;
    }

    return OperatorDecl(visibility, op, param, returnType, body, line, column);
  }

  List<Parameter> _parseParameterList() {
    final parameters = <Parameter>[];

    if (!_check(TokenType.rparen)) {
      do {
        final param = _parseParameter();
        if (param != null) parameters.add(param);
      } while (_match([TokenType.comma]));
    }

    return parameters;
  }

  Parameter? _parseParameter() {
    final line = _peek().line;
    final column = _peek().column;

    final type = _parseTypeSpec();
    if (type == null) {
      _error('Expected parameter type');
      return null;
    }

    if (!_check(TokenType.identifier)) {
      _error('Expected parameter name');
      return null;
    }

    final name = _advance().lexeme;
    return Parameter(type, name, line, column);
  }

  TypeSpec? _parseTypeSpec() {
    final line = _peek().line;
    final column = _peek().column;

    if (_match([TokenType.void_])) {
      return TypeSpec.void_(line, column);
    } else if (_match([TokenType.any])) {
      return TypeSpec.any(line, column);
    } else if (_isPrimitiveType(_peek()) || _check(TokenType.identifier)) {
      final name = _advance().lexeme;

      // Check for generic type
      if (_match([TokenType.lt])) {
        final typeArgs = <TypeSpec>[];
        do {
          final arg = _parseTypeSpec();
          if (arg != null) typeArgs.add(arg);
        } while (_match([TokenType.comma]));

        _consume(TokenType.gt, 'Expected > after type arguments');
        return TypeSpec.generic(name, typeArgs, line, column);
      }

      return TypeSpec.simple(name, line, column);
    } else if (_match([TokenType.lparen])) {
      // Function type or tuple type
      final types = <TypeSpec>[];

      if (!_check(TokenType.rparen)) {
        do {
          final type = _parseTypeSpec();
          if (type != null) types.add(type);
        } while (_match([TokenType.comma]));
      }

      _consume(TokenType.rparen, 'Expected ) after type list');

      if (_match([TokenType.arrow])) {
        // Function type
        final returnType = _parseTypeSpec();
        if (returnType == null) {
          _error('Expected return type after =>');
          return null;
        }
        return TypeSpec.function(types, returnType, line, column);
      } else {
        // Tuple type (not fully implemented here, treating as function for now)
        return TypeSpec.simple('tuple', line, column);
      }
    }

    _error('Expected type specification');
    return null;
  }

  Block? _parseBlock() {
    final line = _peek().line;
    final column = _peek().column;

    _consume(TokenType.lbrace, 'Expected {');

    final statements = <Statement>[];
    while (!_check(TokenType.rbrace) && !_isAtEnd()) {
      final stmt = _parseStatement();
      if (stmt != null) statements.add(stmt);
    }

    _consume(TokenType.rbrace, 'Expected }');
    return Block(statements, line, column);
  }

  Statement? _parseStatement() {
    try {
      if (_match([TokenType.final_, TokenType.let_])) {
        return _parseVarDecl(_previous().type == TokenType.final_);
      } else if (_match([TokenType.if_])) {
        return _parseIfStatement();
      } else if (_match([TokenType.while_])) {
        return _parseWhileStatement();
      } else if (_match([TokenType.return_])) {
        return _parseReturnStatement();
      } else if (_check(TokenType.lbrace)) {
        return _parseBlock();
      } else {
        return _parseExpressionStatement();
      }
    } catch (e) {
      _error('Error parsing statement: $e');
      _synchronize();
      return null;
    }
  }

  VarDecl? _parseVarDecl(bool isFinal) {
    final line = _previous().line;
    final column = _previous().column;

    TypeSpec? type;
    if (!_check(TokenType.identifier) || _isPrimitiveType(_peek())) {
      type = _parseTypeSpec();
    }

    final bindings = <VarBinding>[];
    do {
      if (!_check(TokenType.identifier)) {
        _error('Expected variable name');
        continue;
      }

      final name = _advance().lexeme;
      Expression? initializer;

      if (_match([TokenType.assign])) {
        initializer = _parseExpression();
      }

      bindings.add(VarBinding(name, initializer));
    } while (_match([TokenType.comma]));

    _consume(TokenType.semicolon, 'Expected ; after variable declaration');
    return VarDecl(isFinal, type, bindings, line, column);
  }

  IfStatement? _parseIfStatement() {
    final line = _previous().line;
    final column = _previous().column;

    final hasParens = _match([TokenType.lparen]);
    
    final condition = _parseExpression();
    if (condition == null) {
      _error('Expected condition in if statement');
      return null;
    }

    if (hasParens) {
      _consume(TokenType.rparen, 'Expected ) after if condition');
    }

    final thenBlock = _parseBlock();
    if (thenBlock == null) {
      _error('Expected block after if condition');
      return null;
    }

    Statement? elseStatement;
    if (_match([TokenType.else_])) {
      if (_check(TokenType.if_)) {
        elseStatement = _parseIfStatement();
      } else {
        elseStatement = _parseBlock();
      }
    }

    return IfStatement(condition, thenBlock, elseStatement, line, column);
  }

  WhileStatement? _parseWhileStatement() {
    final line = _previous().line;
    final column = _previous().column;

    final hasParens = _match([TokenType.lparen]);
    
    final condition = _parseExpression();
    if (condition == null) {
      _error('Expected condition in while statement');
      return null;
    }

    if (hasParens) {
      _consume(TokenType.rparen, 'Expected ) after while condition');
    }

    final body = _parseBlock();
    if (body == null) {
      _error('Expected block after while condition');
      return null;
    }

    return WhileStatement(condition, body, line, column);
  }

  ReturnStatement? _parseReturnStatement() {
    final line = _previous().line;
    final column = _previous().column;

    Expression? value;
    if (!_check(TokenType.semicolon) && !_check(TokenType.rbrace)) {
      value = _parseExpression();
    }

    // Semicolon is now required
    _consume(TokenType.semicolon, 'Expected ; after return statement');

    return ReturnStatement(value, line, column);
  }

  ExpressionStatement? _parseExpressionStatement() {
    final line = _peek().line;
    final column = _peek().column;

    final expr = _parseExpression();
    if (expr == null) {
      _error('Expected expression');
      return null;
    }

    // Semicolon is now required
    _consume(TokenType.semicolon, 'Expected ; after expression statement');

    return ExpressionStatement(expr, line, column);
  }

  Expression? _parseExpression() {
    return _parseAssignment();
  }

  Expression? _parseAssignment() {
    final expr = _parseLogicalOr();
    if (expr == null) return null;

    if (_check(TokenType.assign) && expr is IdentifierExpr) {
      final line = _peek().line;
      final column = _peek().column;
      _advance();
      final value = _parseAssignment();
      if (value == null) {
        _error('Expected value after =');
        return null;
      }
      return AssignmentExpr(expr.name, value, line, column);
    }

    return expr;
  }

  Expression? _parseLogicalOr() {
    var expr = _parseLogicalAnd();
    if (expr == null) return null;

    while (_match([TokenType.or])) {
      final line = _previous().line;
      final column = _previous().column;
      final right = _parseLogicalAnd();
      if (right == null) {
        _error('Expected expression after ||');
        return expr;
      }
      expr = BinaryExpr(expr!, '||', right, line, column);
    }

    return expr;
  }

  Expression? _parseLogicalAnd() {
    var expr = _parseEquality();
    if (expr == null) return null;

    while (_match([TokenType.and])) {
      final line = _previous().line;
      final column = _previous().column;
      final right = _parseEquality();
      if (right == null) {
        _error('Expected expression after &&');
        return expr;
      }
      expr = BinaryExpr(expr!, '&&', right, line, column);
    }

    return expr;
  }

  Expression? _parseEquality() {
    var expr = _parseRelational();
    if (expr == null) return null;

    while (_match([TokenType.eq, TokenType.neq])) {
      final op = _previous().lexeme;
      final line = _previous().line;
      final column = _previous().column;
      final right = _parseRelational();
      if (right == null) {
        _error('Expected expression after $op');
        return expr;
      }
      expr = BinaryExpr(expr!, op, right, line, column);
    }

    return expr;
  }

  Expression? _parseRelational() {
    var expr = _parseAdditive();
    if (expr == null) return null;

    while (_match([TokenType.lt, TokenType.gt, TokenType.lte, TokenType.gte])) {
      final op = _previous().lexeme;
      final line = _previous().line;
      final column = _previous().column;
      final right = _parseAdditive();
      if (right == null) {
        _error('Expected expression after $op');
        return expr;
      }
      expr = BinaryExpr(expr!, op, right, line, column);
    }

    // Handle 'is' operator
    if (_match([TokenType.is_])) {
      final line = _previous().line;
      final column = _previous().column;
      final type = _parseTypeSpec();
      if (type == null) {
        _error('Expected type after is');
        return expr;
      }
      expr = IsExpr(expr!, type, line, column);
    }

    // Handle 'as' operator (explicit cast) - use while loop for left-associativity
    while (_match([TokenType.as_])) {
      final line = _previous().line;
      final column = _previous().column;
      final type = _parseTypeSpec();
      if (type == null) {
        _error('Expected type after as');
        return expr;
      }
      expr = CastExpr(type, expr!, line, column);
    }

    return expr;
  }

  Expression? _parseAdditive() {
    var expr = _parseMultiplicative();
    if (expr == null) return null;

    while (_match([TokenType.plus, TokenType.minus])) {
      final op = _previous().lexeme;
      final line = _previous().line;
      final column = _previous().column;
      final right = _parseMultiplicative();
      if (right == null) {
        _error('Expected expression after $op');
        return expr;
      }
      expr = BinaryExpr(expr!, op, right, line, column);
    }

    return expr;
  }

  Expression? _parseMultiplicative() {
    var expr = _parseUnary();
    if (expr == null) return null;

    while (_match([TokenType.star, TokenType.slash, TokenType.percent])) {
      final op = _previous().lexeme;
      final line = _previous().line;
      final column = _previous().column;
      final right = _parseUnary();
      if (right == null) {
        _error('Expected expression after $op');
        return expr;
      }
      expr = BinaryExpr(expr!, op, right, line, column);
    }

    return expr;
  }

  Expression? _parseUnary() {
    if (_match([TokenType.minus, TokenType.not])) {
      final op = _previous().lexeme;
      final line = _previous().line;
      final column = _previous().column;
      final expr = _parseUnary();
      if (expr == null) {
        _error('Expected expression after $op');
        return null;
      }
      return UnaryExpr(op, expr, line, column);
    }

    // Cast expression - check lookahead BEFORE consuming the (
    if (_check(TokenType.lparen) && _lookaheadTypeSpec()) {
      _advance(); // Now consume the (
      final line = _previous().line;
      final column = _previous().column;
      final type = _parseTypeSpec();
      _consume(TokenType.rparen, 'Expected ) after type');
      final expr = _parseUnary();
      if (expr == null || type == null) {
        _error('Expected expression after cast');
        return null;
      }
      return CastExpr(type, expr, line, column);
    }

    return _parsePostfix();
  }

  Expression? _parsePostfix() {
    var expr = _parsePrimary();
    if (expr == null) return null;

    while (true) {
      if (_match([TokenType.dot])) {
        final line = _previous().line;
        final column = _previous().column;
        
        if (_check(TokenType.identifier)) {
          final member = _advance().lexeme;
          expr = MemberAccessExpr(expr!, member, line, column);
        } else if (_check(TokenType.procIdentifier)) {
          final member = _advance().lexeme;
          expr = MemberAccessExpr(expr!, member, line, column);
        } else {
          _error('Expected member name after .');
          return expr;
        }
      } else if (_match([TokenType.lbracket])) {
        // Array indexing
        final line = _previous().line;
        final column = _previous().column;
        final index = _parseExpression();
        if (index == null) {
          _error('Expected index expression');
          return expr;
        }
        _consume(TokenType.rbracket, 'Expected ] after array index');
        expr = ArrayIndexExpr(expr!, index, line, column);
      } else if (_match([TokenType.lparen])) {
        final line = _previous().line;
        final column = _previous().column;
        final arguments = _parseArgumentList();
        _consume(TokenType.rparen, 'Expected ) after arguments');
        expr = CallExpr(expr!, arguments, line, column);
      } else {
        break;
      }
    }

    return expr;
  }

  Expression? _parsePrimary() {
    final line = _peek().line;
    final column = _peek().column;

    if (_match([TokenType.true_, TokenType.false_])) {
      return LiteralExpr(
          _previous().type == TokenType.true_, LiteralType.boolean, line, column);
    }

    if (_match([TokenType.integerLiteral])) {
      return LiteralExpr(_previous().value, LiteralType.integer, line, column);
    }

    if (_match([TokenType.floatLiteral])) {
      return LiteralExpr(_previous().value, LiteralType.float, line, column);
    }

    if (_match([TokenType.stringLiteral])) {
      return LiteralExpr(_previous().value, LiteralType.string, line, column);
    }

    if (_match([TokenType.self_])) {
      if (_match([TokenType.dot])) {
        if (_check(TokenType.identifier) || _check(TokenType.procIdentifier)) {
          final member = _advance().lexeme;
          return MemberAccessExpr(SelfExpr(line, column), member, line, column);
        }
      }
      return SelfExpr(line, column);
    }

    // Array allocation: new Type[size]
    if (_match([TokenType.new_])) {
      final newLine = _previous().line;
      final newColumn = _previous().column;
      
      final type = _parseTypeSpec();
      if (type == null) {
        _error('Expected type after new');
        return null;
      }
      
      if (_match([TokenType.lbracket])) {
        final sizeExpr = _parseExpression();
        if (sizeExpr == null) {
          _error('Expected size expression for array allocation');
          return null;
        }
        _consume(TokenType.rbracket, 'Expected ] after array size');
        return ArrayAllocationExpr(type, sizeExpr, newLine, newColumn);
      } else {
        _error('Expected [ after type in array allocation');
        return null;
      }
    }

    // Array literal: [expr, expr, ...]
    if (_match([TokenType.lbracket])) {
      final bracketLine = _previous().line;
      final bracketColumn = _previous().column;
      
      final elements = <Expression>[];
      if (!_check(TokenType.rbracket)) {
        do {
          final expr = _parseExpression();
          if (expr != null) {
            elements.add(expr);
          }
        } while (_match([TokenType.comma]));
      }
      
      _consume(TokenType.rbracket, 'Expected ] after array elements');
      return ArrayLiteralExpr(elements, bracketLine, bracketColumn);
    }

    if (_match([TokenType.identifier])) {
      final name = _previous().lexeme;
      return IdentifierExpr(name, line, column);
    }

    if (_match([TokenType.procIdentifier])) {
      final name = _previous().lexeme;
      
      // Proc call
      if (_match([TokenType.lparen])) {
        final arguments = _parseArgumentList();
        _consume(TokenType.rparen, 'Expected ) after arguments');
        return CallExpr(IdentifierExpr(name, line, column), arguments, line, column);
      }
      
      return IdentifierExpr(name, line, column);
    }

    if (_match([TokenType.at])) {
      // Lambda expression
      _consume(TokenType.lparen, 'Expected ( after @');
      final parameters = _parseParameterList();
      _consume(TokenType.rparen, 'Expected ) after lambda parameters');

      if (_match([TokenType.arrow])) {
        final body = _parseExpression();
        if (body == null) {
          _error('Expected expression after =>');
          return null;
        }
        return LambdaExpr(parameters, body, line, column);
      } else {
        final body = _parseBlock();
        if (body == null) {
          _error('Expected block for lambda');
          return null;
        }
        return LambdaExpr(parameters, body, line, column);
      }
    }

    if (_match([TokenType.lparen])) {
      final expr = _parseExpression();
      if (expr == null) {
        _error('Expected expression after (');
        return null;
      }

      // Check for tuple
      if (_match([TokenType.comma])) {
        final elements = <Expression>[expr];
        do {
          final element = _parseExpression();
          if (element != null) elements.add(element);
        } while (_match([TokenType.comma]));
        
        _consume(TokenType.rparen, 'Expected ) after tuple');
        return TupleExpr(elements, line, column);
      }

      _consume(TokenType.rparen, 'Expected ) after expression');
      return expr;
    }

    _error('Unexpected token: ${_peek().lexeme}');
    return null;
  }

  List<Expression> _parseArgumentList() {
    final arguments = <Expression>[];

    if (!_check(TokenType.rparen)) {
      do {
        final arg = _parseExpression();
        if (arg != null) arguments.add(arg);
      } while (_match([TokenType.comma]));
    }

    return arguments;
  }

  bool _isPrimitiveType(Token token) {
    return token.type == TokenType.u8 ||
        token.type == TokenType.u16 ||
        token.type == TokenType.u32 ||
        token.type == TokenType.u64 ||
        token.type == TokenType.i8 ||
        token.type == TokenType.i16 ||
        token.type == TokenType.i32 ||
        token.type == TokenType.i64 ||
        token.type == TokenType.f32 ||
        token.type == TokenType.f64 ||
        token.type == TokenType.bool_;
  }

  bool _lookaheadTypeSpec() {
    // Simple lookahead to check if this looks like a type spec
    // Skip the opening ( if we're checking for a cast
    final saved = _current;
    if (_check(TokenType.lparen)) {
      _advance(); // Skip the (
    }
    final isType = _isPrimitiveType(_peek()) || 
                   _check(TokenType.identifier) ||
                   _check(TokenType.void_) ||
                   _check(TokenType.any);
    _current = saved;
    return isType;
  }

  bool _match(List<TokenType> types) {
    for (final type in types) {
      if (_check(type)) {
        _advance();
        return true;
      }
    }
    return false;
  }

  bool _check(TokenType type) {
    if (_isAtEnd()) return false;
    return _peek().type == type;
  }

  Token _advance() {
    if (!_isAtEnd()) _current++;
    return _previous();
  }

  bool _isAtEnd() => _peek().type == TokenType.eof;

  Token _peek() => tokens[_current];

  Token _previous() => tokens[_current - 1];

  void _consume(TokenType type, String message) {
    if (_check(type)) {
      _advance();
      return;
    }

    _error(message);
  }

  void _error(String message) {
    final token = _peek();
    errors.add('Parse error at ${token.line}:${token.column}: $message');
  }

  void _synchronize() {
    _advance();

    while (!_isAtEnd()) {
      if (_previous().type == TokenType.semicolon) return;

      switch (_peek().type) {
        case TokenType.class_:
        case TokenType.fn:
        case TokenType.proc:
        case TokenType.const_:
        case TokenType.final_:
        case TokenType.let_:
        case TokenType.if_:
        case TokenType.while_:
        case TokenType.return_:
          return;
        default:
          _advance();
      }
    }
  }
}

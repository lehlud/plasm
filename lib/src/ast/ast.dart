/// AST node base class
abstract class AstNode {
  final int line;
  final int column;

  AstNode(this.line, this.column);

  void accept(AstVisitor visitor);
}

/// Visitor interface for AST traversal
abstract class AstVisitor {
  void visitProgram(Program node);
  void visitImportDecl(ImportDecl node);
  void visitConstDecl(ConstDecl node);
  void visitFunctionDecl(FunctionDecl node);
  void visitProcedureDecl(ProcedureDecl node);
  void visitClassDecl(ClassDecl node);
  void visitFieldDecl(FieldDecl node);
  void visitConstructorDecl(ConstructorDecl node);
  void visitOperatorDecl(OperatorDecl node);
  void visitParameter(Parameter node);
  void visitTypeSpec(TypeSpec node);
  void visitBlock(Block node);
  void visitVarDecl(VarDecl node);
  void visitIfStatement(IfStatement node);
  void visitWhileStatement(WhileStatement node);
  void visitReturnStatement(ReturnStatement node);
  void visitExpressionStatement(ExpressionStatement node);
  void visitExpression(Expression node);
}

/// Program root node
class Program extends AstNode {
  final List<ImportDecl> imports;
  final List<Declaration> declarations;
  final List<String> errors;

  Program(this.imports, this.declarations, this.errors, int line, int column)
      : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitProgram(this);
}

/// Import declaration
class ImportDecl extends AstNode {
  final List<String> path;
  final bool isRelative;

  ImportDecl(this.path, this.isRelative, int line, int column)
      : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitImportDecl(this);
}

/// Base class for declarations
abstract class Declaration extends AstNode {
  Declaration(int line, int column) : super(line, column);
}

/// Const declaration
class ConstDecl extends Declaration {
  final String name;
  final Expression value;

  ConstDecl(this.name, this.value, int line, int column) : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitConstDecl(this);
}

/// Function declaration
class FunctionDecl extends Declaration {
  final Visibility? visibility;
  final String name;
  final List<Parameter> parameters;
  final TypeSpec returnType;
  final Block body;

  FunctionDecl(this.visibility, this.name, this.parameters, this.returnType,
      this.body, int line, int column)
      : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitFunctionDecl(this);
}

/// Procedure declaration
class ProcedureDecl extends Declaration {
  final Visibility? visibility;
  final bool isStatic;
  final String name;
  final List<Parameter> parameters;
  final TypeSpec returnType;
  final Block body;

  ProcedureDecl(this.visibility, this.isStatic, this.name, this.parameters,
      this.returnType, this.body, int line, int column)
      : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitProcedureDecl(this);
}

/// Class declaration
class ClassDecl extends Declaration {
  final String name;
  final List<AstNode> members; // Can be ClassMember, FunctionDecl, ProcedureDecl

  ClassDecl(this.name, this.members, int line, int column) : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitClassDecl(this);
}

/// Base class for class members
abstract class ClassMember extends AstNode {
  ClassMember(int line, int column) : super(line, column);
}

/// Field declaration
class FieldDecl extends ClassMember {
  final Visibility? visibility;
  final bool isFinal;
  final TypeSpec? type;
  final String name;
  final Expression? initializer;

  FieldDecl(this.visibility, this.isFinal, this.type, this.name,
      this.initializer, int line, int column)
      : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitFieldDecl(this);
}

/// Constructor declaration
class ConstructorDecl extends ClassMember {
  final Visibility? visibility;
  final List<Parameter> parameters;
  final Block body;

  ConstructorDecl(this.visibility, this.parameters, this.body, int line,
      int column)
      : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitConstructorDecl(this);
}

/// Operator declaration
class OperatorDecl extends ClassMember {
  final Visibility? visibility;
  final String operator;
  final Parameter parameter;
  final TypeSpec returnType;
  final Block body;

  OperatorDecl(this.visibility, this.operator, this.parameter, this.returnType,
      this.body, int line, int column)
      : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitOperatorDecl(this);
}

/// Parameter
class Parameter extends AstNode {
  final TypeSpec type;
  final String name;

  Parameter(this.type, this.name, int line, int column) : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitParameter(this);
}

/// Type specification
class TypeSpec extends AstNode {
  final String name;
  final List<TypeSpec>? typeArguments;
  final bool isVoid;
  final bool isAny;
  final List<TypeSpec>? functionParams;
  final TypeSpec? functionReturn;

  TypeSpec.simple(this.name, int line, int column)
      : typeArguments = null,
        isVoid = false,
        isAny = false,
        functionParams = null,
        functionReturn = null,
        super(line, column);

  TypeSpec.void_(int line, int column)
      : name = 'void',
        typeArguments = null,
        isVoid = true,
        isAny = false,
        functionParams = null,
        functionReturn = null,
        super(line, column);

  TypeSpec.any(int line, int column)
      : name = 'any',
        typeArguments = null,
        isVoid = false,
        isAny = true,
        functionParams = null,
        functionReturn = null,
        super(line, column);

  TypeSpec.generic(this.name, this.typeArguments, int line, int column)
      : isVoid = false,
        isAny = false,
        functionParams = null,
        functionReturn = null,
        super(line, column);

  TypeSpec.function(this.functionParams, this.functionReturn, int line,
      int column)
      : name = 'function',
        typeArguments = null,
        isVoid = false,
        isAny = false,
        super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitTypeSpec(this);
}

/// Visibility modifier
enum Visibility { pub, prot }

/// Block statement
/// Block statement
class Block extends Statement {
  final List<Statement> statements;

  Block(this.statements, int line, int column) : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitBlock(this);
}

/// Base class for statements
abstract class Statement extends AstNode {
  Statement(int line, int column) : super(line, column);
}

/// Variable declaration statement
class VarDecl extends Statement {
  final bool isFinal;
  final TypeSpec? type;
  final List<VarBinding> bindings;

  VarDecl(this.isFinal, this.type, this.bindings, int line, int column)
      : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitVarDecl(this);
}

/// Variable binding
class VarBinding {
  final String name;
  final Expression? initializer;

  VarBinding(this.name, this.initializer);
}

/// If statement
class IfStatement extends Statement {
  final Expression condition;
  final Block thenBlock;
  final Statement? elseStatement;

  IfStatement(this.condition, this.thenBlock, this.elseStatement, int line,
      int column)
      : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitIfStatement(this);
}

/// While statement
class WhileStatement extends Statement {
  final Expression condition;
  final Block body;

  WhileStatement(this.condition, this.body, int line, int column)
      : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitWhileStatement(this);
}

/// Return statement
class ReturnStatement extends Statement {
  final Expression? value;

  ReturnStatement(this.value, int line, int column) : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitReturnStatement(this);
}

/// Expression statement
class ExpressionStatement extends Statement {
  final Expression expression;

  ExpressionStatement(this.expression, int line, int column)
      : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitExpressionStatement(this);
}

/// Base class for expressions
abstract class Expression extends AstNode {
  Expression(int line, int column) : super(line, column);

  @override
  void accept(AstVisitor visitor) => visitor.visitExpression(this);
}

/// Identifier expression
class IdentifierExpr extends Expression {
  final String name;

  IdentifierExpr(this.name, int line, int column) : super(line, column);
}

/// Literal expression
class LiteralExpr extends Expression {
  final dynamic value;
  final LiteralType type;

  LiteralExpr(this.value, this.type, int line, int column) : super(line, column);
}

enum LiteralType { integer, float, boolean, string }

/// Binary expression
class BinaryExpr extends Expression {
  final Expression left;
  final String operator;
  final Expression right;

  BinaryExpr(this.left, this.operator, this.right, int line, int column)
      : super(line, column);
}

/// Unary expression
class UnaryExpr extends Expression {
  final String operator;
  final Expression operand;

  UnaryExpr(this.operator, this.operand, int line, int column)
      : super(line, column);
}

/// Call expression
class CallExpr extends Expression {
  final Expression callee;
  final List<Expression> arguments;

  CallExpr(this.callee, this.arguments, int line, int column)
      : super(line, column);
}

/// Member access expression
class MemberAccessExpr extends Expression {
  final Expression object;
  final String member;

  MemberAccessExpr(this.object, this.member, int line, int column)
      : super(line, column);
}

/// Lambda expression
class LambdaExpr extends Expression {
  final List<Parameter> parameters;
  final dynamic body; // Expression or Block

  LambdaExpr(this.parameters, this.body, int line, int column)
      : super(line, column);
}

/// Cast expression
class CastExpr extends Expression {
  final TypeSpec type;
  final Expression expression;

  CastExpr(this.type, this.expression, int line, int column)
      : super(line, column);
}

/// Assignment expression
class AssignmentExpr extends Expression {
  final String name;
  final Expression value;

  AssignmentExpr(this.name, this.value, int line, int column)
      : super(line, column);
}

/// Type check expression
class IsExpr extends Expression {
  final Expression expression;
  final TypeSpec type;

  IsExpr(this.expression, this.type, int line, int column) : super(line, column);
}

/// String interpolation expression
class StringInterpolationExpr extends Expression {
  final List<dynamic> parts; // String or Expression

  StringInterpolationExpr(this.parts, int line, int column) : super(line, column);
}

/// Self expression
class SelfExpr extends Expression {
  SelfExpr(int line, int column) : super(line, column);
}

/// Tuple expression
class TupleExpr extends Expression {
  final List<Expression> elements;

  TupleExpr(this.elements, int line, int column) : super(line, column);
}

/// Constructor call expression
class ConstructorCallExpr extends Expression {
  final String className;
  final List<Expression> arguments;

  ConstructorCallExpr(this.className, this.arguments, int line, int column)
      : super(line, column);
}

/// Array allocation expression (new Type[size])
class ArrayAllocationExpr extends Expression {
  final TypeSpec elementType;
  final Expression size;

  ArrayAllocationExpr(this.elementType, this.size, int line, int column)
      : super(line, column);
}

/// Array index expression (array[index])
class ArrayIndexExpr extends Expression {
  final Expression array;
  final Expression index;

  ArrayIndexExpr(this.array, this.index, int line, int column)
      : super(line, column);
}

/// Array literal expression ([1, 2, 3])
class ArrayLiteralExpr extends Expression {
  final List<Expression> elements;

  ArrayLiteralExpr(this.elements, int line, int column)
      : super(line, column);
}

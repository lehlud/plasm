grammar Plasm;

// Parser Rules

program
    : importDecl* declaration* EOF
    ;

importDecl
    : 'import' importPath ';'
    ;

importPath
    : IDENTIFIER ('/' IDENTIFIER)*
    | '.' '/' IDENTIFIER ('/' IDENTIFIER)*
    ;

declaration
    : constDecl
    | functionDecl
    | procedureDecl
    | classDecl
    ;

constDecl
    : 'const' IDENTIFIER '=' expression ';'
    ;

functionDecl
    : visibility? 'fn' IDENTIFIER '(' parameterList? ')' typeSpec block
    ;

procedureDecl
    : visibility? 'proc' PROC_IDENTIFIER '(' parameterList? ')' typeSpec block
    | visibility? 'static' 'proc' PROC_IDENTIFIER '(' parameterList? ')' typeSpec block
    ;

classDecl
    : 'class' IDENTIFIER '{' classMember* '}'
    ;

classMember
    : fieldDecl
    | constructorDecl
    | functionDecl
    | procedureDecl
    | operatorDecl
    ;

fieldDecl
    : visibility? 'final' typeSpec? IDENTIFIER ';'
    | visibility? 'let' typeSpec? IDENTIFIER ('=' expression)? ';'
    ;

constructorDecl
    : visibility? 'constructor' '(' parameterList? ')' block
    ;

operatorDecl
    : visibility? 'op' '(' operator ')' '(' parameter ')' typeSpec block
    ;

operator
    : '+'
    | '-'
    | '*'
    | '/'
    | '%'
    | '=='
    | '!='
    | '<'
    | '>'
    | '<='
    | '>='
    | '&&'
    | '||'
    ;

visibility
    : 'pub'
    | 'prot'
    ;

parameterList
    : parameter (',' parameter)*
    ;

parameter
    : typeSpec IDENTIFIER
    ;

typeSpec
    : primitiveType
    | IDENTIFIER
    | functionType
    | tupleType
    | genericType
    | 'void'
    | 'any'
    ;

primitiveType
    : 'u8'
    | 'u16'
    | 'u32'
    | 'u64'
    | 'i8'
    | 'i16'
    | 'i32'
    | 'i64'
    | 'f32'
    | 'f64'
    | 'bool'
    ;

functionType
    : '(' typeList? ')' '=>' typeSpec
    ;

tupleType
    : '(' typeList ')'
    ;

genericType
    : IDENTIFIER '<' typeList '>'
    ;

typeList
    : typeSpec (',' typeSpec)*
    ;

block
    : '{' statement* '}'
    ;

statement
    : varDecl
    | ifStatement
    | whileStatement
    | returnStatement
    | expressionStatement
    | block
    ;

varDecl
    : 'final' typeSpec? varBinding (',' varBinding)* ';'
    | 'let' typeSpec? varBinding (',' varBinding)* ';'
    ;

varBinding
    : IDENTIFIER ('=' expression)?
    ;

ifStatement
    : 'if' '('? expression ')'? block ('else' (ifStatement | block))?
    ;

whileStatement
    : 'while' '('? expression ')'? block
    ;

returnStatement
    : 'return' expression? ';'?
    ;

expressionStatement
    : expression ';'?
    ;

expression
    : primary                                                   # PrimaryExpression
    | expression '.' IDENTIFIER                                # MemberAccessExpression
    | expression '.' PROC_IDENTIFIER                           # ProcAccessExpression
    | expression '(' argumentList? ')'                         # CallExpression
    | PROC_IDENTIFIER '(' argumentList? ')'                    # ProcCallExpression
    | 'self' '.' IDENTIFIER                                    # SelfMemberAccessExpression
    | 'self' '.' PROC_IDENTIFIER                               # SelfProcAccessExpression
    | '@' '(' parameterList? ')' '=>' expression               # LambdaExpression
    | '@' '(' parameterList? ')' block                         # LambdaBlockExpression
    | '(' typeSpec ')' expression                              # CastExpression
    | '-' expression                                           # UnaryMinusExpression
    | '!' expression                                           # LogicalNotExpression
    | expression op=('*' | '/' | '%') expression               # MultiplicativeExpression
    | expression op=('+' | '-') expression                     # AdditiveExpression
    | expression op=('<' | '>' | '<=' | '>=') expression       # RelationalExpression
    | expression op=('==' | '!=') expression                   # EqualityExpression
    | expression 'is' typeSpec                                 # IsExpression
    | expression '&&' expression                               # LogicalAndExpression
    | expression '||' expression                               # LogicalOrExpression
    | IDENTIFIER '=' expression                                # AssignmentExpression
    ;

primary
    : IDENTIFIER
    | literal
    | '(' expression ')'
    | tupleExpression
    | constructorCall
    | stringInterpolation
    ;

constructorCall
    : IDENTIFIER '(' argumentList? ')'
    ;

tupleExpression
    : '(' expression ',' expression (',' expression)* ')'
    ;

argumentList
    : expression (',' expression)*
    ;

literal
    : INTEGER_LITERAL
    | FLOAT_LITERAL
    | BOOLEAN_LITERAL
    | STRING_LITERAL
    ;

stringInterpolation
    : STRING_INTERP_START stringInterpPart* STRING_INTERP_END
    ;

stringInterpPart
    : STRING_INTERP_TEXT
    | STRING_INTERP_EXPR_START expression '}'
    ;

// Lexer Rules

BOOLEAN_LITERAL
    : 'true'
    | 'false'
    ;

INTEGER_LITERAL
    : [0-9]+
    ;

FLOAT_LITERAL
    : [0-9]+ '.' [0-9]+
    ;

STRING_LITERAL
    : '"' (~["\\\r\n] | '\\' .)* '"'
    ;

STRING_INTERP_START
    : '"' -> pushMode(STRING_MODE)
    ;

PROC_IDENTIFIER
    : '$' [a-zA-Z_][a-zA-Z0-9_]*
    ;

IDENTIFIER
    : [a-zA-Z_][a-zA-Z0-9_]*
    ;

WS
    : [ \t\r\n]+ -> skip
    ;

COMMENT
    : '//' ~[\r\n]* -> skip
    ;

BLOCK_COMMENT
    : '/*' .*? '*/' -> skip
    ;

mode STRING_MODE;

STRING_INTERP_EXPR_START
    : '${' -> pushMode(DEFAULT_MODE)
    ;

STRING_INTERP_TEXT
    : (~["$\\] | '\\' . | '$' ~[{])+
    ;

STRING_INTERP_END
    : '"' -> popMode
    ;

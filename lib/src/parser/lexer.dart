/// Token types for the Plasm language
enum TokenType {
  // Keywords
  import_,
  const_,
  fn,
  proc,
  class_,
  constructor,
  op,
  pub,
  prot,
  static_,
  final_,
  let_,
  if_,
  else_,
  while_,
  return_,
  self_,
  is_,
  any,
  void_,
  
  // Primitive types
  u8,
  u16,
  u32,
  u64,
  i8,
  i16,
  i32,
  i64,
  f32,
  f64,
  bool_,
  
  // Literals
  true_,
  false_,
  integerLiteral,
  floatLiteral,
  stringLiteral,
  
  // Identifiers
  identifier,
  procIdentifier,
  
  // Operators
  plus,
  minus,
  star,
  slash,
  percent,
  eq,
  neq,
  lt,
  gt,
  lte,
  gte,
  and,
  or,
  not,
  assign,
  
  // Punctuation
  lparen,
  rparen,
  lbrace,
  rbrace,
  lbracket,
  rbracket,
  comma,
  semicolon,
  colon,
  dot,
  arrow,
  at,
  dollar,
  
  // Special
  eof,
  error,
}

/// Token class
class Token {
  final TokenType type;
  final String lexeme;
  final int line;
  final int column;
  final dynamic value;

  Token(this.type, this.lexeme, this.line, this.column, [this.value]);

  @override
  String toString() => 'Token($type, $lexeme, $line:$column)';
}

/// Lexer for the Plasm language
class Lexer {
  final String source;
  final List<String> errors = [];
  int _position = 0;
  int _line = 1;
  int _column = 1;

  static final Map<String, TokenType> _keywords = {
    'import': TokenType.import_,
    'const': TokenType.const_,
    'fn': TokenType.fn,
    'proc': TokenType.proc,
    'class': TokenType.class_,
    'constructor': TokenType.constructor,
    'op': TokenType.op,
    'pub': TokenType.pub,
    'prot': TokenType.prot,
    'static': TokenType.static_,
    'final': TokenType.final_,
    'let': TokenType.let_,
    'if': TokenType.if_,
    'else': TokenType.else_,
    'while': TokenType.while_,
    'return': TokenType.return_,
    'self': TokenType.self_,
    'is': TokenType.is_,
    'any': TokenType.any,
    'void': TokenType.void_,
    'u8': TokenType.u8,
    'u16': TokenType.u16,
    'u32': TokenType.u32,
    'u64': TokenType.u64,
    'i8': TokenType.i8,
    'i16': TokenType.i16,
    'i32': TokenType.i32,
    'i64': TokenType.i64,
    'f32': TokenType.f32,
    'f64': TokenType.f64,
    'bool': TokenType.bool_,
    'true': TokenType.true_,
    'false': TokenType.false_,
  };

  Lexer(this.source);

  List<Token> tokenize() {
    final tokens = <Token>[];
    
    while (!_isAtEnd()) {
      _skipWhitespaceAndComments();
      if (_isAtEnd()) break;
      
      final token = _nextToken();
      if (token != null) {
        tokens.add(token);
      }
    }
    
    tokens.add(Token(TokenType.eof, '', _line, _column));
    return tokens;
  }

  Token? _nextToken() {
    final line = _line;
    final column = _column;
    final char = _advance();

    switch (char) {
      case '+':
        return Token(TokenType.plus, '+', line, column);
      case '-':
        return Token(TokenType.minus, '-', line, column);
      case '*':
        return Token(TokenType.star, '*', line, column);
      case '/':
        return Token(TokenType.slash, '/', line, column);
      case '%':
        return Token(TokenType.percent, '%', line, column);
      case '(':
        return Token(TokenType.lparen, '(', line, column);
      case ')':
        return Token(TokenType.rparen, ')', line, column);
      case '{':
        return Token(TokenType.lbrace, '{', line, column);
      case '}':
        return Token(TokenType.rbrace, '}', line, column);
      case '[':
        return Token(TokenType.lbracket, '[', line, column);
      case ']':
        return Token(TokenType.rbracket, ']', line, column);
      case ',':
        return Token(TokenType.comma, ',', line, column);
      case ';':
        return Token(TokenType.semicolon, ';', line, column);
      case ':':
        return Token(TokenType.colon, ':', line, column);
      case '.':
        return Token(TokenType.dot, '.', line, column);
      case '@':
        return Token(TokenType.at, '@', line, column);
      case '\$':
        if (_isAlpha(_peek())) {
          return _procIdentifier(line, column);
        }
        return Token(TokenType.dollar, '\$', line, column);
      case '=':
        if (_match('=')) {
          return Token(TokenType.eq, '==', line, column);
        } else if (_match('>')) {
          return Token(TokenType.arrow, '=>', line, column);
        }
        return Token(TokenType.assign, '=', line, column);
      case '!':
        if (_match('=')) {
          return Token(TokenType.neq, '!=', line, column);
        }
        return Token(TokenType.not, '!', line, column);
      case '<':
        if (_match('=')) {
          return Token(TokenType.lte, '<=', line, column);
        }
        return Token(TokenType.lt, '<', line, column);
      case '>':
        if (_match('=')) {
          return Token(TokenType.gte, '>=', line, column);
        }
        return Token(TokenType.gt, '>', line, column);
      case '&':
        if (_match('&')) {
          return Token(TokenType.and, '&&', line, column);
        }
        _error('Unexpected character: $char', line, column);
        return null;
      case '|':
        if (_match('|')) {
          return Token(TokenType.or, '||', line, column);
        }
        _error('Unexpected character: $char', line, column);
        return null;
      case '"':
        return _string(line, column);
      default:
        if (_isDigit(char)) {
          return _number(char, line, column);
        } else if (_isAlpha(char)) {
          return _identifier(char, line, column);
        }
        _error('Unexpected character: $char', line, column);
        return null;
    }
  }

  Token _procIdentifier(int line, int column) {
    final buffer = StringBuffer('\$');
    while (_isAlphaNumeric(_peek())) {
      buffer.write(_advance());
    }
    return Token(TokenType.procIdentifier, buffer.toString(), line, column);
  }

  Token _identifier(String first, int line, int column) {
    final buffer = StringBuffer(first);
    while (_isAlphaNumeric(_peek())) {
      buffer.write(_advance());
    }
    
    final lexeme = buffer.toString();
    final type = _keywords[lexeme] ?? TokenType.identifier;
    
    if (type == TokenType.true_ || type == TokenType.false_) {
      return Token(type, lexeme, line, column, type == TokenType.true_);
    }
    
    return Token(type, lexeme, line, column);
  }

  Token _number(String first, int line, int column) {
    final buffer = StringBuffer(first);
    while (_isDigit(_peek())) {
      buffer.write(_advance());
    }
    
    if (_peek() == '.' && _isDigit(_peekNext())) {
      buffer.write(_advance()); // consume '.'
      while (_isDigit(_peek())) {
        buffer.write(_advance());
      }
      final lexeme = buffer.toString();
      return Token(TokenType.floatLiteral, lexeme, line, column,
          double.parse(lexeme));
    }
    
    final lexeme = buffer.toString();
    return Token(TokenType.integerLiteral, lexeme, line, column,
        int.parse(lexeme));
  }

  Token _string(int line, int column) {
    final buffer = StringBuffer();
    
    while (!_isAtEnd() && _peek() != '"') {
      if (_peek() == '\\') {
        _advance();
        if (!_isAtEnd()) {
          final escaped = _advance();
          switch (escaped) {
            case 'n':
              buffer.write('\n');
              break;
            case 't':
              buffer.write('\t');
              break;
            case 'r':
              buffer.write('\r');
              break;
            case '\\':
              buffer.write('\\');
              break;
            case '"':
              buffer.write('"');
              break;
            default:
              buffer.write(escaped);
          }
        }
      } else {
        buffer.write(_advance());
      }
    }
    
    if (_isAtEnd()) {
      _error('Unterminated string', line, column);
      return Token(TokenType.error, buffer.toString(), line, column);
    }
    
    _advance(); // closing "
    return Token(TokenType.stringLiteral, buffer.toString(), line, column,
        buffer.toString());
  }

  void _skipWhitespaceAndComments() {
    while (!_isAtEnd()) {
      final char = _peek();
      
      switch (char) {
        case ' ':
        case '\t':
        case '\r':
          _advance();
          break;
        case '\n':
          _advance();
          _line++;
          _column = 1;
          break;
        case '/':
          if (_peekNext() == '/') {
            // Line comment
            while (!_isAtEnd() && _peek() != '\n') {
              _advance();
            }
          } else if (_peekNext() == '*') {
            // Block comment
            _advance(); // /
            _advance(); // *
            while (!_isAtEnd()) {
              if (_peek() == '*' && _peekNext() == '/') {
                _advance(); // *
                _advance(); // /
                break;
              }
              if (_peek() == '\n') {
                _line++;
                _column = 0;
              }
              _advance();
            }
          } else {
            return;
          }
          break;
        default:
          return;
      }
    }
  }

  String _advance() {
    if (_isAtEnd()) return '\0';
    _column++;
    return source[_position++];
  }

  String _peek() {
    if (_isAtEnd()) return '\0';
    return source[_position];
  }

  String _peekNext() {
    if (_position + 1 >= source.length) return '\0';
    return source[_position + 1];
  }

  bool _match(String expected) {
    if (_isAtEnd()) return false;
    if (_peek() != expected) return false;
    _advance();
    return true;
  }

  bool _isAtEnd() => _position >= source.length;

  bool _isDigit(String char) => char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

  bool _isAlpha(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122) || // a-z
        code == 95; // _
  }

  bool _isAlphaNumeric(String char) => _isAlpha(char) || _isDigit(char);

  void _error(String message, int line, int column) {
    errors.add('Lexer error at $line:$column: $message');
  }
}

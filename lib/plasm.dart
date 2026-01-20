/// Plasm compiler library
library plasm;

export 'src/compiler.dart';
export 'src/ast/ast.dart';
export 'src/parser/lexer.dart';
export 'src/parser/parser.dart';
export 'src/analysis/name_analysis.dart';
export 'src/analysis/type_analysis.dart';
export 'src/ir/ir.dart';
export 'src/ir/ir_builder.dart';
export 'src/ir/visitor.dart';
export 'src/codegen/wat_generator.dart';

package imperative

import scala.util.parsing.input.Positional

sealed trait Command extends Positional
sealed trait Expression extends Positional
sealed trait BExpression extends Positional
sealed trait Dir extends Positional
sealed trait Type extends Positional

case class Port( nm : String) extends Positional

case class Variable( nm : String) extends Expression
case class VectorIndex( nm : String, i : Expression) extends Expression

case class ConstantInteger( c : Int) extends Expression
case object ConstantTrue extends BExpression

case object Inp extends Dir
case object Out extends Dir

case class Process( lst : PortDeclList, cmd : Command) extends Positional

case class UIntType( width : Int) extends Type
case class VecType( n : Int, t : Type) extends Type

case class Decl( v : Variable, t : Type) extends Positional
case class PortDecl( p : Port, dir : Dir, t : Type) extends Positional
case class PortDeclList( lst : List[PortDecl]) extends Positional
case class Unroll( v : Variable, lb : Expression, ub : Expression, cmd : Command) extends Command
case class Assignment( lhs : Expression, rhs : Expression) extends Command

case class IfThenElse( cond : BExpression, bodyT : Command, bodyF : Command) extends Command
case class Blk( decls : Seq[Decl], seq : Seq[Command]) extends Command
case class AddExpression( l : Expression, r : Expression) extends Expression
case class SubExpression( l : Expression, r : Expression) extends Expression
case class MulExpression( l : Expression, r : Expression) extends Expression
case class EqBExpression( l : Expression, r : Expression) extends BExpression
case class LtBExpression( l : Expression, r : Expression) extends BExpression
case class AndBExpression( l : BExpression, r : BExpression) extends BExpression
case class NotBExpression( e : BExpression) extends BExpression

case class NBCanGet( p : Port) extends BExpression
case class NBCanPut( p : Port) extends BExpression
case class NBGet( p : Port, v : Variable) extends Command
case class NBPut( p : Port, e : Expression) extends Command

// Lowered only

case class ResetWhileTrueWait( decls : Seq[Decl], initSeq : Seq[Command], mainBlk : Command) extends Command

// High level commands

case class While( cond : BExpression, body : Command) extends Command
case class UntilFinallyBody( b : BExpression, fin : Command, body : Command) extends Command
case object Wait extends Command


# set ENV
class Env < Hash
  attr_accessor :outer
  
  def initialize parms=[], args=[], outer=nil
    parms_array = parms.zip args
    # update with the passed parms & args
    self.update Hash[*parms_array.flatten( 1 )]
    @outer = outer
  end
  
  # Find the innermost Env where var appears.
  def find var
    if self.has_key? var
      self
    else
      self.outer.find var unless self.outer.nil?
    end
  end
end

# Add some Scheme standard procedures to an environment.
def add_globals env
  arithmetric_operators = [:+, :-, :*, :/]
  arithmetric_operators.each { |op| env[op.to_s] = lambda { |*args| args.inject { |result, e| result.send(op, e) } } }
  operators = [:>, :<, :>=, :<=]
  operators.each { |op| env[op.to_s] = lambda { |x,y| x.send op, y } }
  env.update( { 'equal?' => lambda { |x,y| x.equal? y},
                '=' => lambda { |x,y| x.equal? y },
                'length' => lambda { |x| x.length },
                'cons' => lambda { |elem, arr| arr.unshift elem },
                'car' => lambda { |arr| arr.first },
                'cdr' => lambda { |arr| arr.drop 1 },
                'append' => lambda { |x, y| x + y },
                'list' => lambda { |*x| Array.new x },
                'list?' => lambda { |x| x.instance_of? Array },
                'null?' => lambda { |x| x == [] },
                'symbol?' => lambda { |x| x.instance_of? String } } )
  env
end

# parse
def tokenize(str)
  str.gsub(/[()]/, ' \0 ').split
end

def read_from(tokens)
  raise SyntaxError, "unexpected EOF while reading" if tokens.length.zero?

  case token = tokens.shift
  when "("
    arr = []
    until tokens.first == ")"
      arr << read_from(tokens)
    end
    # ")"を除去
    tokens.shift
    arr
  # 最初から)の場合
  when ")"
    raise SyntaxError, "unexpected )"
  else
    # 数値型やシンボル型に変換
    atom(token)
  end
end

def atom(token)
  begin
    Integer token
  rescue ArgumentError
    begin
      Float token
    rescue ArgumentError
      String token
    end
  end
end

def read(str)
  read_from(tokenize(str))
end
alias :parse :read

parse("(+ 3 (* 4 5))")
parse("(define plus1 (lambda (n) (+ n 1)))")

# evaluate
def evaluate(x, env)
  if x.instance_of?(String)
    env.find(x)[x]
  elsif x.instance_of?(Array)
    case x.first
    # 特殊型の配列
    when "quote"
      _, expr = x
      expr
    when "if"
      _, test, conseq, alt = x
      evaluate((evaluate(test, env) ? conseq : alt), env)
    when "set!"
      _, var, expr = x
      env[var] = evaluate(expr, env)
    when "define"
      _, var, expr = x
      env[var] = evaluate(expr, env)
    when "lambda"
      _, vars, expr = x
      lambda { |*args| evaluate(expr, Env.new(vars, args, env)) }
    when "begin"
      val = nil
      x[1..-1].each do |expr|
        val = evaluate(expr, env)
      end
      val
    # 特殊型ではない配列
    else
      exprs = x.map { |expr| evaluate expr, env }
      procedure = exprs.shift
      procedure.call(*exprs)
    end
  # 数値型
  else
    x
  end
end

# run
# Convert a Python object back into a Lisp-readable string.    
def to_string expr
  if expr.instance_of? Array
    "(#{expr.map { |exp| to_string exp }.join ' ' })"
  else
    String expr
  end
end

# A prompt read-eval-print loop
def repl prompt='my-lisby> '
  global_env = add_globals Env.new
  while true
    print prompt
    val = evaluate(read(gets.chomp), global_env)
    unless val.nil?
      puts to_string(val)
    end
  end
end

repl


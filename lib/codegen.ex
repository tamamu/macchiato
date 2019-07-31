defmodule Macchiato.Codegen do
  def codegen(expr) do
    case expr do
      [{:Symbol, "defn"}, {:Symbol, name}, arglist | body] -> gen_fn(name, arglist, body, false)
      [{:Symbol, "defn*"}, {:Symbol, name}, arglist | body] -> gen_fn(name, arglist, body, true)
      # [{:Access, target, {:Symbol, attr}} | arglist] -> gen_call(gen_access(target, attr), arglist)
      {:Symbol, "nil"} -> "null"
      {:Symbol, "t"} -> "true"
      {:Symbol, name} -> normalize_name(name, false)
      {:Access, target, {:Symbol, attr}} -> gen_access(target, attr)
      {:String, str} -> gen_string(str)
      [{:Symbol, "let"}, varlist | body] -> gen_let(varlist, body)
      [{:Symbol, "set!"}, target, val] -> gen_assign(target, val)
      [{:Symbol, "lambda"}, arglist | body] -> gen_lambda(arglist, body)
      [{:Symbol, "lambda*"}, arglist | body] -> gen_lambda(arglist, body)
      [{:Symbol, "if"}, condition, then_form] -> gen_if(condition, then_form, nil)
      [{:Symbol, "if"}, condition, then_form, else_form] -> gen_if(condition, then_form, else_form)
      [{:Symbol, "vector"} | exprs] -> gen_vector(exprs)
      [{:Symbol, "list"} | exprs] -> gen_list(exprs)
      #[{:Symbol, "list"} | exprs] -> gen_list(exprs)
      [{:Symbol, "cond"} | body] -> gen_cond(body)
      [{:Symbol, "do"} | body] -> gen_scope(gen_func_body(body))
      [{:Symbol, "range"}, to] -> gen_range(to)
      [{:Symbol, "range"}, from, to] -> gen_range(from, to)
      [{:Symbol, "doseq"}, varlist | body] -> gen_doseq(varlist, body)
      [{:Symbol, "match"}, target | exprs] -> gen_match(exprs, target, true)
      [{:Symbol, "nth"}, target, n] -> gen_nth(target, n)
      [{:Symbol, "max"} | exprs] -> gen_call("Math.max", exprs)
      [{:Symbol, "min"} | exprs] -> gen_call("Math.min", exprs)
      [{:Symbol, "+"} | exprs] -> gen_infix(exprs, "+")
      [{:Symbol, "-"} | exprs] -> gen_infix(exprs, "-")
      [{:Symbol, "*"} | exprs] -> gen_infix(exprs, "*")
      [{:Symbol, "/"} | exprs] -> gen_infix(exprs, "/")
      [{:Symbol, "<"} | exprs] -> gen_true_nil(gen_infix(exprs, "<"))
      [{:Symbol, ">"} | exprs] -> gen_true_nil(gen_infix(exprs, ">"))
      [{:Symbol, "<="} | exprs] -> gen_true_nil(gen_infix(exprs, "<="))
      [{:Symbol, ">="} | exprs] -> gen_true_nil(gen_infix(exprs, ">="))
      [{:Symbol, "/="} | exprs] -> gen_true_nil(gen_infix(exprs, "/="))
      [{:Symbol, "and"} | exprs] -> gen_true_nil(gen_infix(exprs, "&&"))
      [{:Symbol, "or"} | exprs] -> gen_true_nil(gen_infix(exprs, "||"))
      [{:Symbol, "="}, a, b] -> gen_true_nil(gen_infix([a, b], "=="))
      [{:Symbol, "eq"}, a, b] -> gen_true_nil(gen_infix([a, b], "==="))
      [{:Symbol, "zero?"}, expr] -> gen_true_nil(gen_infix([expr, "0"], "=="))
      [{:Symbol, "mod"}, a, b] -> gen_infix([a, b], "%")
      [{:Symbol, "not"}, expr] -> gen_true_nil(gen_prefix(expr, "!"))
      [{:Symbol, "yield"}, expr] -> gen_statement(expr, "yield")
      [{:Symbol, "return"}, expr] -> gen_statement(expr, "return")
      [{:Symbol, "->"} | exprs] -> gen_pipe(exprs)
      {:Keyword, name} -> gen_keyword(name)
      {:Number, number} -> gen_number(number)
      [expr | arglist] -> gen_call(expr, arglist)
      nil -> "null"
      [] -> "null"
      _ -> expr
    end
  end

  def normalize_name(name, head_capitalize) do
    normalize_name(name, "", head_capitalize)
  end

  def normalize_name(name, acc, capitalize) do
    if name == "" do
      acc
    else
      with {head, tail} <- String.split_at(name, 1) do
        if head == "-" do
          normalize_name(tail, acc, true)
        else
          if capitalize do
            normalize_name(tail, acc <> String.upcase(head), false)
          else
            normalize_name(tail, acc <> head, false)
          end
        end
      end
    end
  end

  def gen_func_body(body) do
    gen_func_body(body, [])
  end

  def gen_func_body(body, acc) do
    case body do
      [head] -> Enum.join(Enum.reverse([gen_return(head) | acc]), ";\n")
      [head | tail] ->
        gen_func_body(tail, [codegen(head) | acc])
      [] -> acc
    end
  end

  def gen_body_no_return(body) do
    Enum.join(Enum.map(body, fn expr -> codegen(expr) end), ";\n")
  end

  def gen_return(expr) do
    "return " <> codegen(expr)
  end

  def gen_fn(name, arglist, body, generator) do
    (if generator do "function* " else "function " end) <> normalize_name(name, false) <> "(" <> Enum.join(Enum.map(arglist, fn expr -> codegen(expr) end), ", ") <> ") {\n"
    <> gen_func_body(body) <> ";\n}\n"
  end

  def gen_call(func, arglist) do
    ~s/#{codegen(func)}(#{Enum.join(Enum.map(arglist, fn expr -> codegen(expr) end), ",")})/
  end

  def gen_access(target, attr) do
    codegen(target) <> "." <> normalize_name(attr, false)
  end

  def gen_string(str) do
    "\"" <> str <> "\""
  end

  def gen_assign(target, val) do
    codegen(target) <> "=" <> codegen(val)
  end

  def gen_scope(body) do
    "(() => {\n" <>
      codegen(body) <>
    ";\n})()"
  end

  def gen_let(varlist, body) do
    if rem(length(varlist), 2) == 0 do
      gen_scope(
        Enum.join(Enum.map(Enum.chunk_every(varlist, 2), fn [target, val] -> "let " <> gen_assign(target, val) end), ";\n") <>
          ";\n" <>
            gen_func_body(body))
    else
      {:error, varlist}
    end
  end

  def gen_lambda(arglist, body) do
    "(" <>
      Enum.join(Enum.map(arglist, fn expr -> codegen(expr) end), ", ") <>
    ") => {\n" <>
      gen_func_body(body) <>
    ";\n}"
  end

  def gen_cond(body) do
    gen_cond(Enum.reverse(body), nil)
  end

  def gen_cond(body, acc) do
    case body do
      [] ->
        acc
      [clause, condition | rest] ->
        gen_cond(rest, gen_if(condition, clause, acc))
    end
  end

  def gen_if(condition, then_form, else_form) do
    # gen_scope(
    #   "if (" <> codegen(condition) <> ") {\n" <> gen_statement(then_form, "return") <> ";\n} else {\n" <> gen_statement(else_form, "return") <> "\n;}\n"
    # )
    ~s/(#{codegen(condition)} ? #{codegen(then_form)} : #{codegen(else_form)})/
  end

  def gen_range(to) do
    ~s/(function*(to){if(to>=0){for(let i=0;i<to;i++)yield i;}else{for(let i=0; i>to;i--)yield i;}})(#{codegen(to)})/
  end

  def gen_range(from, to) do
    ~s/(function*(from,to){if(to>=from){for(let i=from;i<to;i++)yield i;}else{for(let i=from; i>to;i--)yield i;}})(#{codegen(from)},#{codegen(to)})/
  end

  def gen_doseq(varlist, body) do
    gen_scope(gen_doseq_inner(varlist, body))
  end

  def gen_doseq_inner(varlist, body) do
    case varlist do
      [name, seq] ->
        ~s/for (const #{codegen(name)} of #{codegen(seq)}) {\n#{gen_body_no_return(body)}\n}/
      [name, seq | rest] ->
        ~s/for (const #{codegen(name)} of #{codegen(seq)}) {\n#{gen_doseq_inner(rest, body)}\n}/
    end
  end

  def gen_infix(exprs, op) do
    "(" <> Enum.join(Enum.map(exprs, fn expr -> codegen(expr) end), op) <> ")"
  end

  def gen_prefix(expr, op) do
    ~s/#{op}(#{codegen(expr)})/
  end

  def gen_statement(expr, word) do
    ~s/#{word} #{codegen(expr)}/
  end

  def gen_vector(exprs) do
    ~s/[#{Enum.join(Enum.map(exprs, fn expr -> codegen(expr) end), ", ")}]/
  end

  def gen_nth(target, n) do
    ~s/#{codegen(target)}[#{codegen(n)}]/
  end

  def gen_pipe(exprs) do
    with [head | tail] <- exprs do
      gen_pipe(tail, head)
    end
  end

  def gen_pipe(exprs, acc) do
    case exprs do
      [{:Keyword, attr} | tail] -> gen_pipe(tail, {:Access, acc, {:Symbol, attr}})
      [head | tail] -> gen_pipe(tail, [head, acc])
      [] -> codegen(acc)
    end
  end

  def gen_binfold(exprs, op) do
    with [head | tail] <- exprs do
      gen_binfold(tail, op, head)
    end
  end

  def gen_binfold(exprs, op, acc) do
    case exprs do
      [head | tail] -> gen_call(op, [acc, gen_binfold(tail, op, head)])
      [] -> acc
    end
  end

  def gen_keyword(name) do
    ~s/"#{name}"/
  end

  def gen_match(exprs, target, bind?) do
    if bind? do
      sym = "_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16 |> binary_part(0, 8))
      gen_scope(Enum.join([gen_statement(gen_assign(sym, target), "const"), gen_match(exprs, sym, false)], ";\n"))
    else case exprs do
      [pattern, then_form | rest] ->
        with [varlist, condition] <- gen_pattern(target, pattern, []) do
          gen_if(case condition do
            [inner] -> inner
            [] -> true
            _ -> condition
          end, gen_let(varlist, [then_form]), gen_match(rest, target, false))
        end
      [] -> nil
    end
    end
  end

  def gen_pattern(target, pattern, varlist) do
    case pattern do
      [_ | _] -> gen_list_pattern(target, pattern, varlist)
      {:Symbol, name} -> [[name, target] ++ varlist, []]
      _ -> [varlist, [gen_infix([target, pattern], "===")]]
    end
  end

  def gen_list_pattern(target, pattern, varlist) do
    case pattern do
      # [head] ->
      #   with [vars, condition] <- gen_pattern(gen_nth(target, 0), head, varlist) do
      #     [vars, [gen_infix([gen_is_list(target)] ++ condition, "&&")]]
      #   end
      [head | tail] -> 
        with [vars1, condition1] <- gen_pattern(gen_nth(target, 0), head, varlist) do
          with [vars2, condition2] <- gen_list_pattern(gen_nth(target, 1), tail, vars1) do
            [vars2, [gen_infix([gen_is_list(target)] ++ condition1 ++ condition2, "&&")]]
          end
        end
      [] -> [varlist, [gen_infix([target, nil], "===")]]
    end
  end

  def gen_is_list(expr) do
    gen_infix([gen_call("Array.isArray", [expr]), gen_infix([({:Access, expr, {:Symbol, "length"}}), 2], "===")], "&&")
  end

  def gen_list(exprs) do
    case exprs do
      [head | tail] -> ~s/[#{codegen(head)}, #{gen_list(tail)}]/
      [] -> "null"
    end
  end

  def gen_number(number) do
    number
  end

  def gen_true_nil(form) do
    ~s/(#{form} ? true : null)/
  end
end

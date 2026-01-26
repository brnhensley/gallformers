# Pattern Matching in Elixir

Pattern matching is pervasive in Elixir. Here are all the places you can use it:

## 1. Variable Assignment

```elixir
# Basic binding
{a, b, c} = {1, 2, 3}

# Destructuring maps
%{name: name, age: age} = %{name: "Alice", age: 30}

# Destructuring lists
[head | tail] = [1, 2, 3, 4]

# Ignoring values
{_, second, _} = {1, 2, 3}
```

## 2. Function Clauses

```elixir
def greet(%{name: name}), do: "Hello, #{name}!"
def greet(_), do: "Hello, stranger!"

# Multiple arities with pattern matching
def sum([]), do: 0
def sum([head | tail]), do: head + sum(tail)
```

## 3. Case Expressions

```elixir
case response do
  {:ok, data} -> process(data)
  {:error, :not_found} -> handle_not_found()
  {:error, reason} -> handle_error(reason)
end
```

## 4. With Expressions

```elixir
with {:ok, user} <- fetch_user(id),
     {:ok, profile} <- fetch_profile(user),
     {:ok, settings} <- fetch_settings(user) do
  {:ok, %{user: user, profile: profile, settings: settings}}
end
```

## 5. Cond (limited)

```elixir
# Cond uses truthiness, not pattern matching
# But you can combine with pattern matching via assignment
cond do
  match?({:ok, _}, result) -> handle_success()
  match?({:error, _}, result) -> handle_error()
  true -> handle_default()
end
```

## 6. Receive (for processes)

```elixir
receive do
  {:message, content} -> IO.puts(content)
  {:stop, reason} -> exit(reason)
after
  5000 -> IO.puts("Timeout")
end
```

## 7. Try/Rescue/Catch

```elixir
try do
  risky_operation()
rescue
  %ArgumentError{message: msg} -> handle_arg_error(msg)
  %RuntimeError{} -> handle_runtime_error()
catch
  :exit, reason -> handle_exit(reason)
  :throw, value -> handle_throw(value)
end
```

## 8. Anonymous Functions

```elixir
handler = fn
  {:ok, data} -> {:processed, data}
  {:error, _} -> :failed
end
```

## 9. Comprehensions

```elixir
# Filter with pattern matching
for {:ok, value} <- results, do: value

# Multiple generators with patterns
for {key, value} <- map, value > 10, do: {key, value * 2}
```

## 10. Guards (extending patterns)

```elixir
def process(x) when is_integer(x) and x > 0, do: :positive
def process(x) when is_integer(x) and x < 0, do: :negative
def process(0), do: :zero
def process(x) when is_binary(x), do: :string
```

## Special Operators

| Operator | Purpose |
|----------|---------|
| `^` (pin) | Match against existing variable's value |
| `_` | Ignore/wildcard |
| `..` | Range matching (limited) |
| `<>` | Binary/string matching |

```elixir
# Pin operator - match against existing value
expected = 42
{^expected, other} = {42, "hello"}  # Works
{^expected, other} = {99, "hello"}  # MatchError

# String matching
"Hello, " <> name = "Hello, World"  # name = "World"

# Binary matching
<<a::8, b::8, rest::binary>> = <<1, 2, 3, 4, 5>>
```

## The `match?/2` Macro

For boolean checks without binding:

```elixir
if match?({:ok, _}, result) do
  # ...
end

Enum.filter(results, &match?({:ok, _}, &1))
```

# A Philosophical Treatise on the Proper Use of Elixir

## I. The Three Pillars: Erlang's Soul, Ruby's Face, Clojure's Mind

José Valim built Elixir on three philosophical foundations:

1. **Erlang's infrastructure** - fault tolerance, distribution, concurrency
2. **Ruby's developer experience** - readable syntax, metaprogramming, joy
3. **Clojure's data philosophy** - immutability, data transformation, simplicity

Good Elixir code honors all three. It runs reliably under load (Erlang), reads clearly (Ruby), and transforms data through pure functions (Clojure).

---

## II. The Separation of Concerns: Behavior, State, and Mutability

In his [ElixirConf EU 2024 keynote "Gang of None?"](https://elixirforum.com/t/keynote-gang-of-none-design-patterns-in-elixir-jose-valim-elixirconf-eu-2024/63550), José Valim articulated a fundamental principle:

> **Elixir decouples behavior, state, and mutability.**

In OOP, these are fused into objects. In Elixir:
- **Behavior** lives in modules (pure functions)
- **State** lives in processes (GenServers, Agents)
- **Mutability** is explicit and isolated (message passing)

This separation is not incidental—it's the core insight. When you find yourself creating "objects" in Elixir, you're fighting the language.

---

## III. The Core and The Interface

Saša Jurić, author of *[Elixir in Action](https://www.manning.com/books/elixir-in-action)*, advocates for a clear architectural division in his [Thinking Elixir podcast appearance](https://podcast.thinkingelixir.com/38) and writings:

**The Core:**
- Pure business logic
- No side effects
- Easily testable
- Phoenix contexts belong here

**The Interface:**
- Web layer (controllers, LiveViews)
- External API calls
- Database interactions
- Side effects live here

```
┌─────────────────────────────────────┐
│           Interface Layer           │
│  (LiveView, Controllers, External)  │
├─────────────────────────────────────┤
│             Core Layer              │
│    (Contexts, Business Logic)       │
│         Pure Functions Only         │
└─────────────────────────────────────┘
```

Jurić notes this requires "a bit more lines of code, but in return provides better clarity and focus. The code becomes easier to work with, helping teams keep a long-term sustainable pace."

---

## IV. Let It Crash: The Counter-Intuitive Wisdom

The Erlang philosophy inherited by Elixir inverts defensive programming:

**Traditional thinking:** Handle every possible error condition.

**Elixir thinking:** Let processes crash. Supervisors restart them.

This isn't negligence—it's liberation. Instead of:

```elixir
# Defensive (anti-pattern in Elixir)
def process(data) do
  case validate(data) do
    {:ok, valid} ->
      case transform(valid) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end
    {:error, reason} -> {:error, reason}
  end
end
```

Write:

```elixir
# Assertive (idiomatic Elixir)
def process(data) do
  data
  |> validate!()
  |> transform!()
end
```

If `validate!` or `transform!` fail on truly unexpected input, the process crashes, the supervisor restarts it, and the system continues. Reserve `{:ok, _} | {:error, _}` tuples for *expected* error conditions that callers should handle.

---

## V. The Pipe as Philosophy

The pipe operator `|>` is not merely syntax sugar. It embodies a worldview:

> **Data flows through transformations.**

Good Elixir reads top-to-bottom, left-to-right, like prose:

```elixir
order
|> calculate_subtotal()
|> apply_discounts(promotions)
|> add_tax(jurisdiction)
|> finalize()
```

Each function receives data, transforms it, passes it forward. No hidden state. No side effects buried in method chains. The [community style guide](https://github.com/christopheradams/elixir_style_guide) emphasizes this pattern as central to readable code.

---

## VI. Pattern Matching as Truth-Telling

Pattern matching forces you to be explicit about what you expect:

```elixir
# Non-assertive (anti-pattern per official docs)
def handle_response(response) do
  status = response[:status]
  if status == :ok do
    response[:data]
  else
    nil
  end
end

# Assertive (idiomatic)
def handle_response(%{status: :ok, data: data}), do: data
def handle_response(%{status: :error, reason: reason}), do: raise "Failed: #{reason}"
```

The [official Elixir anti-patterns documentation](https://hexdocs.pm/elixir/main/code-anti-patterns.html) calls this "Non-Assertive Pattern Matching"—defensive code that silently returns incorrect values instead of failing on unexpected input.

---

## VII. The Ten Anti-Patterns

The official documentation identifies key mistakes:

| Anti-Pattern | The Problem | The Solution |
|--------------|-------------|--------------|
| **Comments overuse** | Explaining obvious code | Use clear names instead |
| **Complex `else` in `with`** | Unclear error origins | Normalize errors in private functions |
| **Dynamic atom creation** | Memory leaks (atoms aren't GC'd) | Use `String.to_existing_atom/1` |
| **Long parameter lists** | Confusion, errors | Group into maps/structs |
| **Namespace trespassing** | Module conflicts | Prefix with your package name |
| **Non-assertive map access** | `nil` propagation | Use `map.key` for required fields |
| **Non-assertive truthiness** | Overly generic logic | Use `and/or/not` for booleans |
| **Structs with 32+ fields** | Performance degradation | Nest or group fields |

---

## VIII. Processes Are Not Objects

A common mistake from OOP refugees: treating GenServers as objects.

**Objects** encapsulate state and behavior together.
**Processes** are independent execution units with message queues.

Use a process when you need:
- **Concurrency** - work happening in parallel
- **State isolation** - state that must survive beyond a request
- **Fault isolation** - failures that shouldn't cascade

Do *not* use a process for:
- Namespacing functions (use modules)
- Grouping related data (use structs)
- Code organization (use contexts)

As the [Elixir Wiki on Functional Design Patterns](https://www.elixirwiki.com/wiki/Functional_Design_Patterns_in_Elixir) notes: "Pure functions always return the same output for the same input without side effects. This makes code predictable and testable."

---

## IX. The Shape of Good Elixir

```elixir
defmodule MyApp.Orders do
  @moduledoc """
  The Orders context - handles order lifecycle.
  """

  alias MyApp.Orders.Order
  alias MyApp.Repo

  # Public API - clear, minimal, focused
  def create_order(attrs) do
    %Order{}
    |> Order.changeset(attrs)
    |> Repo.insert()
  end

  def calculate_total(%Order{} = order) do
    order.line_items
    |> Enum.map(& &1.price * &1.quantity)
    |> Enum.sum()
    |> apply_discount(order.discount_code)
  end

  # Private - implementation details
  defp apply_discount(total, nil), do: total
  defp apply_discount(total, code) do
    # ...
  end
end
```

Notice:
- Clear module purpose in `@moduledoc`
- Pattern matching on structs (assertive)
- Pipes for data transformation
- Private functions for implementation
- No GenServer unless actually needed

---

## X. Summary: The Elixir Way

1. **Separate behavior from state from mutability**
2. **Build a pure core, push side effects to the edges**
3. **Let processes crash; supervisors handle recovery**
4. **Use pipes to show data flow**
5. **Pattern match assertively—crash on unexpected input**
6. **Avoid dynamic atoms, long parameter lists, overloaded structs**
7. **Processes are for concurrency and isolation, not organization**
8. **Contexts are your API boundaries**

As José Valim demonstrated in his 2024 keynote, many Gang of Four patterns "inherently align with Elixir's core principles"—but they manifest differently. Mediator becomes PubSub. Strategy becomes higher-order functions. Singleton becomes Application configuration.

The language guides you toward correctness if you listen.

---

## Sources

- [José Valim's ElixirConf EU 2024 Keynote: "Gang of None?"](https://elixirforum.com/t/keynote-gang-of-none-design-patterns-in-elixir-jose-valim-elixirconf-eu-2024/63550)
- [Official Elixir Anti-Patterns Documentation](https://hexdocs.pm/elixir/main/code-anti-patterns.html)
- [Thinking Elixir Podcast #38: Maintainable Elixir with Saša Jurić](https://podcast.thinkingelixir.com/38)
- [Saša Jurić - Elixir in Action (Manning)](https://www.manning.com/books/elixir-in-action)
- [Community Style Guide](https://github.com/christopheradams/elixir_style_guide)
- [Credo Style Guide](https://github.com/rrrene/elixir-style-guide)
- [Functional Design Patterns in Elixir](https://www.elixirwiki.com/wiki/Functional_Design_Patterns_in_Elixir)
- [Curiosum: Elixir Anti-Patterns](https://www.curiosum.com/blog/elixir-anti-patterns)

---
name: elixir-anti-patterns
description: Reviews Elixir code for anti-patterns and code smells. Use when reviewing PRs, auditing codebases, refactoring Elixir code, or when asked to find code smells, anti-patterns, or improve Elixir code quality.
---

# Elixir Anti-Pattern Reviewer

You are an expert Elixir code reviewer specializing in identifying anti-patterns and code smells. When reviewing code, systematically check for the anti-patterns below, explain why each is problematic, and provide concrete refactoring suggestions.

## Review Process

1. **Scan the code** for each anti-pattern category
2. **Identify matches** with specific line numbers or code snippets
3. **Explain the problem** in context of the specific code
4. **Provide refactored code** that addresses the issue
5. **Note exceptions** where the pattern may be acceptable

## Output Format

For each finding, use this structure:

```
### [Anti-Pattern Name]
**Location:** `module_name.ex:line_number` or code snippet
**Problem:** Why this is problematic in this specific context
**Refactoring:**
```elixir
# Before
<problematic code>

# After  
<refactored code>
```
**Note:** Any exceptions or context where this might be acceptable
```

---

# ANTI-PATTERN CATALOG

## Code-Related Anti-Patterns

### 1. Comments Overuse
**Detect:** Comments explaining self-explanatory code, comments restating what code does
**Problem:** Reduces readability, comments can become stale
**Refactor:** Use clear function/variable names, extract magic numbers to module attributes
```elixir
# BAD
# Add five minutes in seconds
unix_now + (60 * 5)

# GOOD
@five_min_in_seconds 60 * 5
unix_now + @five_min_in_seconds
```

### 2. Complex `else` Clauses in `with`
**Detect:** `with` expressions with multiple patterns in `else` block
**Problem:** Unclear which clause produced which error
**Refactor:** Normalize errors in private wrapper functions
```elixir
# BAD
with {:ok, encoded} <- File.read(path),
     {:ok, decoded} <- Base.decode64(encoded) do
  {:ok, decoded}
else
  {:error, _} -> {:error, :badfile}
  :error -> {:error, :badencoding}
end

# GOOD
with {:ok, encoded} <- file_read(path),
     {:ok, decoded} <- base_decode64(encoded) do
  {:ok, decoded}
end

defp file_read(path) do
  case File.read(path) do
    {:ok, contents} -> {:ok, contents}
    {:error, _} -> {:error, :badfile}
  end
end
```

### 3. Complex Extractions in Clauses
**Detect:** Multi-clause functions extracting many fields in function heads
**Problem:** Hard to distinguish pattern-matching fields from body-usage fields
**Refactor:** Extract only guard-related variables in signature, bind rest in body
```elixir
# BAD
def drive(%User{name: name, age: age}) when age >= 18 do
  "#{name} can drive"
end

# GOOD
def drive(%User{age: age} = user) when age >= 18 do
  %User{name: name} = user
  "#{name} can drive"
end
```

### 4. Dynamic Atom Creation
**Detect:** `String.to_atom/1` with external/untrusted input
**Problem:** Atoms aren't garbage collected; can exhaust atom table (1,048,576 limit)
**Refactor:** Use explicit mapping or `String.to_existing_atom/1`
```elixir
# BAD
def parse(%{"status" => status}) do
  %{status: String.to_atom(status)}
end

# GOOD
def parse(%{"status" => status}) do
  %{status: convert_status(status)}
end

defp convert_status("ok"), do: :ok
defp convert_status("error"), do: :error
defp convert_status("redirect"), do: :redirect
```

### 5. Long Parameter List
**Detect:** Functions with 4+ unrelated parameters
**Problem:** Confusing interface, error-prone calls
**Refactor:** Group related params into maps/structs/keyword lists
```elixir
# BAD
def loan(user_name, email, password, user_alias, book_title, book_ed)

# GOOD
def loan(%{name: _, email: _, password: _, alias: _} = user, %{title: _, ed: _} = book)
```

### 6. Namespace Trespassing
**Detect:** Library modules defined outside their namespace (e.g., `Plug.Auth` in `:plug_auth`)
**Problem:** Module name conflicts when Erlang VM loads modules
**Refactor:** Use library name as prefix (`PlugAuth` not `Plug.Auth`)

### 7. Non-Assertive Map Access
**Detect:** `map[:key]` for keys that should always exist
**Problem:** Returns `nil` instead of failing fast; hides bugs
**Refactor:** Use `map.key` for required keys, `map[:key]` for optional
```elixir
# BAD - x and y are required
{point[:x], point[:y], point[:z]}

# GOOD
{point.x, point.y, point[:z]}
```

### 8. Non-Assertive Pattern Matching
**Detect:** Code using `Enum.at/2`, list indexing, or loose matching instead of pattern matching
**Problem:** Returns incorrect values instead of crashing on invalid input
**Refactor:** Use pattern matching to assert expected structure
```elixir
# BAD
key_value = String.split(pair, "=")
Enum.at(key_value, 0) == desired_key && Enum.at(key_value, 1)

# GOOD
[key, value] = String.split(pair, "=")
key == desired_key && value
```

### 9. Non-Assertive Truthiness
**Detect:** `&&`, `||`, `!` with boolean operands
**Problem:** More generic than necessary; can mask Erlang `:undefined`/`:error` values
**Refactor:** Use `and`, `or`, `not` for boolean operations
```elixir
# BAD
if is_binary(name) && is_integer(age) do

# GOOD
if is_binary(name) and is_integer(age) do
```

### 10. Structs with 32+ Fields
**Detect:** Structs with 32 or more fields
**Problem:** Switches from flat map to hash map; loses memory optimizations
**Refactor:** Nest optional fields, group related fields into sub-structs

---

## Design-Related Anti-Patterns

### 11. Alternative Return Types
**Detect:** Functions where options change return type
**Problem:** Hard to understand what function returns
**Refactor:** Create separate functions for each return type
```elixir
# BAD
def parse(string, discard_rest: true)  # returns integer()
def parse(string, discard_rest: false) # returns {integer(), String.t()}

# GOOD
def parse(string)              # returns {integer(), String.t()}
def parse_discard_rest(string) # returns integer()
```

### 12. Boolean Obsession
**Detect:** Multiple boolean options with overlapping states
**Problem:** Unclear precedence, related options scattered
**Refactor:** Use atoms/enums for related states
```elixir
# BAD
def process(invoice, editor: true, admin: true)

# GOOD
def process(invoice, role: :admin)  # :admin | :editor | :default
```

### 13. Exceptions for Control-Flow
**Detect:** `try/rescue` for expected error cases
**Problem:** Exceptions should be exceptional; obscures normal flow
**Refactor:** Use `{:ok, _}`/`{:error, _}` tuples and pattern matching
```elixir
# BAD
try do
  IO.puts(File.read!(file))
rescue
  e -> IO.puts(:stderr, Exception.message(e))
end

# GOOD
case File.read(file) do
  {:ok, binary} -> IO.puts(binary)
  {:error, reason} -> IO.puts(:stderr, "could not read: #{reason}")
end
```

### 14. Primitive Obsession
**Detect:** Strings/integers carrying structured data (addresses, money, etc.)
**Problem:** Repeated parsing/manipulation logic, unclear domain model
**Refactor:** Create structs/maps for domain concepts
```elixir
# BAD
def extract_postal_code(address) when is_binary(address)

# GOOD
defmodule Address do
  defstruct [:street, :city, :state, :postal_code, :country]
end
def extract_postal_code(%Address{postal_code: code}), do: code
```

### 15. Unrelated Multi-Clause Function
**Detect:** Multi-clause functions with completely different behavior per clause
**Problem:** Confusing API, documentation full of conditionals
**Refactor:** Split into separate named functions
```elixir
# BAD
def update(%Product{}), do: # product logic
def update(%Animal{}), do: # completely different animal logic

# GOOD
def update_product(%Product{}), do: ...
def update_animal(%Animal{}), do: ...
```

### 16. Application Configuration for Libraries
**Detect:** Libraries using `Application.get_env/fetch_env!` for configuration
**Problem:** Global state prevents different configs per dependent app
**Refactor:** Accept configuration as function parameters or child_spec options

---

## Process-Related Anti-Patterns

### 17. Code Organization by Process
**Detect:** GenServer/Agent used for pure computation without state/concurrency needs
**Problem:** Creates bottlenecks, unnecessary complexity
**Refactor:** Use plain modules and functions
```elixir
# BAD - GenServer for stateless math
defmodule Calculator do
  use GenServer
  def add(a, b, pid), do: GenServer.call(pid, {:add, a, b})
end

# GOOD
defmodule Calculator do
  def add(a, b), do: a + b
end
```

### 18. Scattered Process Interfaces
**Detect:** Direct `Agent.update/get`, `GenServer.call/cast` spread across modules
**Problem:** Duplicated code, inconsistent data formats, hard to maintain
**Refactor:** Centralize process interaction in one module
```elixir
# BAD - scattered across modules
Agent.update(process, fn _ -> 123 end)  # in module A
Agent.update(process, fn c -> %{a: c} end)  # in module B

# GOOD - centralized
defmodule Foo.Bucket do
  def put(bucket, key, value), do: Agent.update(bucket, &Map.put(&1, key, value))
  def get(bucket, key), do: Agent.get(bucket, &Map.get(&1, key))
end
```

### 19. Sending Unnecessary Data
**Detect:** Passing large structs to `spawn/1`, `Task.async/1`, `GenServer.call/2`
**Problem:** Full data copied to new process; expensive for large structs
**Refactor:** Extract only needed fields before spawning
```elixir
# BAD - copies entire conn
spawn(fn -> log_request_ip(conn) end)

# GOOD - copies only IP
ip_address = conn.remote_ip
spawn(fn -> log_request_ip(ip_address) end)
```

### 20. Unsupervised Processes
**Detect:** Long-running processes started outside supervision trees
**Problem:** Hard to monitor, no lifecycle control, no restart strategy
**Refactor:** Add processes to supervision tree

---

## Meta-Programming Anti-Patterns

### 21. Compile-Time Dependencies
**Detect:** Macros that create compile-time deps on runtime-only modules
**Problem:** Changing one file triggers large recompilation cascades
**Refactor:** Use `Macro.expand_literals/2` with function context
```elixir
# BAD
defmacro plug(mod) do
  quote do
    @plugs unquote(mod)  # mod becomes compile-time dependency
  end
end

# GOOD
defmacro plug(mod) do
  mod = Macro.expand_literals(mod, %{__CALLER__ | function: {:call, 2}})
  quote do
    @plugs unquote(mod)
  end
end
```

### 22. Large Code Generation
**Detect:** Macros with large `quote` blocks
**Problem:** Code expanded/compiled on every macro invocation
**Refactor:** Delegate to functions, keep `quote` minimal
```elixir
# BAD
defmacro get(route, handler) do
  quote do
    # 20 lines of validation and logic
  end
end

# GOOD
defmacro get(route, handler) do
  quote do
    Routes.__define__(__MODULE__, unquote(route), unquote(handler))
  end
end
```

### 23. Unnecessary Macros
**Detect:** Macros that could be plain functions
**Problem:** Harder to understand, debug, and maintain
**Refactor:** Use functions unless compile-time transformation is required

### 24. `use` Directive Overuse
**Detect:** `use` that imports many modules or propagates dependencies
**Problem:** Hidden dependencies, potential name conflicts
**Refactor:** Prefer `import`/`alias` with explicit `:only`

---

## Review Checklist

When reviewing Elixir code, check for:

- [ ] Dynamic atom creation from external input
- [ ] `map[:key]` for required keys
- [ ] `try/rescue` for expected errors
- [ ] GenServers without state/concurrency needs
- [ ] Large structs passed to spawned processes
- [ ] Unsupervised long-running processes
- [ ] Complex `with` else blocks
- [ ] Boolean options with overlapping states
- [ ] Functions with 4+ parameters
- [ ] Multi-clause functions with unrelated behavior
- [ ] Library code using Application config
- [ ] Macros that could be functions
- [ ] `&&`/`||` with boolean operands

## Important Notes

- **Not all matches require changes**: Anti-patterns are indicators, not absolute rules
- **Context matters**: Some patterns are acceptable in specific situations
- **Prioritize impact**: Focus on patterns causing real maintenance/performance issues
- **Suggest, don't mandate**: Explain trade-offs and let developers decide

## References

- https://hexdocs.pm/elixir/what-anti-patterns.html
- https://hexdocs.pm/elixir/code-anti-patterns.html
- https://hexdocs.pm/elixir/design-anti-patterns.html
- https://hexdocs.pm/elixir/process-anti-patterns.html
- https://hexdocs.pm/elixir/macro-anti-patterns.html
- https://github.com/lucasvegi/Elixir-Code-Smells

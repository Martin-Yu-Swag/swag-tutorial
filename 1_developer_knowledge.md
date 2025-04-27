# W1 - W2

## [How to ask the right questions ?](https://jvns.ca/blog/good-questions/)

- State what you know
- Ask questions where the answer is a fact
- Be willing to say what you don't understand
- Identify terms you don't understand
- Do some research
- Decide who to ask
- Ask questions to show what's not obvious

## Organizational Structure

# W3 - W4

### Development flow

### Efficient debugging

- Errors
- Performance issues

# W5 - W6

## What is Good Code?

- [Common “bad code smells”](https://refactoring.guru/refactoring/smells)

### Bloaters

- code, methods, classes that have increased to such gargantuan properties.
- accumulate over time as the program evolves.

#### [Long Method](https://refactoring.guru/smells/long-method)

- Signs and Symptoms:
  method contains too many lines of code (generally > 10 lines)

- Treatment
  - Rule of thumb:
    if feel the need to comment on sth inside method
    -> should take this code out and put it in a new method.

  - [Extract Method](https://refactoring.guru/extract-method)

  - Handling local vars or params:
    - [Replace Temp with Query](https://refactoring.guru/replace-temp-with-query)
      using query (method) result rather than storing result as local var.
    - [Introduce Parameter Object](https://refactoring.guru/introduce-parameter-object)
      consolidating parameters in a single class.
    - [Preserve Whole Object](https://refactoring.guru/preserve-whole-object)

  - [Replace Method with Method Object](https://refactoring.guru/replace-method-with-method-object)
    transform the method into a separate class so that the local variables become fields of the class.
    (but added class increase the overall complexity)

  - [Decompose Conditional](https://refactoring.guru/decompose-conditional)
    Decompose the complicated parts of the conditional into separate methods

#### [Large Class](https://refactoring.guru/smells/large-class)

- Signs and Symptoms:
  A class contains many fields/methods/lines of code.

- Treatment:
  - [Extract Class](https://refactoring.guru/extract-class)

  - [Extract Subclass](https://refactoring.guru/extract-subclass)
    - compose instead of inherit
      (compose obj)

  - [Extract Interface](https://refactoring.guru/extract-interface)

  - [Duplicate Observed Data](https://refactoring.guru/duplicate-observed-data)

#### [Primitive Obsession](https://refactoring.guru/smells/primitive-obsession)

- Signs and Symptoms
  - Use of primitives instead of small objects for simple tasks
    (eg. currency, ranges, phone numbers)

  - Use of constants for coding information

  - Use of string constants as field names for use in data arrays.

- Treatment

  - [Replace Data Value with Object](https://refactoring.guru/replace-data-value-with-object)

  - If the values of primitive fields are used in params:
    - Introduce Parameter Object
    - Preserver Whole Object

  - Handling complicated data in vars:
    - [Replace Type Code with Class](https://refactoring.guru/replace-type-code-with-class)
    - [Replace Type Code with Subclasses](https://refactoring.guru/replace-type-code-with-subclasses)
    - [Replace Type Code with State/Strategy](https://refactoring.guru/replace-type-code-with-state-strategy)

  - [Replace Array with Object](https://refactoring.guru/replace-array-with-object)

#### [Long Parameter List](https://refactoring.guru/smells/long-parameter-list)

- Signs and Symptoms
  More than 3 or 4 params for a method

- Treatment

  - If some of the arguments are just results of method calls of another object,
    use [Replace Parameter with Method Call](https://refactoring.guru/replace-parameter-with-method-call).

  - pass the object itself to the method, by using Preserve Whole Object

  - Introduce Parameter Object

- When to Ignore?
  if doing so would cause unwanted dependency between classes.

#### Data Clumps

- Signs and Symptoms

> Sometimes different parts of the code contain identical groups of variables
> (such as parameters for connecting to a database)

- Treatment

  - Extract Class
  - Introduce Parameter Object
  - Preserve Whole Object

---

### [Object-Orientation Abusers](https://refactoring.guru/refactoring/smells/oo-abusers)

> All these smells are incomplete or incorrect application of object-oriented programming principles:

#### [Switch Statements](https://refactoring.guru/smells/switch-statements)

> complex `switch` operator or sequence of `if` statements.
> Rule of thumb: think of `polymorphism` when encounter `switch`!

- **Treatment**
  - Use `Extract Method` then `Move Method` to isolate switch
  
  - Replace Type Code with Subclass | Replace Type Code with State/Strategy

  - [`Replace Conditional with Polymorphism`](https://refactoring.guru/replace-conditional-with-polymorphism)

  - If there aren't too many conditions in the operator:
    [`Replace Parameter with Explicit Methods`](https://refactoring.guru/replace-parameter-with-explicit-methods)
  
  - If one of the conditional options is null, use [`Introduce Null Object`](https://refactoring.guru/introduce-null-object)
    to provide a default behavior for null condition.

#### [Temporary Field](https://refactoring.guru/smells/temporary-field)

- **Signs and Symptoms**
  > Temporary fields get their values (and thus are needed by objects) only under certain circumstances. Outside of these circumstances, they’re empty.
  eg. instead of put a long list of params in method, coder store them directly as obj fields, yet there're seldom used (so often empty).

- **Treatment**
  - Put temp fields and code operating on them in a separate class (`Extract Class`),
    then `Replace Method with Method Object`

  - `Introduce Null Object`

#### [Refused Bequest](https://refactoring.guru/smells/refused-bequest)

- **Signs and Symptoms**
  > If a subclass uses only some of the methods and properties inherited from its parents, the hierarchy is "off-kilter".

- **Treatment**
  - Eliminate inheritance in favor of [`Replace Inheritance with Delegation`](https://refactoring.guru/replace-inheritance-with-delegation)

  - `Extract Superclass`

#### [Alternative Classes with Different Interface](https://refactoring.guru/smells/alternative-classes-with-different-interfaces)

- **Signs and Symptoms**
  > Two classes perform identical functions but have different method names.

- **Treatment**
  - [`Rename Methods`](https://refactoring.guru/rename-method)

  - `Move Method`, `Add Parameter` and `Parameterize Method` to make the signature and implementation of methods the same.

  - `Extract Superclass` if part of functionality of the classes is duplicated

### [Change Preventers](https://refactoring.guru/refactoring/smells/change-preventers)

#### Divergent Change

**Signs and Symptoms**

> having to change many unrelated methods when you make changes to "a single class".

**Treatment**

- Split up the behavior of the class via `Extract Class`
- `Extract Superclass` / `Extract Subclass` for shared behavior

#### Shotgun Surgery

**Signs and Symptoms**

> Making any modifications requires that you make many small changes to "many different classes".

-> Not obeying Single Responsibility Principle.

**Treatment**

- `Move Method` / `Move Field`
- `Inline Class`

#### Parallel Inheritance Hierarchy

**Signs and Symptoms**

> Whenever you create a subclass for a class,
> you find yourself needing to create a subclass for another class.


**Treatment**

- `Move Method` / `Move Field`.

### [Dispensables](https://refactoring.guru/refactoring/smells/dispensables)

> A dispensable is something pointless and unneeded whose absence would make the code cleaner, more efficient and easier to understand.

#### Comments

**Signs and Symptoms**

- method filled with explanatory comments
- The BEST comment is a good name for a method or class.

**Treatment**

- expression not understandable -> `Extract Variable`
- parse section to separate method -> `Extract Method`
- `Rename Method` for self-explanatory components
- `Introduce Assertion` to guarantee system integrity
  (assertions can act as live documentation for code)

#### [Duplicate Code](https://refactoring.guru/smells/duplicate-code)

**Signs and Symptoms**

> Two code fragments look almost identical.

**Treatment**

- `Extract Method`
- `Form Template Method`, `Substitute Algorithm`
- Duplicate code in different class: `Extract SuperClass` / `Extract Class`
- `Consolidate Conditional Expression`
- `Consolidate Duplicate Conditional Fragments`

#### [Lazy Class](https://refactoring.guru/smells/lazy-class)

**Signs and Symptoms**

> So if a class doesn’t do enough to earn your attention, it should be deleted.

**Treatment**

- `Inline Class`
- `Collapse Hierarchy`

#### [Data Class](https://refactoring.guru/smells/data-class)

**Signs and Symptoms**

> A data class refers to a class that contains only fields and getter/setter.
> simply containers for data used by other classes.

**Treatment**

- `Encapsulate Field` / `Encapsulate Collection`
- `Move Method` / `Extract Method`
- `Remove Setting Method` / `Hide Method`

#### [Dead Code](https://refactoring.guru/smells/dead-code)

**Signs and Symptoms**

> A variable, parameter, field, method or class is no longer used.

**Treatment**

- Use `IDE` to detect dead code
- `Inline Class` / `Collapse Hierarchy`
- `Remove Parameter`

#### [Speculative Generality](https://refactoring.guru/smells/speculative-generality)

**Signs and Symptoms**

> There’s an unused class, method, field or parameter (over-design).

**Treatment**

- `Collapse Hierarchy`
- `Inline Class`
- `Inline Method`
- `Remove Parameter`

### [Couplers](https://refactoring.guru/refactoring/smells/couplers)

> All the smells in this group contribute to excessive coupling between classes or show what happens if coupling is replaced by excessive delegation.

#### [Feature Envy](https://refactoring.guru/smells/feature-envy)

**Signs and Symptoms**

> A method accesses the data of another object more than its own data.

-> not coherent!

**Treatment**

- `Move Method`
- `Extract Method`

#### [Inappropriate Intimacy](https://refactoring.guru/smells/inappropriate-intimacy)

**Signs and Symptoms**

> One class uses the internal fields and methods of another class.

**Treatment**

- `Move Method` / `Move Field`
- `Extract Class` / `Hide Delegate`
- `Change Bidirectional Association to Unidirectional`
- `Replace Delegation with Inheritance`

#### [Message Chains](https://refactoring.guru/smells/message-chains)

**Signs and Symptoms**

> In code you see a series of calls resembling $a->b()->c()->d()

**Treatment**

- `Hide Delegate`
- `Extract Method` / `Move Method`

#### [Middle Man](https://refactoring.guru/smells/middle-man)

**Signs and Symptoms**

> If a class performs only one action, delegating work to another class.
> Can be the result of overzealous elimination of Message Chains.

**Treatment**

- `Remove Middle Man`

### Other Smells

#### [Incomplete Library Class](https://refactoring.guru/smells/incomplete-library-class)

**Treatment**

- `Introduce Foreign Method`
- `Introduce Local Extension`

---

# W7-W8

## How to create good PRs ?

### [How to write the perfect pull request](https://github.blog/2015-01-21-how-to-write-the-perfect-pull-request/)

NOTE: clarity, explicitness.

### [In Praise of Stacked PRs](https://benjamincongdon.me/blog/2022/07/17/In-Praise-of-Stacked-PRs/)

- Stacked PR: breaking up a large change int smaller, individually reviewable PRs.

- Benefits:
  - Easier & quicker to review / Easier to rollback
  - Stacking PRs keeps the author unblocked
  - Allow to easily managed dependent changes

## How to conduct good PR reviews ?

### [How to Do Code Reviews Like a Human](https://mtlynch.io/human-code-reviews-1/)

- The author must create a **changelist**: a set of changes to source code

Techniques:

#### Let Computers do the boring parts

- Use automated formatting tool
- tools:
  - pre-commit hooks in Git
  - webhooks in Github

#### Settle style arguments with a style guide

- Don't waste time arguing styling issue.
  Just defer to the style guide and move on

- Adopt an existing style guide / Create your own style guide incrementally

#### Start reviewing immediately

Blocked PRs are prone to growing into larger PR.

#### Start high level and work your way down

> Focus on issues like redesigning a class interface or splitting up complex functions.
> Wait until those issues are resolved before tackling lower-level issues, such as variable naming or clarity of code comments

-> 處理 High-level issues 優先，再慢慢處理 trivial issues (naming, styling).

#### Be generous with code examples

#### Never say “you”

> Word your feedback in a way that minimizes the risk of raising your teammate’s defenses

> Critique the code, not the coder.

- Options 1: Replace 'you' with 'we'
  -> “We” reinforces the team’s collective responsibility for the code

- Option 2: Remove the subject from the sentence OR use passive voice
  (Or may be starting the sentence with 'What about')

#### Frame feedback as requests, not commands

> If you frame your feedback as a command, any push-back from the author comes across as disobedience.

#### Tie notes to principles, not opinions

- eg. SRP (single responsibility principle)

> Grounding your notes in principles frames the discussion in a constructive way

---

(PART 2)

> Takeaway: a good code reviewer not only finds bugs,
  but provides conscientious feedback to help their teammates improve.

#### Aim to bring the code up a letter grade or two

- Don't push the PRs from grade D to grade-extreme-perfect, this frustrate the author.

#### Limit feedback on repeated patterns

#### Respect the scope of the review

> The rule of thumb is: if the changelist doesn’t touch the line, it’s out of scope.

#### Look for opportunities to split up large reviews

#### Offer sincere praise

#### Grant approval when remaining fixes are trivial

- Grant approval when any of the following are true
  - You have no more notes.
  - Your remaining notes are for trivial issues (eg. typo)
  - Your remaining notes are optional suggestions

#### Handle stalemates proactively

- Talk it out: Meet in person or over video chat
- Consider a design review
- Concede or Escalate
- Recovering from a stalemate

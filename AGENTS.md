# AGENTS.md

## Codebase expectations

## Quality requirements

- Changes must not break one platform while fixing the other
- Prefer small, targeted changes
- Keep dependencies minimal and justified

## Agent instructions

When working on this project:

1. Prefer simple solutions that are easy to test and maintain
1. Keep project structure clean and predictable
1. Avoid introducing unnecessary backend or cloud complexity unless explicitly requested
1. Never perform changes that are not explicitly requested and approved by the instructor

## Definition of done

A task is complete only if:

- the Flutter project still builds successfully
- the diff is minimal and focused
- the task fulfills explicitly every single point in the requirements list that was given
- no additional changes outside the requirements have been made
- you have explicitly validated that the current UX and features have not changed unless explicitly requested. New code must never change current UX behaviour nor features.

## Core Rules

### 1. Literal Obedience

- Implement **exactly** what is asked. Nothing more, nothing less.
- Do not add unrequested features, styles, animations, restructuring, or "improvements."
- Do not apply your own aesthetic or architectural preferences.
- Do not change current UI and introduce spurious elements unless explicitly asked to do so.
- If an instruction seems suboptimal to you, **do not silently correct it**. Flag it first, then wait.

### 2. Ask Before Acting

- If any part of a request is ambiguous, **stop and ask** before writing a single line of code.
- List your specific questions clearly and concisely.
- Do not make assumptions and proceed — assumptions are forbidden.
- A question asked upfront costs nothing. A wrong implementation costs a revert.

### 3. Minimal Diffs

- Changes must be **as small as possible** to accomplish the task.
- Do not refactor surrounding code unless explicitly instructed.
- Do not rename variables, reorder properties, or reformat blocks that are not part of the task.
- Do not clean up whitespace, fix indentation, or reorganize imports unless asked.

### 4. No Scope Creep

- Stay strictly within the scope of the request.
- If you notice an unrelated bug or issue while working, **mention it separately** after completing the task. Do not fix it silently.

### 5. No unwanted changes

- if you are asked a question, answer the question without making changes. Do not make changes _unless_ explicitly required to do so. Address questions immediately and only if the user prompts you for a change do so.

______________________________________________________________________

## Response Format

When implementing a change:

1. State in one sentence what you are doing.
1. Show only the modified code block(s) with enough surrounding context to locate them.
1. Do not explain the code unless asked.
1. Do not add "Note:", "Tip:", or unsolicited commentary.

When asking a clarifying question:

1. State that you need clarification before proceeding.
1. List your questions as a numbered list.
1. Do not write any code until answers are received.

______________________________________________________________________

## Visual Consistency

If a visual element (button, card, input, badge, modal, tooltip, etc.) already exists anywhere in the app, any new instance of that element **must match it exactly** — same classes, same structure, same spacing, same colors, same typography.

- Do not create a "similar" version. Find the existing pattern and replicate it verbatim.
- If you are unsure what the existing pattern looks like, **ask** before implementing.
- Do not introduce a second styling approach for the same type of element.
- Consistency is not optional. A divergent instance is a bug, not a variation.

______________________________________________________________________

## Prohibited Behaviors

- ❌ Interpreting vague instructions without asking
- ❌ Adding code "while you're at it"
- ❌ Silently fixing things that weren't broken
- ❌ Rewriting working code in a "better" style
- ❌ Providing alternative approaches unless the original is technically impossible
- ❌ Adding comments to code
- ❌ Changing file structure or naming conventions

______________________________________________________________________

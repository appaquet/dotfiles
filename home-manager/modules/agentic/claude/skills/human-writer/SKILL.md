---
name: human-writer
description: Writing style rules to avoid AI-sounding patterns in prose. Use when writing documentation, PR descriptions, READMEs, changelogs, long explanations, or any user-facing text longer than a few sentences. Do NOT use for code, short factual answers, or command output.
---

# Human Writer

Rules for producing prose that reads as written by a human, not an LLM. Apply these when writing
any non-trivial user-facing text.

## Core Principles

- Be concrete and specific. "Reduced latency by 40ms" not "improved performance"
- Have opinions when relevant. Pick a side instead of hedging everything
- Allow imperfection. Occasional informal phrasing beats relentless polish
- Say it once. If one sentence covers it, don't spread across three with filler transitions
- Describe things proportionally. Most things are ordinary, reserve strong language for what earns it

## Banned Words

Never use these. They are the most statistically flagged AI patterns:

delve, tapestry, vibrant, multifaceted, game-changer, groundbreaking, cutting-edge,
unleash, unlock (the potential/power of), embark on a journey, at its core,
pave the way, spearhead, rich cultural heritage, enduring legacy, intricate interplay,
ever-evolving, seamless integration

## Restricted Words

Use sparingly (max once per response). Prefer the plain alternative.

| AI-flagged | Plain alternative |
|---|---|
| crucial, pivotal, vital | important, matters, key |
| leverage (verb) | use |
| utilize | use |
| robust | strong, solid |
| seamless | smooth |
| comprehensive | full, complete, thorough |
| nuanced | subtle, specific |
| foster | build, encourage, grow |
| underscore, highlight, showcase | show, point to, reveal |
| navigate (metaphorical) | deal with, handle, work through |
| landscape (metaphorical) | space, field, area |
| realm | area, domain |
| testament to | shows, proves |
| enhance | improve |
| streamline | simplify |
| empower | let, enable, help |
| innovative | new |
| optimal | best |
| facilitate | help, allow |
| encompasses | includes, covers |

## Banned Phrases

These appear orders of magnitude more often in AI text than human text:

- "complex and multifaceted" (700x overuse vs human baseline)
- "intricate interplay" (100x overuse)
- "played a crucial role" (70x overuse)
- "not only... but also..."
- "It's not just X, it's Y"
- "a testament to"
- "the move underscores a broader shift"
- "in an era of"
- "serves as a reminder that"
- "stands as a testament"
- "offers a glimpse into"
- "a rich tapestry of"

## Banned Openers and Transitions

Never open a sentence or paragraph with:

- "It's worth noting" / "It's important to note" / "It bears mentioning"
- "Interestingly" / "Notably" / "Crucially" / "Significantly"
- "Indeed" / "Moreover" / "Furthermore" / "Additionally" / "Subsequently"
- "In today's [anything]" / "In the world of [anything]"
- "In conclusion" / "In summary" / "Overall" (as paragraph openers)
- "Whether you're a [X], a [Y], or a [Z]..."
- "That's a great question" or any sycophantic opener

## Structural Rules

1. No rule-of-three abuse: don't default to "X, Y, and Z" triads for every list. Two items, four
   items, or one item are all fine
2. No synonym rotation: repeating a word is better than cycling through "the framework",
   "the tool", "the solution", "the platform" to avoid repetition
3. No em dashes: never use them, they are a strong AI tell. Use commas, parentheses, colons,
   or just start a new sentence
4. No importance inflation: don't call things "significant", "fascinating", "pivotal" unless
   they genuinely are
5. No formulaic endings: don't close sections with vague positive speculation
6. No excessive bolding in running prose
7. No semicolons: LLMs overuse semicolons to join clauses. Use a period and start a new sentence,
   or restructure with a comma
8. Sentence case in headings: "Getting started with the API" not "Getting Started With The API"
9. No curly quotes: use straight quotes
10. Don't bullet-point everything: use prose when items are connected thoughts

## Tone

- No promotional language: "new feature" not "powerful new feature"
- No flattery or sycophancy
- Concrete over vague: numbers, names, specifics over "improved", "enhanced", "optimized"
- Plain words over fancy ones: "use" not "utilize", "improve" not "enhance", "show" not "showcase"

# Reviewing

REVIEW comments mark actionable feedback directly in code - a core communication mechanism

User writes them to flag issues or instructions without prompting individually
Review agents also insert them during automated reviews

Every REVIEW comment is a directive — never dismiss or treat as optional
NEVER remove them if you believe they are not relevant. Leave them, add comment under to explain why
and I'll decide

## Comment Format

```
// REVIEW: <description>
// REVIEW: <agent-name> - <description>
```

Multi-line (`>>` opens, `<<` closes):

```
// REVIEW: description >>
// continued detail
// <<
```

## Searching

```
Grep(pattern="(//|#|--|/\\*|\\*)\\s*REVIEW:", output_mode="content")
```

* Ignore results in `proj/`
* Don't use bash rg — glob exclusions fail silently

## Addressing Comments

* Remove each comment after its fix — never replace with `// Note:` or other explanation
  => Add comment bellow it instead
* Never skip a comment. If pushing back: fix others first, report which and why
* Implement what the comment describes — if it names an abstraction or solution, build that.
  Don't reinterpret into a different approach that's "related but easier"

# Personal rules

## General

* You can call be AP, I live in Quebec, Canada and I speak French and English. I'd rather have you
  speak to me in English, but I can understand French.
* We're coworkers, but I'm technically your boss. However, I've always been a very informal,
  friendly and open boss.
* Neither of us are perfect, so we can make mistakes, but we should always try to do our best.
* We are always open to feedback and suggestions, and we always push each other to improve.
* It's ok, to be critical, and when you think you are right, it's OK to disagree with me.
* When you don't know something, I'd rather you ask me or do some research rather than making
  assumptions. You have access to the internet, so you can look things up.
* I like jokes and humor, but not when it gets in the way of work.
* I like to keep things simple, so don't overcomplicate things.
* Stop saying I'm right all the time, I hate it. Be critical, and just do the work we need to do
  instead of constantly trying to please me.

## General instructions

* *ALWAYS* load the context of the project you are working on before *ANY* interaction with the
  user. Follow the step-by-step process described in @commands/load-context.md.

* You should **ALWAYS** favor using ripgrep `rg` over `find`+`grep` since find can do mutations and
  will require my approval, while `rg` is read-only and will not require my approval.

* If we have a project documentation (`PR.md`), you should always read it before starting AND update
  it as you go along.

* At the end of every interaction (ex: after a task is done, after answer a question, after
  planning), you should call terminal command `notify "<some message>"` to notify the user of the
  completed task. Such message could be: `Coding done`, `Planning done`, `Need more context`, etc.

* **TODO preservation rule**: NEVER replace TODO/FIXME comments with explanatory notes. TODO/FIXME
  comments must remain as actionable TODOs until either:
    1. The task is actually implemented
    2. The TODO is explicitly tracked in an external TODO list (like PR.md) to ensure it won't be
       forgotten and i told you to remove it.
       Comments like "// Note: this is intentional" are not sufficient to replace TODOs.

## Environment

* I'm on NixOS most of the time, but may be on MacOS as well when I interact with you.
* I use fish, so you may be asked to execute fish functions, which means that you'll *NEED* to use
  `fish -c "the function with params"` to execute them

## Version control

As soon as you start working on a project, you *MUST* use version control to interact with its
codebase. Check this documentation for more information: @docs/version-control.md

## Development instructions

Before starting any development task (planning, coding, testing, etc.), you *MUST* read this
documentation: @docs/development.md

## General code style guidelines

Before writing any code, you *MUST* read this documentation: @docs/code-style.md

## Pull Request / Project documentation

Tasks / branches / features are documented via a `PR.md` file. You *MUST* read this documentation
before starting any task: @docs/PR-file.md

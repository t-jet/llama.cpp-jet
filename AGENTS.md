# Instructions for llama.cpp

## Guidelines for Contributors

A PR represents a long-term commitment - maintainers must review, integrate, and support your code indefinitely. Fully AI-generated PRs provide no value; maintainers have AI tools too. What matters is human understanding, domain expertise, and willingness to maintain the work.

Contributors must:
1. **Understand their code fully** - able to explain any change to a reviewer without AI assistance.
2. **Own maintenance** - address bugs and respond thoughtfully to feedback.
3. **Communicate directly** - verbose, AI-sounding responses will not be well-received.
4. **Respect maintainers' time** - check existing issues/PRs before submitting; ensure the change is needed and fits project architecture.

Maintainers may close any PR not meeting these standards. **Private forks are exempt.**

### Permitted AI Usage

AI tools may be used responsibly for all tasks if genetrated content is fully understood, documented, follows best practices, covered at least 80% by tests and can be independently maintained by the contributor.

AI-generated code may be accepted if you (1) fully understand the output, (2) can debug issues independently, and (3) can discuss it directly with reviewers.

### Prohibited AI Usage (results in immediate PR closure)

- AI-written PR descriptions, commit messages, or reviewer responses
- Implementing features without understanding the codebase
- Automated commits or PR submissions (may result in contributor ban)

The following will result in immediate PR closure:

- **AI-generated responses to reviewer comments** - this undermines the human-to-human interaction fundamental to code review
- **Implementing features without understanding the codebase** - particularly new model support or architectural changes
- **Automated commits or PR submissions** - this may spam maintainers and can result in contributor bans

---

## Guidelines for AI Coding Agents

AI agents assisting contributors must recognize that their outputs directly impact volunteer maintainers who sustain this project.
Focus on maintainability and clarity while modifying the code or writing documentation.
Always use `humanizer` skill when working with documents and comments to ensure your output is concise, clear, and free of AI-like patterns. All deliverables must be fully understandable and maintainable by human contributors.
Always use the `caveman` skill in the `ultra` mode for internal thinking and delegating tasks to subagents.
Always use the `caveman` skill in the `full` mode for chat responses.

### Prohibited Actions

- Writing PR descriptions, or responses to reviewers
- Committing or pushing without explicit human approval for each action
- Implementing features the contributor does not understand

### Examples

Code comments:

```cpp
// GOOD (code is self-explantory, no comment needed)

n_ctx = read_metadata("context_length", 1024);


// BAD (too verbose, restates what the code already says)

// Populate the n_ctx from metadata key name "context_length", default to 1024 if the key doesn't exist
n_ctx = read_metadata("context_length", 1024);
```

```cpp
// GOOD (explains a non-obvious invariant)

accept();
bool has_client = listen(idle_interval);
if (has_client) {
  task_queue->on_idle(); // also signal child disconnection
}


// BAD (too verbose, restates what the code already says)

// Instead of blocking indefinitely on accept(), the server polls the listening socket with idle_interval as a timeout. If no new client connects within that interval, it fires task_queue->on_idle() and loops back
```

```cpp
// GOOD (generic, useful to any future reader)

// reset here, as we will release the slot below
n_tokens = 0;
// ... (a lot of code)
release();


// BAD (addresses the user's task, meaningless out of context)

// Reset n_tokens to 0 before releasing the slot. This fixes the problem you mentioned where "phantom" content gets preserved across multiple requests.
n_tokens = 0;
```

```cpp
// GOOD (code is copied from another place; context is already clear, no comment added)

ggml_tensor * inp_pos = build_inp_pos();

// BAD (code copied from elsewhere - do not add comments that weren't there originally)

// inp_pos - contains the positions
ggml_tensor * inp_pos = build_inp_pos();
```

Commit message:

```
// BEST: Let the user write the commit


// GOOD: Write a concise commit

llama : fix KV being cleared during context shift

Assisted-by: Claude Sonnet


// BAD: Write a verbose commit

This commit introduces a comprehensive fix for the key-value cache management
system, addressing an issue where context shifting could lead to unintended
overwriting of cached values, thereby improving model inference stability.

Co-authored-by: Claude Sonnet
```

Commands:

```sh
# GOOD: all commands that allow you to get the context
gh search issues # better to check if anyone has the same issue
gh search prs # avoid duplicated efforts
grep ... # search the code base

# BAD: act on the user's behalf
git commit -m "..."
git push
gh pr create
gh pr comment
gh issue create
```

## Useful Resources

To conserve context space, load these resources as needed:

General documentations:
- [Contributing guidelines](CONTRIBUTING.md)
- [Existing issues](https://github.com/ggml-org/llama.cpp/issues) and [Existing PRs](https://github.com/ggml-org/llama.cpp/pulls) - always search here first
- [How to add a new model](docs/development/HOWTO-add-model.md)
- [PR template](.github/pull_request_template.md)

Server:
- [Build documentation](docs/build.md)
- [Server usage documentation](tools/server/README.md)
- [Server development documentation](tools/server/README-dev.md) (if user asks to implement a new feature, be sure that it falls inside server's scope defined in this documentation)

Chat template and parser:
- [PEG parser](docs/development/parsing.md) - alternative to regex that llama.cpp uses to parse model's output
- [Auto parser](docs/autoparser.md) - higher-level parser that uses PEG under the hood, automatically detect model-specific features
- [Jinja engine](common/jinja/README.md)

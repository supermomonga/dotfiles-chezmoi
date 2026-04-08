---
name: project-setup
description: Set up a new project in the current directory using a template from ~/.config/project-setup-instructions/. Use this skill whenever the user wants to create a new project, initialize a project, scaffold a project, or start a new codebase. Also trigger when the user says things like "新規プロジェクト", "プロジェクトセットアップ", "プロジェクトを作って", "init project", or mentions setting up any kind of project from scratch.
---

# Project Setup Skill

Set up a new project in the current directory by following a user-selected template from `~/.config/project-setup-instructions/`.

The current directory is assumed to be the project folder — do not create a subdirectory.

## Workflow

Follow these steps in order. Each step must complete before moving to the next.

### Step 1: Select a template

List all `.md` files in `~/.config/project-setup-instructions/` using Glob or Bash. Then present the available templates to the user with the `AskUserQuestion` tool so they can choose one. Format the question clearly — show the filename (without `.md` extension) as the template name for each option.

If only one template exists, still confirm with the user before proceeding ("〇〇 テンプレートを使いますか？" etc.).

If no templates are found, tell the user that no templates exist in `~/.config/project-setup-instructions/` and stop.

### Step 2: Confirm the project name

Infer the project name from the basename of the current working directory (e.g., if cwd is `/home/code/my-awesome-bot`, the inferred name is `my-awesome-bot`).

Ask the user with `AskUserQuestion` to confirm or override this name. For example:

> カレントディレクトリ名から推定したプロジェクト名は「my-awesome-bot」です。この名前でよろしいですか？別の名前を使いたい場合は入力してください。

Use whatever the user responds with as the project name going forward.

### Step 3: Initialize git

Check if the current directory is already a git repository (`git rev-parse --is-inside-work-tree`). If not, run `git init`.

### Step 4: Execute the template

Read the selected template file and follow its instructions to set up the project. The template is a markdown document that describes the project structure, dependencies, configuration files, and other setup details.

When applying the template:

- Replace all occurrences of `<project-name>` or similar placeholders in the template with the confirmed project name.
- Create all directories and files as specified in the template's project structure section.
- Install dependencies as specified (e.g., `bun add ...`, `npm install ...`).
- Generate configuration files (tsconfig.json, .gitignore, etc.) with the content specified or implied by the template.
- Create initial source files with the boilerplate/skeleton code shown in the template.
- If the template mentions configuration files that need user-specific values (like Slack tokens, channel IDs, etc.), do NOT create those files with dummy values in the project directory — instead, note what the user needs to configure later.

If something in the template is ambiguous or requires a choice from the user (e.g., which optional features to include), ask with `AskUserQuestion`.

### Step 5: Commit the result

Stage all the newly created project files and create an initial git commit. Use a commit message like:

```
Initial project setup from <template-name> template
```

After the commit, give the user a brief summary of what was set up and any remaining manual steps they need to take (like setting environment variables or creating config files outside the project directory).

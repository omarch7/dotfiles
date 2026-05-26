# Graph Report - .  (2026-05-26)

## Corpus Check
- Corpus is ~11,036 words - fits in a single context window. You may not need a graph.

## Summary
- 164 nodes · 116 edges · 55 communities (44 shown, 11 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 7 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Catppuccin Theme Overrides|Catppuccin Theme Overrides]]
- [[_COMMUNITY_Core Dotfiles Architecture|Core Dotfiles Architecture]]
- [[_COMMUNITY_Graph Detection Metadata|Graph Detection Metadata]]
- [[_COMMUNITY_RGB Hardware Config|RGB Hardware Config]]
- [[_COMMUNITY_Lua Language Server Config|Lua Language Server Config]]
- [[_COMMUNITY_Claude Permissions Settings|Claude Permissions Settings]]
- [[_COMMUNITY_AST Extraction Metadata|AST Extraction Metadata]]
- [[_COMMUNITY_AI LLM Integration|AI LLM Integration]]
- [[_COMMUNITY_CI Release Pipeline|CI Release Pipeline]]
- [[_COMMUNITY_Catppuccin Base Theme|Catppuccin Base Theme]]
- [[_COMMUNITY_Tmux Theme Detection|Tmux Theme Detection]]
- [[_COMMUNITY_Snacks Keybindings|Snacks Keybindings]]
- [[_COMMUNITY_Claude Context Bar|Claude Context Bar]]
- [[_COMMUNITY_Repository Documentation|Repository Documentation]]
- [[_COMMUNITY_Conform Formatting|Conform Formatting]]
- [[_COMMUNITY_UFO Smart Folding|UFO Smart Folding]]
- [[_COMMUNITY_Noice UI Enhancement|Noice UI Enhancement]]
- [[_COMMUNITY_FZF Fuzzy Finder|FZF Fuzzy Finder]]
- [[_COMMUNITY_Git Tools Suite|Git Tools Suite]]
- [[_COMMUNITY_Mason Package Manager|Mason Package Manager]]

## God Nodes (most connected - your core abstractions)
1. `overrides` - 39 edges
2. `Modular Neovim Configuration` - 11 edges
3. `files` - 6 edges
4. `Omar's Dotfiles` - 6 edges
5. `rgb` - 5 edges
6. `permissions` - 4 edges
7. `Omar's Dotfiles Repository` - 3 edges
8. `Lazy Plugin Manager` - 3 edges
9. `AI & LLM Integration` - 3 edges
10. `Catppuccin Mocha Colorscheme` - 3 edges

## Surprising Connections (you probably didn't know these)
- `Modular Organization Principle` --implements--> `Modular Neovim Configuration`  [INFERRED]
  README.md → CLAUDE.md
- `CI Lint Workflow` --references--> `Modular Neovim Configuration`  [INFERRED]
  .github/workflows/lint-dotfiles.yml → CLAUDE.md
- `Omar's Dotfiles` --conceptually_related_to--> `Omar's Dotfiles Repository`  [INFERRED]
  README.md → CLAUDE.md
- `Lazy Loading Strategy` --implements--> `Lazy Plugin Manager`  [INFERRED]
  README.md → CLAUDE.md
- `Blink.cmp Completion Engine` --uses--> `LSP Integration`  [INFERRED]
  README.md → CLAUDE.md

## Hyperedges (group relationships)
- **Dotfiles Components** — README_OmarDotfiles, CLAUDE_NeovimConfig, README_TmuxConfig, README_Starship [EXTRACTED 0.95]
- **AI Integration Ecosystem** — CLAUDE_AILLMIntegration, CLAUDE_Copilot, CLAUDE_AvanteNvim, CLAUDE_AvanteProviders [EXTRACTED 0.90]
- **CI/CD Pipeline** — release_ReleaseWorkflow, lint_LintWorkflow, release_SemVer, lint_Luacheck [INFERRED 0.80]

## Communities (55 total, 11 thin omitted)

### Community 0 - "Catppuccin Theme Overrides"
Cohesion: 0.05
Nodes (39): overrides, autoAccept, bashBorder, blue_FOR_SUBAGENTS_ONLY, claude, claudeShimmer, cyan_FOR_SUBAGENTS_ONLY, diffAdded (+31 more)

### Community 1 - "Core Dotfiles Architecture"
Cohesion: 0.11
Nodes (21): DAP Debugging Integration, Omar's Dotfiles Repository, Git Integration (DiffView, Gitsigns), LSP Integration, Lazy Plugin Manager, Navigation & Productivity (Telescope, NvimTree), Modular Neovim Configuration, Treesitter Syntax Engine (+13 more)

### Community 2 - "Graph Detection Metadata"
Cohesion: 0.14
Nodes (13): files, code, document, image, paper, video, graphifyignore_patterns, needs_graph (+5 more)

### Community 3 - "RGB Hardware Config"
Cohesion: 0.15
Nodes (12): aio, default_fps, ene6k77, fan_curves, fans, hid_driver, lcds, rgb (+4 more)

### Community 4 - "Lua Language Server Config"
Cohesion: 0.29
Nodes (6): diagnostics.globals, runtime.path, runtime.version, telemetry.enable, workspace.checkThirdParty, workspace.library

### Community 5 - "Claude Permissions Settings"
Cohesion: 0.40
Nodes (4): permissions, allow, ask, deny

### Community 6 - "AST Extraction Metadata"
Cohesion: 0.40
Nodes (4): edges, input_tokens, nodes, output_tokens

### Community 7 - "AI LLM Integration"
Cohesion: 0.50
Nodes (4): AI & LLM Integration, Avante.nvim LLM Plugin, Avante LLM Providers (Bedrock, Claude, Ollama, Gemini), GitHub Copilot

### Community 8 - "CI Release Pipeline"
Cohesion: 0.67
Nodes (4): Branch Prefix Convention (major/minor/patch), Auto-generated Changelog, GitHub Release Workflow, Semantic Version Bumping

## Knowledge Gaps
- **100 isolated node(s):** `code`, `document`, `paper`, `image`, `video` (+95 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `overrides` connect `Catppuccin Theme Overrides` to `Catppuccin Base Theme`?**
  _High betweenness centrality (0.062) - this node is a cross-community bridge._
- **Why does `Modular Neovim Configuration` connect `Core Dotfiles Architecture` to `AI LLM Integration`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `Modular Neovim Configuration` (e.g. with `Modular Organization Principle` and `CI Lint Workflow`) actually correct?**
  _`Modular Neovim Configuration` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `code`, `document`, `paper` to the rest of the system?**
  _100 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Catppuccin Theme Overrides` be split into smaller, more focused modules?**
  _Cohesion score 0.05128205128205128 - nodes in this community are weakly interconnected._
- **Should `Core Dotfiles Architecture` be split into smaller, more focused modules?**
  _Cohesion score 0.11428571428571428 - nodes in this community are weakly interconnected._
- **Should `Graph Detection Metadata` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
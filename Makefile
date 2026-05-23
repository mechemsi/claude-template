SHELL        := /usr/bin/env bash
REPO_DIR     := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SKILLS_DIR   := $(REPO_DIR)/skills
CLAUDE_TARGET_DIR := $(HOME)/.claude/skills
CODEX_TARGET_DIR  := $(HOME)/.agents/skills

SKILLS := $(notdir $(wildcard $(SKILLS_DIR)/*))

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "claudet - Claude Code + Codex project template"
	@echo ""
	@echo "Skill installation targets:"
	@echo "  make install         Symlink every skill into Claude and Codex global skill dirs"
	@echo "  make install-claude  Symlink every skill into ~/.claude/skills/"
	@echo "  make install-codex   Symlink every skill into ~/.agents/skills/"
	@echo "  make install-copy    Copy skills into both global skill dirs instead of symlinking"
	@echo "  make uninstall       Remove symlinks in both global skill dirs that point at this repo"
	@echo "  make list            Show which skills are installed and where each one points"
	@echo "  make doctor          Diagnose: does each repo skill have a working install?"
	@echo "  make sync-agents     Generate Claude/Codex adapter files in this repo"
	@echo ""
	@echo "Repo dir:    $(REPO_DIR)"
	@echo "Skills:      $(SKILLS)"
	@echo "Claude dir:  $(CLAUDE_TARGET_DIR)"
	@echo "Codex dir:   $(CODEX_TARGET_DIR)"

.PHONY: install
install: install-claude install-codex
	@echo ""
	@echo "Done. $(words $(SKILLS)) skills available for Claude and Codex."

.PHONY: install-claude
install-claude:
	@$(MAKE) install-one TARGET_DIR="$(CLAUDE_TARGET_DIR)" TARGET_LABEL="claude"

.PHONY: install-codex
install-codex:
	@$(MAKE) install-one TARGET_DIR="$(CODEX_TARGET_DIR)" TARGET_LABEL="codex"

.PHONY: install-one
install-one:
	@mkdir -p "$(TARGET_DIR)"
	@for skill in $(SKILLS); do \
		src="$(SKILLS_DIR)/$$skill" ; \
		dst="$(TARGET_DIR)/$$skill" ; \
		if [ -L "$$dst" ]; then \
			current=$$(readlink "$$dst") ; \
			if [ "$$current" = "$$src" ]; then \
				echo "  $(TARGET_LABEL) ok      $$skill (already linked)" ; \
			else \
				echo "  $(TARGET_LABEL) relink  $$skill (was -> $$current)" ; \
				ln -sfn "$$src" "$$dst" ; \
			fi ; \
		elif [ -e "$$dst" ]; then \
			echo "  $(TARGET_LABEL) SKIP    $$skill - $$dst already exists as a real file/dir; remove it manually first" ; \
		else \
			ln -s "$$src" "$$dst" ; \
			echo "  $(TARGET_LABEL) link    $$skill" ; \
		fi ; \
	done

.PHONY: install-copy
install-copy:
	@mkdir -p "$(CLAUDE_TARGET_DIR)" "$(CODEX_TARGET_DIR)"
	@for skill in $(SKILLS); do \
		src="$(SKILLS_DIR)/$$skill" ; \
		for target in "$(CLAUDE_TARGET_DIR)" "$(CODEX_TARGET_DIR)"; do \
			dst="$$target/$$skill" ; \
			if [ -L "$$dst" ]; then \
				rm "$$dst" ; \
			fi ; \
			rm -rf "$$dst" ; \
			cp -r "$$src" "$$dst" ; \
			echo "  copy    $$skill -> $$target" ; \
		done ; \
	done
	@echo ""
	@echo "Done. Copies are static; re-run 'make install-copy' after pulling changes."

.PHONY: uninstall
uninstall:
	@for skill in $(SKILLS); do \
		for target_dir in "$(CLAUDE_TARGET_DIR)" "$(CODEX_TARGET_DIR)"; do \
			dst="$$target_dir/$$skill" ; \
			if [ -L "$$dst" ]; then \
				target=$$(readlink "$$dst") ; \
				case "$$target" in \
					$(REPO_DIR)/*) rm "$$dst" ; echo "  remove  $$skill from $$target_dir" ;; \
					*)             echo "  keep    $$skill (links elsewhere: $$target)" ;; \
				esac ; \
			elif [ -e "$$dst" ]; then \
				echo "  keep    $$skill (real dir, not from this repo)" ; \
			fi ; \
		done ; \
	done

.PHONY: list
list:
	@for skill in $(SKILLS); do \
		for target_dir in "$(CLAUDE_TARGET_DIR)" "$(CODEX_TARGET_DIR)"; do \
			dst="$$target_dir/$$skill" ; \
			if [ -L "$$dst" ]; then \
				printf "  %-24s %-30s -> %s\n" "$$target_dir" "$$skill" "$$(readlink $$dst)" ; \
			elif [ -d "$$dst" ]; then \
				printf "  %-24s %-30s (copied, not symlinked)\n" "$$target_dir" "$$skill" ; \
			else \
				printf "  %-24s %-30s NOT INSTALLED\n" "$$target_dir" "$$skill" ; \
			fi ; \
		done ; \
	done

.PHONY: doctor
doctor:
	@fail=0 ; \
	for skill in $(SKILLS); do \
		src="$(SKILLS_DIR)/$$skill/SKILL.md" ; \
		for target_dir in "$(CLAUDE_TARGET_DIR)" "$(CODEX_TARGET_DIR)"; do \
			dst="$$target_dir/$$skill" ; \
			if [ ! -f "$$src" ]; then \
				echo "  ERR     $$skill - missing SKILL.md in repo" ; fail=1 ; \
			elif [ ! -e "$$dst" ]; then \
				echo "  WARN    $$skill - not installed in $$target_dir (run: make install)" ; fail=1 ; \
			elif [ -L "$$dst" ] && [ ! -e "$$(readlink $$dst)/SKILL.md" ]; then \
				echo "  ERR     $$skill - broken symlink in $$target_dir" ; fail=1 ; \
			else \
				echo "  ok      $$skill in $$target_dir" ; \
			fi ; \
		done ; \
	done ; \
	exit $$fail

.PHONY: sync-agents
sync-agents:
	@python3 "$(SKILLS_DIR)/agent-config-sync/scripts/agent_config_sync.py" --target "$(REPO_DIR)" --direction claude-to-codex --force

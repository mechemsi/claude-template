SHELL        := /usr/bin/env bash
REPO_DIR     := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SKILLS_DIR   := $(REPO_DIR)/skills
TARGET_DIR   := $(HOME)/.claude/skills

SKILLS := $(notdir $(wildcard $(SKILLS_DIR)/*))

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "claudet — Claude Code project template"
	@echo ""
	@echo "Skill installation targets:"
	@echo "  make install         Symlink every skill in ./skills/ into ~/.claude/skills/ (recommended)"
	@echo "  make install-copy    Copy skills into ~/.claude/skills/ instead of symlinking"
	@echo "  make uninstall       Remove symlinks in ~/.claude/skills/ that point at this repo"
	@echo "  make list            Show which skills are installed and where they point"
	@echo "  make doctor          Diagnose: does each repo skill have a working install?"
	@echo ""
	@echo "Repo dir:    $(REPO_DIR)"
	@echo "Skills:      $(SKILLS)"
	@echo "Target:      $(TARGET_DIR)"

.PHONY: install
install:
	@mkdir -p "$(TARGET_DIR)"
	@for skill in $(SKILLS); do \
		src="$(SKILLS_DIR)/$$skill" ; \
		dst="$(TARGET_DIR)/$$skill" ; \
		if [ -L "$$dst" ]; then \
			current=$$(readlink "$$dst") ; \
			if [ "$$current" = "$$src" ]; then \
				echo "  ok      $$skill (already linked)" ; \
			else \
				echo "  relink  $$skill (was → $$current)" ; \
				ln -sfn "$$src" "$$dst" ; \
			fi ; \
		elif [ -e "$$dst" ]; then \
			echo "  SKIP    $$skill — $$dst already exists as a real file/dir; remove it manually first" ; \
		else \
			ln -s "$$src" "$$dst" ; \
			echo "  link    $$skill" ; \
		fi ; \
	done
	@echo ""
	@echo "Done. $(words $(SKILLS)) skills available globally via $(TARGET_DIR)/."

.PHONY: install-copy
install-copy:
	@mkdir -p "$(TARGET_DIR)"
	@for skill in $(SKILLS); do \
		src="$(SKILLS_DIR)/$$skill" ; \
		dst="$(TARGET_DIR)/$$skill" ; \
		if [ -L "$$dst" ]; then \
			rm "$$dst" ; \
		fi ; \
		rm -rf "$$dst" ; \
		cp -r "$$src" "$$dst" ; \
		echo "  copy    $$skill" ; \
	done
	@echo ""
	@echo "Done. Copies are static — re-run 'make install-copy' after pulling changes."

.PHONY: uninstall
uninstall:
	@for skill in $(SKILLS); do \
		dst="$(TARGET_DIR)/$$skill" ; \
		if [ -L "$$dst" ]; then \
			target=$$(readlink "$$dst") ; \
			case "$$target" in \
				$(REPO_DIR)/*) rm "$$dst" ; echo "  remove  $$skill" ;; \
				*)             echo "  keep    $$skill (links elsewhere: $$target)" ;; \
			esac ; \
		elif [ -e "$$dst" ]; then \
			echo "  keep    $$skill (real dir, not from this repo)" ; \
		fi ; \
	done

.PHONY: list
list:
	@for skill in $(SKILLS); do \
		dst="$(TARGET_DIR)/$$skill" ; \
		if [ -L "$$dst" ]; then \
			printf "  %-30s → %s\n" "$$skill" "$$(readlink $$dst)" ; \
		elif [ -d "$$dst" ]; then \
			printf "  %-30s (copied, not symlinked)\n" "$$skill" ; \
		else \
			printf "  %-30s NOT INSTALLED\n" "$$skill" ; \
		fi ; \
	done

.PHONY: doctor
doctor:
	@fail=0 ; \
	for skill in $(SKILLS); do \
		dst="$(TARGET_DIR)/$$skill" ; \
		src="$(SKILLS_DIR)/$$skill/SKILL.md" ; \
		if [ ! -f "$$src" ]; then \
			echo "  ERR     $$skill — missing SKILL.md in repo" ; fail=1 ; \
		elif [ ! -e "$$dst" ]; then \
			echo "  WARN    $$skill — not installed (run: make install)" ; fail=1 ; \
		elif [ -L "$$dst" ] && [ ! -e "$$(readlink $$dst)/SKILL.md" ]; then \
			echo "  ERR     $$skill — broken symlink" ; fail=1 ; \
		else \
			echo "  ok      $$skill" ; \
		fi ; \
	done ; \
	exit $$fail

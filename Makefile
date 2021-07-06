#
# - passes args to venv/Makefile
# - only works for phony targets
#

TARGETS := $(shell awk -F .PHONY: '/^.PHONY/ {print $$2}' venv/Makefile)

$(TARGETS):
	@$(MAKE) -$(MAKEFLAGS) --no-print-directory --directory=venv \
		$(MAKECMDGOALS)

.PHONY: $(TARGETS)

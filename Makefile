# ooawk v0.2.0 Makefile

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/ooawk

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SRC := $(wildcard *.oo) $(wildcard */*.oo)
VERSION ?= $(shell cat VERSION 2>/dev/null || echo 0.2.0)

.PHONY: build check line-cap file-law academy density verify clean test package package-deb package-rpm package-arch install uninstall

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@cp -a $(BIN) dist/ooawk-linux-x86_64
	@sha256sum dist/ooawk-linux-x86_64 > dist/ooawk-linux-x86_64.sha256
	@echo "built $(BIN) (and dist/ooawk-linux-x86_64)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot" | grep -v "/dist/" | grep -v "/.ooda-cache/"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
			continue; \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.sh" -not -path "./.git/*" -not -path "./dist/*" 2>/dev/null); do \
		if [ "$$f" != "./install.sh" ] && [ "$$f" != "./uninstall.sh" ]; then \
			echo "VIOLATION: .sh forbidden outside install.sh and uninstall.sh: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./packaging*" -not -path "./qa*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

test: $(BIN)
	@echo "=== testing --help ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@echo "=== testing --version ==="
	@./$(BIN) --version | grep -q "0.2.0" && echo "PASS: --version"
	@rm -rf /tmp/ooawk-test && mkdir -p /tmp/ooawk-test
	@printf "apple 100 fruit\nbanana 200 fruit\ncarrot 50 veggie\n" > /tmp/ooawk-test/data.txt
	@echo "=== testing column projection ==="
	@./$(BIN) -c 1,2 /tmp/ooawk-test/data.txt | grep -q "apple 100" && echo "PASS: column projection -c 1,2"
	@./$(BIN) '{print $$1, $$3}' /tmp/ooawk-test/data.txt | grep -q "apple fruit" && echo "PASS: print expr {print $$1, $$3}"
	@echo "=== testing custom field separator ==="
	@printf "root:x:0:0:root:/root:/bin/bash\nbin:x:1:1:bin:/bin:/sbin/nologin\n" > /tmp/ooawk-test/passwd.txt
	@./$(BIN) -F ":" -c 1,7 /tmp/ooawk-test/passwd.txt | grep -q "root /bin/bash" && echo "PASS: custom delimiter -F :"
	@./$(BIN) -F ":" -v OFS="," -c 1,3 /tmp/ooawk-test/passwd.txt | grep -q "root,0" && echo "PASS: output field separator OFS"
	@echo "=== testing row filtering ==="
	@./$(BIN) --where "2,>,70" /tmp/ooawk-test/data.txt | grep -q "apple 100 fruit" && echo "PASS: filter numeric greater than"
	@./$(BIN) --where "3,==,veggie" -c 1 /tmp/ooawk-test/data.txt | grep -q "carrot" && echo "PASS: filter string equals"
	@echo "=== testing stats aggregation ==="
	@./$(BIN) -s 2 /tmp/ooawk-test/data.txt | grep -q "Sum:.*350" && echo "PASS: stats aggregation sum"
	@./$(BIN) -s 2 --json /tmp/ooawk-test/data.txt | grep -q '"sum":350' && echo "PASS: stats aggregation json"
	@echo "=== testing JSON output ==="
	@./$(BIN) -c 1 --json /tmp/ooawk-test/data.txt | grep -q '"apple"' && echo "PASS: json lines projection"
	@echo "=== testing MCP initialize ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "protocolVersion" && echo "PASS: MCP initialize"
	@echo "=== testing MCP tools/list ==="
	@printf '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "awk_eval" && echo "PASS: MCP tools/list"
	@echo "=== testing MCP tools/call awk_project ==="
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"awk_project","arguments":{"text":"foo 42 bar\nbaz 84 qux","cols":"1,2","fs":" "}}}\n' | ./$(BIN) --mcp | grep -q 'foo 42' && echo "PASS: MCP awk_project"
	@echo "=== testing MCP tools/call awk_filter ==="
	@printf '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"awk_filter","arguments":{"text":"alice 95\nbob 60\ncharlie 85","col":2,"op":">=","val":"80","fs":" "}}}\n' | ./$(BIN) --mcp | grep -q 'alice 95' && echo "PASS: MCP awk_filter"
	@echo "=== testing MCP tools/call awk_stats ==="
	@printf '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"awk_stats","arguments":{"text":"val 10\nval 20\nval 30","col":2,"fs":" "}}}\n' | ./$(BIN) --mcp | grep -q 'sum.*60' && echo "PASS: MCP awk_stats"
	@rm -rf /tmp/ooawk-test
	@echo "ALL TESTS PASSED"

install: $(BIN)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/ooawk
	install -m 0755 uninstall.sh $(DESTDIR)$(BINDIR)/ooawk-uninstall
	@echo "installed ooawk and ooawk-uninstall to $(DESTDIR)$(BINDIR)"

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/ooawk $(DESTDIR)$(BINDIR)/ooawk-uninstall
	@if [ "$(PURGE)" = "1" ]; then rm -rf $(HOME)/.cache/ooawk $(HOME)/.config/ooawk; echo "purged user cache and config"; fi
	@echo "uninstalled ooawk and ooawk-uninstall from $(DESTDIR)$(BINDIR)"

package-deb: $(BIN)
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/ooawk
	@chmod 0755 dist/deb-root/usr/bin/ooawk
	@cp uninstall.sh dist/deb-root/usr/bin/ooawk-uninstall
	@chmod 0755 dist/deb-root/usr/bin/ooawk-uninstall
	@dpkg-deb --build --root-owner-group dist/deb-root dist/ooawk_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/ooawk_$(VERSION)-1_amd64.deb"

package-rpm: $(BIN)
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/ooawk-linux-x86_64
	@cp uninstall.sh ~/rpmbuild/SOURCES/uninstall.sh
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/ooawk.spec > ~/rpmbuild/SPECS/ooawk.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/ooawk.spec
	@cp ~/rpmbuild/RPMS/x86_64/ooawk-$(VERSION)*.rpm dist/
	@echo "built dist RPM package"

package-arch: $(BIN)
	@mkdir -p dist/arch-pkg/usr/bin
	@cp $(BIN) dist/arch-pkg/usr/bin/ooawk
	@chmod 0755 dist/arch-pkg/usr/bin/ooawk
	@cp uninstall.sh dist/arch-pkg/usr/bin/ooawk-uninstall
	@chmod 0755 dist/arch-pkg/usr/bin/ooawk-uninstall
	@printf "pkgname = ooawk\npkgbase = ooawk\npkgver = $(VERSION)-1\npkgdesc = Data-driven pattern scanning and text processing language with exact arithmetic.\nurl = https://github.com/openOODA-tools/ooawk\nbuilddate = $$(date +%s)\npackager = openOODA-tools <ops@openooda.org>\nsize = $$(stat -c %s $(BIN))\narch = x86_64\nlicense = Apache-2.0\ndepend = glibc\nprovides = ooawk\n" > dist/arch-pkg/.PKGINFO
	@tar --zstd -cf dist/ooawk-$(VERSION)-1-x86_64.pkg.tar.zst -C dist/arch-pkg .PKGINFO usr
	@rm -rf dist/arch-pkg
	@bash -n packaging/arch/PKGBUILD
	@cp packaging/arch/PKGBUILD packaging/PKGBUILD
	@echo "built dist/ooawk-$(VERSION)-1-x86_64.pkg.tar.zst and validated PKGBUILD"

package: package-deb package-rpm package-arch
	@cd dist && sha256sum ooawk* > checksums.txt 2>/dev/null || true
	@echo "built all packages and dist/checksums.txt"

clean:
	@rm -rf dist .ooda-cache
	@echo "cleaned"

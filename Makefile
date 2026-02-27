PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
DATADIR = $(PREFIX)/share/opus

install:
	mkdir -p $(DESTDIR)$(BINDIR)
	mkdir -p $(DESTDIR)$(DATADIR)
	cp -r data/* $(DESTDIR)$(DATADIR)/
	sed 's|$${SCRIPT_DIR}/data|$(DATADIR)|' opus.sh > $(DESTDIR)$(BINDIR)/opus
	chmod 755 $(DESTDIR)$(BINDIR)/opus

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/opus
	rm -rf $(DESTDIR)$(DATADIR)

.PHONY: install uninstall hooks

hooks:
	sh scripts/install-hooks.sh

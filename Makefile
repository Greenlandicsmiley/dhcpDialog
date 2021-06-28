OPTDIR ?= /opt/dhcpDialog
BINDIR ?= /usr/bin

all:
	@echo "Run \"make install\" to install dhcpDialog"
	@echo "Run \"make update\" to update the existing dhcpDialog"
	@echo "Run \"make uninstall\" to uninstall dhcpDialog"

install:
	@mkdir -p $(DESTDIR)$(BINDIR)
	@mkdir -p $(DESTDIR)$(OPTDIR)
	@cp -p LICENSE $(DESTDIR)$(OPTDIR)/LICENSE
	@cp -p README.md $(DESTDIR)$(OPTDIR)/README.md
	@cp -p CONTRIBUTING.md $(DESTDIR)$(OPTDIR)/CONTRIBUTING.md
	@cp -p ABOUT $(DESTDIR)$(OPTDIR)/ABOUT
	@cp -r -p exclusions $(DESTDIR)$(OPTDIR)/exclusions
	@cp -r -p dhcpScopes $(DESTDIR)$(OPTDIR)/dhcpScopes
	@cp -p servers.list $(DESTDIR)$(OPTDIR)/servers.list
	@cp -p dhcpd.conf $(DESTDIR)$(OPTDIR)/dhcpd.conf
	@cp -p active.leases $(DESTDIR)$(OPTDIR)/active.leases
	@cp -p dhcpDialog.sh $(DESTDIR)$(BINDIR)/dhcpDialog
	@chmod 755 $(DESTDIR)$(BINDIR)/dhcpDialog

update:
	@cp -p LICENSE $(DESTDIR)$(OPTDIR)/LICENSE
	@cp -p README.md $(DESTDIR)$(OPTDIR)/README.md
	@cp -p CONTRIBUTING.md $(DESTDIR)$(OPTDIR)/CONTRIBUTING.md
	@cp -p ABOUT $(DESTDIR)$(OPTDIR)/ABOUT
	@cp -p dhcpDialog.sh $(DESTDIR)$(BINDIR)/dhcpDialog
	@chmod 755 $(DESTDIR)$(BINDIR)/dhcpDialog

uninstall:
	@rm -rf $(DESTDIR)$(OPTDIR)
	@rm $(DESTDIR)$(BINDIR)/dhcpDialog

PLUGIN_ID := lmoesle-token-usage
PACKAGE_DIR := ./package

.PHONY: install upgrade uninstall test test-panel package

install:
	kpackagetool6 --type Plasma/Applet --install $(PACKAGE_DIR) || kpackagetool6 --type Plasma/Applet --upgrade $(PACKAGE_DIR)

upgrade:
	kpackagetool6 --type Plasma/Applet --upgrade $(PACKAGE_DIR)

uninstall:
	kpackagetool6 --type Plasma/Applet --remove $(PLUGIN_ID)

test:
	plasmoidviewer -a $(PACKAGE_DIR)

test-panel:
	plasmoidviewer -a $(PACKAGE_DIR) -l topedge -f horizontal

package:
	rm -f $(PLUGIN_ID).plasmoid
	cd $(PACKAGE_DIR) && zip -r ../$(PLUGIN_ID).plasmoid .

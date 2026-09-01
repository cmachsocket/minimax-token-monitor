
NAME := org.kde.plasma.minimax-token-monitor
INSTALL_DIR := $(HOME)/.local/share/plasma/plasmoids/$(NAME)

install: clean
	cp -r . $(INSTALL_DIR)

clean:
	rm -rf $(INSTALL_DIR)

run : install
	plasmoidviewer --applet $(INSTALL_DIR)
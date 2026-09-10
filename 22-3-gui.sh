#!/bin/bash
###############################################################################
# Linux Mint 22.3 (Zena) Post-Installation - GRAFISCHE Version (zenity)
#
# Grafischer Umbau von 22-3.sh:
#   * Alle Ja/Nein-Abfragen -> zenity-Checklisten (vorab, gebuendelt)
#   * Privilegierter Installationslauf -> einmalig per pkexec als root
#   * Fortschrittsanzeige -> zenity --progress (Stufen-Labels + Logdatei)
#   * Benutzerspezifische dconf-Einstellungen -> danach in der User-Sitzung
#
# Aufruf: einfach ausfuehren (Doppelklick / ./22-3-gui.sh) in einer
#         grafischen Sitzung. Root wird per pkexec (Polkit) angefordert.
#
# Das Skript ruft sich fuer den Root-Teil selbst erneut auf:
#   pkexec bash <script> --root-phase <choices-datei>
###############################################################################

set -o pipefail

SELF="$(readlink -f "$0")"

# ---------------------------------------------------------------------------
# ============================  ROOT-PHASE  =================================
#  Wird per pkexec als root gestartet. Liest alle Entscheidungen aus der
#  Choices-Datei ($2). Gibt "# ..."-Zeilen fuer das zenity-Fortschrittslabel
#  aus; die vollstaendige Ausgabe wird von der GUI-Phase in ein Log geleitet.
# ---------------------------------------------------------------------------
if [ "$1" = "--root-phase" ]; then
	CHOICES="$2"
	if [ ! -r "$CHOICES" ]; then
		echo "Choices-Datei nicht lesbar: $CHOICES" >&2
		exit 1
	fi
	# shellcheck disable=SC1090
	. "$CHOICES"          # setzt opt_*, CONFIG, DE, USERLIST ...

	export DEBIAN_FRONTEND=noninteractive
	config="$CONFIG"

	pakete=""
	paketerec="digikam exiv2 kipi-plugins graphicsmagick-imagemagick-compat hw-probe"
	remove=""
	service=""
	rep=""

	# --- Fastly-Repository ---------------------------------------------------
	echo "# Richte Paketquellen (Mirrors) ein ..."
	if ! grep -q fastly.linuxmint.io /etc/apt/sources.list.d/official-package-repositories.list; then
		sed -i '/^deb http:\/\/packages.linuxmint.com zena main upstream import backport.*$/ideb http:\/\/fastly.linuxmint.io zena main upstream import backport' /etc/apt/sources.list.d/official-package-repositories.list
	fi
	# --- Zusaetzliche Mirrors bei Zeitzone Europe/Berlin ---------------------
	if grep -q Europe/Berlin /etc/timezone; then
		if ! grep -q ftp-stud.hs-esslingen.de /etc/apt/sources.list.d/official-package-repositories.list; then
			if ! grep -q -e ftp.uni-mainz.de -e ftp.rrzn.uni-hannover.de /etc/apt/sources.list.d/official-package-repositories.list; then
				sed -i '/^deb http:\/\/archive.ubuntu.com\/ubuntu noble main restricted universe multiverse$/ideb http:\/\/ftp.uni-mainz.de\/ubuntu noble main restricted universe multiverse\ndeb http:\/\/ftp.uni-mainz.de\/ubuntu noble-updates main restricted universe multiverse\ndeb http:\/\/ftp.uni-mainz.de\/ubuntu noble-backports main restricted universe multiverse\ndeb http:\/\/ftp-stud.hs-esslingen.de\/ubuntu noble main restricted universe multiverse\ndeb http:\/\/ftp-stud.hs-esslingen.de\/ubuntu noble-updates main restricted universe multiverse\ndeb http:\/\/ftp-stud.hs-esslingen.de\/ubuntu noble-backports main restricted universe multiverse\ndeb http:\/\/ftp.rrzn.uni-hannover.de\/pub\/mirror\/linux\/ubuntu noble main restricted universe multiverse\ndeb http:\/\/ftp.rrzn.uni-hannover.de\/pub\/mirror\/linux\/ubuntu noble-updates main restricted universe multiverse\ndeb http:\/\/ftp.rrzn.uni-hannover.de\/pub\/mirror\/linux\/ubuntu noble-backports main restricted universe multiverse' /etc/apt/sources.list.d/official-package-repositories.list
			fi
			if ! grep -q ftp.rz.uni-frankfurt.de /etc/apt/sources.list.d/official-package-repositories.list; then
				sed -i '/^deb http:\/\/packages.linuxmint.com zena main upstream import backport.*$/ideb https:\/\/ftp-stud.hs-esslingen.de\/pub\/Mirrors\/packages.linuxmint.com zena main upstream import backport\ndeb https:\/\/ftp.rz.uni-frankfurt.de\/pub\/mirrors\/linux-mint\/packages zena main upstream import backport' /etc/apt/sources.list.d/official-package-repositories.list
			fi
		fi
	fi

	echo "# Aktualisiere Paketlisten und installiere nala ..."
	apt-get update
	apt-get -y install nala
	nala full-upgrade -y

	# --- GRUB recordfail ----------------------------------------------------
	echo "# Passe GRUB an ..."
	sed -i "/recordfail_broken=/{s/1/0/}" /etc/grub.d/00_header
	update-grub

	# --- KDE Connect --------------------------------------------------------
	if [ "$opt_kdeconnect" = 1 ]; then
		pakete="$pakete kdeconnect"
	fi

	# --- Thunderbird / Evolution -------------------------------------------
	echo "# Konfiguriere Mail-Client ..."
	if [ "$opt_thunderbird" != 1 ]; then
		pakete="$pakete evolution"
		remove="$remove thunderbird*"
		sed -i 's/^.*x-scheme-handler\/mailto=thunderbird.desktop.*$/x-scheme-handler\/mailto=org.gnome.Evolution.desktop/' /etc/xdg/mimeapps.list 2>/dev/null
		sed -i 's/^.*"thunderbird.desktop",.*$/"org.gnome.Evolution.desktop",/' "$config/.config/cinnamon/spices/panel-launchers@cinnamon.org/18.json" 2>/dev/null
	else
		if grep -q "thunderbird" /etc/xdg/mimeapps.list 2>/dev/null; then
			sed -i 's/^.*x-scheme-handler\/mailto=thunderbird.desktop.*$/x-scheme-handler\/mailto=org.gnome.Evolution.desktop/' /etc/xdg/mimeapps.list
			sed -i 's/^.*"org.gnome.Evolution.desktop",.*$/"thunderbird.desktop",/' "$config/.config/cinnamon/spices/panel-launchers@cinnamon.org/18.json" 2>/dev/null
		fi
	fi
	mkdir -p /etc/xdg/
	cp -rf "$config/etc/xdg/mimeapps.list" /etc/xdg/mimeapps.list

	# --- Standard-Konfigurationsdateien in die Home-Verzeichnisse -----------
	# (Hinweis: In der Original-22-3.sh war diese Abfrage invertiert -
	#  "j" fuehrte zum NICHT-Schreiben. Hier bedeutet die Checkbox das,
	#  was ihr Text sagt: angehakt = Konfigs schreiben.)
	if [ "$opt_writeconfigs" = 1 ]; then
		echo "# Schreibe Standard-Konfigurationen in die Home-Verzeichnisse ..."
		for i in $(ls /home); do
			[ "$i" = "lost+found" ] && continue

			# Dayon
			mkdir -p "/home/$i/.dayon"
			cp -rf "$config/.dayon" "/home/$i"

			# Remotely / Dayon Assistant / Matrix
			mkdir -p "/home/$i/.local/share/applications"
			cp -f "$config"/.local/share/applications/* "/home/$i/.local/share/applications/" 2>/dev/null

			if [ ! -f "/home/$i/.config/Element/config.json" ]; then
				mkdir -p "/home/$i/.config/Element"
				cp -f "$config/.config/Element/config.json" "/home/$i/.config/Element/"
			fi

			# KDE Connect Cinnamon-Applet
			if [ "$opt_kdeconnect" = 1 ] && [ -f "/usr/bin/cinnamon" ]; then
				if [ ! -d "/home/$i/.config/cinnamon/spices/kdecapplet@joejoetv" ]; then
					mkdir -p "/home/$i/.config/cinnamon/spices/"
					cp -rf "$config/.config/cinnamon/spices/kdecapplet@joejoetv" "/home/$i/.config/cinnamon/spices/"
				fi
				if [ ! -d "/home/$i/.local/share/cinnamon/applets/kdecapplet@joejoetv" ]; then
					mkdir -p "/home/$i/.local/share/cinnamon/applets/"
					cp -rf "$config/.local/share/cinnamon/applets/kdecapplet@joejoetv" "/home/$i/.local/share/cinnamon/applets/"
				fi
			fi

			# Nemo-Actions
			nemofile="/home/$i/.config/nemo/actions-tree.json"
			if [ ! -f "$nemofile" ] || [ "$opt_ow_nemo" = 1 ]; then
				[ "$opt_ow_nemo" = 1 ] && rm -f "$nemofile"
				mkdir -p "/home/$i/.config/nemo/"
				cp -f "$config/.config/nemo/actions-tree.json" "/home/$i/.config/nemo/"
				if [ "$DE" != 1 ]; then
					sed -i -e 's/Senden an/send to/g' "/home/$i/.config/nemo/actions-tree.json"
				fi
			fi
			mkdir -p "/home/$i/.local/share/nemo/actions/"
			cp -rf "$config"/.local/share/nemo/actions/* "/home/$i/.local/share/nemo/actions/" 2>/dev/null

			# Gajim
			if [ ! -d "/home/$i/.config/gajim" ] || [ "$opt_ow_gajim" = 1 ]; then
				[ "$opt_ow_gajim" = 1 ] && rm -rf "/home/$i/.config/gajim"
				mkdir -p "/home/$i/.config"
				cp -rf "$config/.config/gajim" "/home/$i/.config"
			fi

			# Google Chrome
			if [ ! -d "/home/$i/.config/google-chrome" ] || [ "$opt_ow_chrome" = 1 ]; then
				[ "$opt_ow_chrome" = 1 ] && rm -rf "/home/$i/.config/google-chrome"
				mkdir -p "/home/$i/.config"
				cp -rf "$config/.config/google-chrome" "/home/$i/.config"
			fi

			# Vivaldi
			if [ ! -d "/home/$i/.config/vivaldi" ] || [ "$opt_ow_vivaldi" = 1 ]; then
				[ "$opt_ow_vivaldi" = 1 ] && rm -rf "/home/$i/.config/vivaldi"
				mkdir -p "/home/$i/.config"
				cp -rf "$config/.config/vivaldi" "/home/$i/.config"
			fi

			# Firefox
			if [ ! -d "/home/$i/.mozilla" ] || [ "$opt_ow_firefox" = 1 ]; then
				[ "$opt_ow_firefox" = 1 ] && rm -rf "/home/$i/.mozilla"
				cp -rf "$config/.mozilla" "/home/$i/"
			fi

			# Cinnamon-Applet/-Extension (Download)
			if [ ! -d "/home/$i/.local/share/cinnamon/applets/CinnVIIStarkMenu@NikoKrause" ]; then
				mkdir -p "/home/$i/.local/share/cinnamon/applets/"
				cp -rf "$config/.local/share/cinnamon/applets/CinnVIIStarkMenu@NikoKrause" "/home/$i/.local/share/cinnamon/applets/"
			fi
			if [ ! -d "/home/$i/.local/share/cinnamon/extensions/cinnamon-maximus@fmete" ]; then
				mkdir -p "/home/$i/.local/share/cinnamon/extensions/"
				cp -rf "$config/.local/share/cinnamon/extensions/cinnamon-maximus@fmete" "/home/$i/.local/share/cinnamon/extensions/"
			fi

			chown -R "$i:$i" "/home/$i"
		done
	fi

	# --- Nextcloud Desktop --------------------------------------------------
	[ "$opt_nextcloud" = 1 ] && pakete="$pakete nextcloud-desktop nemo-nextcloud"

	# --- HPLIP GUI ----------------------------------------------------------
	[ "$opt_hplip" = 1 ] && pakete="$pakete hplip-gui"

	# --- MangoHud -----------------------------------------------------------
	[ "$opt_mangohud" = 1 ] && pakete="$pakete mangohud"

	# --- Gaming AMD/Intel (Mesa) -------------------------------------------
	if [ "$opt_gaming" = 1 ]; then
		echo "# Fuege Mesa-PPA (kisak) hinzu ..."
		add-apt-repository -y ppa:kisak/kisak-mesa
		pakete="$pakete mesa-vulkan-drivers mesa-vulkan-drivers:i386"
	fi

	# --- Vivaldi ------------------------------------------------------------
	if [ "$opt_vivaldi" = 1 ]; then
		echo "# Richte Vivaldi-Repository ein ..."
		wget -qO- https://repo.vivaldi.com/archive/linux_signing_key.pub | gpg --dearmor | dd of=/usr/share/keyrings/vivaldi-browser.gpg
		echo "deb [signed-by=/usr/share/keyrings/vivaldi-browser.gpg arch=$(dpkg --print-architecture)] https://repo.vivaldi.com/archive/deb/ stable main" | dd of=/etc/apt/sources.list.d/vivaldi-archive.list
		pakete="$pakete vivaldi-stable"
	fi

	# --- Gajim --------------------------------------------------------------
	if [ "$opt_gajim" = 1 ]; then
		pakete="$pakete gajim-plugininstaller gajim-rostertweaks gajim-urlimagepreview gajim-omemo"
		if [ "$opt_gajim_autostart" = 1 ] && [ ! -f /etc/xdg/autostart/gajim.desktop ]; then
			{
				echo "[Desktop Entry]"
				echo "Type=Application"
				echo "Name=gajim"
				echo "Exec=gajim"
			} > /etc/xdg/autostart/gajim.desktop
		fi
	fi

	# --- Flathub + Rustdesk -------------------------------------------------
	echo "# Richte Flathub ein und installiere Rustdesk ..."
	flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
	flatpak -y install rustdesk

	# --- Roger Router (Fritz!Box) ------------------------------------------
	if [ "$opt_roger" = 1 ]; then
		echo "# Installiere Roger Router ..."
		flatpak -y install flathub org.tabos.roger
	fi

	# --- Laptop / TLP -------------------------------------------------------
	if [ "$opt_laptop" = 1 ]; then
		echo "# Installiere TLP / TLPUI ..."
		pakete="$pakete tlp tlp-rdw smartmontools ethtool"
		service="$service tlp.service"
		flatpak -y install flathub com.github.d4nj1.tlpui
	fi

	# --- Standard-Paketliste ------------------------------------------------
	pakete="$pakete synaptic krita krita-l10n ubuntu-restricted-extras pidgin nfs-common language-pack-kde-de libdvd-pkg smartmontools unoconv mediathekview python3-axolotl python3-gnupg language-pack-de fonts-symbola vlc libxvidcore4 libfaac0 gnupg2 lutris dayon kate konsole element-desktop qpwgraph kasts meld pavucontrol"
	remove="$remove casper"

	echo "# Entferne nicht benoetigte Pakete ..."
	nala purge -y $remove

	# --- Fremd-Repositories -------------------------------------------------
	echo "# Richte Element- und Dayon-Repositories ein ..."
	cd /root/ || cd /
	nala install -y wget apt-transport-https
	wget -O /usr/share/keyrings/element-io-archive-keyring.gpg https://packages.element.io/debian/element-io-archive-keyring.gpg
	echo "deb [signed-by=/usr/share/keyrings/element-io-archive-keyring.gpg] https://packages.element.io/debian/ default main" | tee /etc/apt/sources.list.d/element-io.list
	add-apt-repository -y ppa:regal/dayon

	IFS=" "
	for i in $rep; do
		add-apt-repository -y "$i"
	done

	echo "# Fuehre System-Upgrade durch ..."
	nala full-upgrade -y
	echo "# Installiere empfohlene Basis-Pakete ..."
	nala install -y --no-install-recommends $paketerec
	echo "# Installiere ausgewaehlte Pakete (das kann dauern) ..."
	nala install -y $pakete

	# --- Applikations-/Icon-/Bin-Dateien -----------------------------------
	echo "# Kopiere Anwendungsdateien ..."
	cp "$config"/usr/share/applications/* /usr/share/applications/ 2>/dev/null
	cp "$config"/usr/share/icons/* /usr/share/icons/ 2>/dev/null
	cp "$config"/usr/local/bin/* /usr/local/bin/ 2>/dev/null

	update-alternatives --set x-terminal-emulator /usr/bin/konsole 2>/dev/null

	echo "# Konfiguriere libdvd-pkg ..."
	dpkg-reconfigure libdvd-pkg

	if [ -n "$service" ]; then
		systemctl enable $service
	fi
	nala install --fix-broken -y

	# --- Auto-Update --------------------------------------------------------
	echo "# Aktiviere automatische Updates ..."
	if grep -q "Linux Mint" /etc/issue; then
		mintupdate-automation upgrade enable
		mintupdate-automation autoremove enable
	else
		dpkg-reconfigure -plow unattended-upgrades
		cp -f "$config/50unattended-upgrades" /etc/apt/apt.conf.d/50unattended-upgrades
	fi

	# --- Gast-Benutzer (LightDM) -------------------------------------------
	if [ -f /etc/lightdm/lightdm.conf ]; then
		if grep -q "allow-guest=" /etc/lightdm/lightdm.conf; then
			sed -i 's/^.*allow-guest=.*$/allow-guest=true/' /etc/lightdm/lightdm.conf
		else
			echo "/etc/lightdm/lightdm.conf existiert, aber allow-guest fehlt - lasse es unveraendert."
		fi
	else
		cp "$config/etc/lightdm/lightdm.conf" /etc/lightdm/ 2>/dev/null
	fi

	# --- Hardware-Probe -----------------------------------------------------
	if [ "$opt_hwprobe" = 1 ]; then
		echo "# Fuehre anonyme Hardware-Probe durch ..."
		hw-probe -all -upload
	fi
	nala purge -y hw-probe

	echo "# Root-Phase abgeschlossen."
	exit 0
fi

###############################################################################
# ============================  GUI-PHASE (User)  ==========================
###############################################################################

# --- Vorbedingungen ---------------------------------------------------------
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
	echo "Dieses Skript benoetigt eine grafische Sitzung (kein DISPLAY gefunden)." >&2
	exit 1
fi

if ! command -v zenity >/dev/null 2>&1; then
	if command -v pkexec >/dev/null 2>&1; then
		pkexec apt-get install -y zenity || {
			echo "zenity konnte nicht installiert werden." >&2
			exit 1
		}
	else
		echo "Weder zenity noch pkexec vorhanden - Abbruch." >&2
		exit 1
	fi
fi

if ! command -v pkexec >/dev/null 2>&1; then
	zenity --error --title="Fehlende Abhaengigkeit" \
		--text="pkexec (Polkit) wird benoetigt, ist aber nicht installiert.\nBitte 'policykit-1' installieren."
	exit 1
fi

# --- Sprache / Pfade --------------------------------------------------------
if grep -q de_ <<< "$LANG"; then DE=1; else DE=0; fi
SCRIPTDIR="$(dirname "$SELF")"
CONFIG="$SCRIPTDIR/download"
INVOKING_USER="$(id -un)"

if [ ! -d "$CONFIG" ]; then
	zenity --error --title="Konfigurationsordner fehlt" \
		--text="Der Ordner 'download' wurde neben dem Skript nicht gefunden:\n$CONFIG\n\nBitte das komplette Repository (inkl. 'download') entpacken."
	exit 1
fi

# --- Begruessung ------------------------------------------------------------
zenity --info --title="Linux Mint 22.3 Post-Installation" \
	--width=460 \
	--text="Willkommen!\n\nDieses Skript richtet ein frisch installiertes Linux Mint 22.3 (Zena) ein.\n\nGleich waehlst du die gewuenschten Komponenten aus. Anschliessend wird einmalig das Administrator-Passwort abgefragt (pkexec), und die Installation laeuft in einem Fortschrittsfenster." || exit 0

# --- Versionspruefung -------------------------------------------------------
if ! grep -q Zena /etc/issue; then
	zenity --question --title="Warnung: Andere Version" \
		--width=420 \
		--text="Du benutzt offenbar kein Linux Mint 22.3 (Zena).\n\nTrotzdem fortfahren?" || exit 0
fi

# --- Komponenten-Auswahl ----------------------------------------------------
has() { case "|$1|" in *"|$2|"*) return 0;; *) return 1;; esac; }

SEL=$(zenity --list --checklist \
	--title="Komponenten auswaehlen" \
	--width=640 --height=560 \
	--text="Waehle aus, was installiert/konfiguriert werden soll:" \
	--column="Aktiv" --column="Kennung" --column="Beschreibung" \
	--hide-column=2 --print-column=2 --separator="|" \
	TRUE  writeconfigs     "Standard-Konfigurationsdateien in die Home-Verzeichnisse schreiben" \
	FALSE kdeconnect       "KDE Connect (Zugriff von/auf das Handy)" \
	FALSE thunderbird      "Thunderbird statt Evolution als Mail-Client verwenden" \
	FALSE nextcloud        "Nextcloud Desktop Client (+ Nemo-Integration)" \
	FALSE hplip            "HP-Drucker: Fuellstand abfragen (hplip-gui)" \
	FALSE mangohud         "MangoHud (FPS-/Performance-Overlay)" \
	FALSE gaming           "Gaming auf AMD/Intel (aktuelle Mesa-Treiber, kisak-PPA)" \
	FALSE vivaldi          "Vivaldi Browser (Chromium-basiert)" \
	FALSE gajim            "Gajim (XMPP) + Plugins" \
	FALSE gajim_autostart  "Gajim fuer alle Nutzer automatisch starten" \
	FALSE roger            "Roger Router (Fritz!Box, ehem. ffgtk)" \
	FALSE laptop           "Laptop: Akkulaufzeit erhoehen (TLP + TLPUI)" \
	TRUE  hwprobe          "Am Ende anonyme Hardware-Probe an linux-hardware.org senden")

# Abbruch (Cancel) -> beenden
[ $? -ne 0 ] && exit 0

opt_writeconfigs=0; opt_kdeconnect=0; opt_thunderbird=0; opt_nextcloud=0
opt_hplip=0; opt_mangohud=0; opt_gaming=0; opt_vivaldi=0; opt_gajim=0
opt_gajim_autostart=0; opt_roger=0; opt_laptop=0; opt_hwprobe=0

has "$SEL" writeconfigs    && opt_writeconfigs=1
has "$SEL" kdeconnect      && opt_kdeconnect=1
has "$SEL" thunderbird     && opt_thunderbird=1
has "$SEL" nextcloud       && opt_nextcloud=1
has "$SEL" hplip           && opt_hplip=1
has "$SEL" mangohud        && opt_mangohud=1
has "$SEL" gaming          && opt_gaming=1
has "$SEL" vivaldi         && opt_vivaldi=1
has "$SEL" gajim           && opt_gajim=1
has "$SEL" gajim_autostart && opt_gajim_autostart=1
has "$SEL" roger           && opt_roger=1
has "$SEL" laptop          && opt_laptop=1
has "$SEL" hwprobe         && opt_hwprobe=1

# gajim_autostart nur sinnvoll mit gajim
[ "$opt_gajim" = 1 ] || opt_gajim_autostart=0

# --- Ueberschreib-Auswahl (nur wenn Konfigs geschrieben werden) -------------
opt_ow_firefox=0; opt_ow_chrome=0; opt_ow_vivaldi=0
opt_ow_gajim=0; opt_ow_nemo=0; opt_ow_cinnamon=0

if [ "$opt_writeconfigs" = 1 ]; then
	OW=$(zenity --list --checklist \
		--title="Vorhandene Konfigurationen ueberschreiben?" \
		--width=600 --height=420 \
		--text="Falls diese Konfigurationen bereits existieren:\nWelche duerfen ueberschrieben werden?\n(Nicht angehakt = vorhandene bleiben erhalten)" \
		--column="Ueberschreiben" --column="Kennung" --column="Beschreibung" \
		--hide-column=2 --print-column=2 --separator="|" \
		FALSE ow_firefox   "Firefox (~/.mozilla)" \
		FALSE ow_chrome    "Google Chrome (~/.config/google-chrome)" \
		FALSE ow_vivaldi   "Vivaldi (~/.config/vivaldi)" \
		FALSE ow_gajim     "Gajim (~/.config/gajim)" \
		FALSE ow_nemo      "Nemo-Actions (~/.config/nemo/actions-tree.json)" \
		FALSE ow_cinnamon  "Cinnamon-Spices (~/.config/cinnamon/spices)")
	# Cancel hier -> mit Standard (nichts ueberschreiben) fortfahren
	if [ $? -eq 0 ]; then
		has "$OW" ow_firefox  && opt_ow_firefox=1
		has "$OW" ow_chrome   && opt_ow_chrome=1
		has "$OW" ow_vivaldi  && opt_ow_vivaldi=1
		has "$OW" ow_gajim    && opt_ow_gajim=1
		has "$OW" ow_nemo     && opt_ow_nemo=1
		has "$OW" ow_cinnamon && opt_ow_cinnamon=1
	fi
fi

# --- Choices-Datei schreiben ------------------------------------------------
CHOICES="$(mktemp --tmpdir mint-setup-choices.XXXXXX)"
LOG="$(mktemp --tmpdir mint-setup-log.XXXXXX)"
trap 'rm -f "$CHOICES"' EXIT

{
	echo "CONFIG=$(printf '%q' "$CONFIG")"
	echo "DE=$DE"
	for v in opt_writeconfigs opt_kdeconnect opt_thunderbird opt_nextcloud \
		opt_hplip opt_mangohud opt_gaming opt_vivaldi opt_gajim \
		opt_gajim_autostart opt_roger opt_laptop opt_hwprobe \
		opt_ow_firefox opt_ow_chrome opt_ow_vivaldi opt_ow_gajim \
		opt_ow_nemo opt_ow_cinnamon; do
		echo "$v=${!v}"
	done
} > "$CHOICES"

# --- Root-Phase per pkexec + Fortschrittsfenster ----------------------------
pkexec bash "$SELF" --root-phase "$CHOICES" 2>&1 \
	| tee "$LOG" \
	| zenity --progress --pulsate --auto-close --no-cancel \
		--width=520 \
		--title="Installation laeuft" \
		--text="Starte Installation ..."

# PIPESTATUS[0] = Exit-Code von pkexec
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
	zenity --error --width=520 \
		--title="Fehler waehrend der Installation" \
		--text="Die privilegierte Installationsphase endete mit Fehlercode $RC.\n\nDetails findest du im Log-Fenster."
	zenity --text-info --title="Installations-Log" --width=800 --height=600 --filename="$LOG"
	exit "$RC"
fi

# ---------------------------------------------------------------------------
# ---  Benutzer-Phase: dconf/Konfiguration in der aktuellen User-Sitzung  ---
# ---------------------------------------------------------------------------
(
	echo "# Uebernehme Cinnamon-/Nemo-Einstellungen ..."

	# Cinnamon-Spices des aktuellen Nutzers
	if [ "$opt_writeconfigs" = 1 ]; then
		spicesdir="$HOME/.config/cinnamon/spices"
		if [ ! -d "$spicesdir" ] || [ "$opt_ow_cinnamon" = 1 ]; then
			[ "$opt_ow_cinnamon" = 1 ] && rm -rf "$spicesdir"
			mkdir -p "$spicesdir"
			cp -rf "$CONFIG"/.config/cinnamon/spices/* "$spicesdir/" 2>/dev/null
			dconf load /org/cinnamon/ < "$CONFIG/dconf/cinnamon-ubuntumate.conf"
			dconf write /org/cinnamon/enabled-extensions "['cinnamon-maximus@fmete']"
		fi
	fi

	echo "# Setze Terminal, Theme, Tastenkuerzel ..."
	dconf write /org/cinnamon/desktop/applications/terminal/exec "'konsole'"
	dconf load /org/cinnamon/desktop/peripherals/touchpad/ < "$CONFIG/dconf/touchpad.conf"
	dconf load /org/nemo/desktop/                          < "$CONFIG/dconf/desktop.conf"
	dconf load /org/cinnamon/desktop/keybindings/          < "$CONFIG/dconf/keybindings.conf"
	dconf write /org/cinnamon/desktop/wm/preferences/num-workspaces 2
	dconf write /org/cinnamon/desktop/interface/gtk-theme "'Mint-Y-Dark-Aqua'"
	dconf write /org/cinnamon/settings-daemon/plugins/color/night-light-enabled true

	if grep -q "Linux Mint" /etc/issue; then
		dconf load /com/linuxmint/updates/ < "$CONFIG/dconf/linuxmint-updates.conf"
	fi
	echo "# Benutzer-Einstellungen abgeschlossen."
) 2>&1 | tee -a "$LOG" \
	| zenity --progress --pulsate --auto-close --no-cancel \
		--width=520 --title="Einstellungen uebernehmen" \
		--text="Uebernehme persoenliche Einstellungen ..."

# --- Abschluss --------------------------------------------------------------
zenity --info --width=460 \
	--title="Fertig" \
	--text="Die Installation ist abgeschlossen.\n\nEin Neustart wird empfohlen, damit alle Einstellungen (Theme, Cinnamon, Auto-Updates) wirksam werden."

if zenity --question --width=420 \
	--title="Log anzeigen?" \
	--text="Moechtest du das vollstaendige Installations-Log ansehen?"; then
	zenity --text-info --title="Installations-Log" --width=800 --height=600 --filename="$LOG"
fi

exit 0

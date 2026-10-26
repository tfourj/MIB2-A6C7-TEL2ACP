#!/bin/sh
# Custom patches hook for the M.I.B. launcher
#
# Copy this file to mod/command.sh on the M.I.B. SD card. It runs the installer
# of each patch folder in custom-patches/ (TEL2ACP, JOKERBTN, ...).
# The M.I.B. launcher runs it at the end of its run, with $VOLUME set to the SD
# card mount point. GEM -> M.I.B. -> individual script also runs it, but without
# $VOLUME, so the SD1 slot is used then.
#
# CUSTOM_PATCHES selects what runs, one patch per line: <folder> [actions...]
# Leave it empty to run DEFAULT_ACTIONS for every folder in custom-patches/.
#   install     install the patch
#   gem-on      add the patch's screen to the GEM
#   uninstall   remove the patch again
#   status      only write the status to the patch's log
# Example:
#   CUSTOM_PATCHES="
#   TEL2ACP install gem-on
#   JOKERBTN uninstall
#   "
CUSTOM_PATCHES=""
DEFAULT_ACTIONS="install gem-on"

custom_gem=0
if [ -z "$VOLUME" ]; then
	VOLUME=/net/mmx/fs/sda0
	custom_gem=1
fi
custom_dir="$VOLUME/custom-patches"

# The installer is the .sh file in the patch folder that isn't this hook
custom_installer() {
	for custom_f in "$custom_dir/$1"/*.sh; do
		case "${custom_f##*/}" in
			command.sh) ;;
			*) if [ -f "$custom_f" ]; then echo "$custom_f"; return 0; fi ;;
		esac
	done
	return 1
}

custom_list="$CUSTOM_PATCHES"
if [ -z "$custom_list" ]; then
	for custom_d in "$custom_dir"/*; do
		if [ -d "$custom_d" ]; then
			custom_list="$custom_list
${custom_d##*/}"
		fi
	done
fi

if [ -z "$custom_list" ]; then
	echo "no patches found in $custom_dir"
fi

echo "$custom_list" | while read custom_name custom_actions; do
	case "$custom_name" in
		''|'#'*) continue ;;
	esac
	if ! custom_sh=$(custom_installer "$custom_name"); then
		echo "custom-patches/$custom_name: no installer found, skipped"
		continue
	fi
	for custom_action in ${custom_actions:-$DEFAULT_ACTIONS}; do
		/bin/sh "$custom_sh" "$custom_action" < /dev/null
	done
done

# GEM closes the output when the script ends, so leave time to read it
if [ $custom_gem = 1 ]; then
	sleep 10
fi

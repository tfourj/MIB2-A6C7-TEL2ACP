#!/bin/sh
# TEL2ACP hook for the M.I.B. launcher
#
# Copy this file to mod/command.sh on the M.I.B. SD card. The M.I.B. launcher
# runs it at the end of its run, with $VOLUME set to the SD card mount point.
# GEM -> M.I.B. -> individual script also runs it, but without $VOLUME, so
# the SD1 slot is used then.
#
# Set TEL2ACP_ACTIONS to what should happen, in order:
#   install     install the TEL -> CarPlay patch
#   gem-on      add the TEL2ACP screen to the GEM
#   uninstall   remove the patch again
#   status      only write the status to TEL2ACP/tel2acp.log
TEL2ACP_ACTIONS="install gem-on"

tel2acp_gem=0
if [ -z "$VOLUME" ]; then
	VOLUME=/net/mmx/fs/sda0
	tel2acp_gem=1
fi

for tel2acp_action in $TEL2ACP_ACTIONS; do
	/bin/sh "$VOLUME/TEL2ACP/tel2acp.sh" "$tel2acp_action"
done

# GEM closes the output when the script ends, so leave time to read it
if [ $tel2acp_gem = 1 ]; then
	sleep 10
fi

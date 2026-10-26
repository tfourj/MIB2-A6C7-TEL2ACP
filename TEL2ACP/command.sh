# TEL2ACP hook for the M.I.B. launcher
#
# Copy this file to mod/command.sh on the M.I.B. SD card. The M.I.B. launcher
# runs it at the end of its run, with $VOLUME set to the SD card mount point.
#
# Set TEL2ACP_ACTIONS to what should happen, in order:
#   install     install the TEL -> CarPlay patch
#   gem-on      add the TEL2ACP screen to the GEM
#   uninstall   remove the patch again
#   status      only write the status to TEL2ACP/tel2acp.log
TEL2ACP_ACTIONS="install gem-on"

for tel2acp_action in $TEL2ACP_ACTIONS; do
	/bin/sh "$VOLUME/TEL2ACP/tel2acp.sh" "$tel2acp_action"
done

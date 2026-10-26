# MIB2-A6C7-TEL2ACP

Makes the **TEL** button on an Audi MHI2 MMI open **Apple CarPlay** (or Android Auto), packaged as an add-on for the M.I.B. (More Incredible Bash) SD card.

| You press | Before | After |
|---|---|---|
| TEL | Phone menu | CarPlay |
| TEL while CarPlay is on screen | Phone menu | Phone menu |

All other buttons work as before.

> [!WARNING]
> **Not tested on a car yet.** The patch was built by reverse engineering one unit's firmware (see [docs/FINDINGS.md](docs/FINDINGS.md)).
> If something is wrong, the MMI screen software may not start (black screen, no GEM).
> A [boot guard](#safeguards) turns the patch off by itself after one failed start. SSH is still the best way to undo things. Use at your own risk.

## Requirements

- Audi MHI2 with firmware **`MHI2_ER_AU57x_K3663_1`** (MU1425), e.g. A6/A7 C7.
  The installer checks the firmware fingerprint and refuses to run on anything else.
- [M.I.B.](https://wiki.mibsolution.one/en/MHI2) on an SD card in the **SD1 slot** (`sda0`), with GEM enabled.
- SSH access to the unit (recommended, see [Setting up SSH](#setting-up-ssh)).

## What's in the `TEL2ACP` folder

| File | Purpose |
|---|---|
| `TEL2ACP.jar` | The patched `HardKeyManager` class |
| `TEL2ACP.jar.sha1` | Checksum the installer uses to spot a damaged copy |
| `tel2acp.sh` | Installer: `install`, `uninstall`, `restore`, `status`, `gem-on`, `gem-off` |
| `command.sh` | Hook to run the installer from the M.I.B. launcher (no SSH needed) |
| `esd/` | Optional GEM screen with Status / Install / Uninstall / Restore buttons |

## Install

1. Copy the `TEL2ACP` folder to the root of the M.I.B. SD card, next to `apps`, `esd` and `mod`.
2. Put the card in SD1 and run the installer, using **one** of these:

   **Over SSH**

   ```sh
   on -f rcc /net/mmx/fs/sda0/TEL2ACP/tel2acp.sh install
   ```

   **Without SSH**: copy `TEL2ACP/command.sh` to `mod/command.sh` on the card.
   Then run the M.I.B. installation again, the same way you installed M.I.B. (software update from the SD card).
   The M.I.B. launcher runs `mod/command.sh` at the end. Delete `mod/command.sh` afterwards.

3. Reboot the MMI (GEM → M.I.B. → Reboot).
4. Press TEL. CarPlay should open.

The installer writes everything it does to `TEL2ACP/tel2acp.log` on the SD card.

### Optional GEM screen

```sh
on -f rcc /net/mmx/fs/sda0/TEL2ACP/tel2acp.sh gem-on
```

After a reboot, GEM has a **TEL2ACP** screen with Status, Install, Uninstall and Restore.
It only works while the SD card is in SD1. `command.sh` turns it on by default.

## Uninstall

```sh
on -f rcc /net/mmx/fs/sda0/TEL2ACP/tel2acp.sh uninstall
```

Or use **Uninstall** in the GEM screen, or set `TEL2ACP_ACTIONS="uninstall"` in `mod/command.sh`. Reboot afterwards.

`restore` puts back the original `lsd.sh` saved on first install, in case `uninstall` can't clean it.

## Safeguards

**Before changing anything**, the installer checks that:

- the firmware is exactly `MHI2_ER_AU57x_K3663_1` (checksum of `/ifs/lsd.jxe`)
- `TEL2ACP.jar` on the card isn't damaged, and the copy on the unit matches it
- `lsd.sh` has the expected layout and no other `-Xbootclasspath/p:` mod is installed
- `/mnt/persist` is writable (the boot guard needs it)
- M.I.B. isn't busy flashing, backing up or rebooting

If any check fails, it stops and leaves the unit as it was.

**Boot guard.** Every time the MMI screen software starts, the `lsd.sh` block first leaves a flag in `/mnt/persist`, then loads the patch.
The patched class deletes the flag once it has loaded.
If the flag is still there at the next start, that start failed, so the block starts the stock software without the patch and remembers that.

**If the screen stays black after installing:**

1. Lock the car and leave it until the MMI shuts down, or restart the MMI. The next start runs without the patch.
2. Check `status` (GEM screen, SSH or `mod/command.sh`). It shows `DISABLED the patch after a failed start`.
3. Run `uninstall`. Keep `TEL2ACP/tel2acp.log` from the card, it shows what happened.

The boot guard only covers starting up. If the screen software ever crashed when you *press* TEL, it would come back with the patch still on.
Then stop using TEL and run `uninstall` from the GEM screen.
Running `install` again re-arms a disabled patch.

## Setting up SSH

No cable is needed if the car has a Wi-Fi hotspot (the A6 C7 this was built on does). SSH works over it.

1. Turn on the car's Wi-Fi hotspot in the MMI settings and connect your laptop to it.
2. Turn on SSH with M.I.B. (its `sshd` mod). The [M.I.B. wiki](https://wiki.mibsolution.one/en/MHI2) has the menu entry and the login details.
3. Connect from the laptop. In the system dump from this unit, the hotspot address of the MMI is `10.173.189.1`:

   ```sh
   ssh root@10.173.189.1
   ```

   If the laptop refuses the MMI's old key type, add `-o HostKeyAlgorithms=+ssh-rsa`.

If the car has no Wi-Fi hotspot, a USB-to-Ethernet adapter in the car's USB port works too. Check the M.I.B. wiki for supported adapters.

## What the installer changes

- Copies `TEL2ACP.jar` to `/mnt/app/eso/hmi/lsd/jars/`.
- Adds the boot guard block before the J9 start line in `/mnt/app/eso/hmi/lsd/lsd.sh`. Every line ends in `#TEL2ACP`.
  When the guard allows it, the block adds:

  ```sh
  BOOTCLASSPATH="$BOOTCLASSPATH -Xbootclasspath/p:$TEL2ACP_JAR"
  ```

  This loads the patched class ahead of the firmware's own copy in `lsd.jxe`. M.I.B.'s NavActiveIgnore patch works the same way.
- Uses three small flag files in `/mnt/persist` (`tel2acp_pending`, `tel2acp_loaded`, `tel2acp_disabled`).
- Saves the original `lsd.sh` as `lsd.sh.tel2acp.bak` on the unit and `TEL2ACP/backup/lsd.sh` on the card.

`-force` installs anyway when the firmware doesn't match or no `sha1sum` tool is found. A damaged jar is never installed.

## Build from source

Needs a JDK 8, because newer JDKs can't produce the old class format the MMI's J9 VM uses.

```bash
JAVA_HOME="/path/to/jdk8" ./build.sh
```

This rebuilds `TEL2ACP/TEL2ACP.jar` from `src/`. The classes in `stubs/` only stand in for firmware types at compile time and are not included in the jar.

## How it works

Every hard key goes through `de.audi.tghu.fwhmi.appmgr.HardKeyManager.triggerKeyEvent()`. TEL normally fires the state-machine event `HK_TEL` (103).
The patched class fires `SWITCH_TO_TERMINAL_MODE` (1903) instead. The firmware already uses that event when a connected phone takes over the screen.
If a CarPlay screen (240000–240009) is already showing, TEL fires `HK_TEL` as before.

Full analysis: [docs/FINDINGS.md](docs/FINDINGS.md).

## Credits

- M.I.B. by MIBonk and MIB-Wiki, for the SD card toolkit and the `-Xbootclasspath/p:` approach.
- zrnec and mrfixpl in [jilleb/mib2-toolbox#283](https://github.com/jilleb/mib2-toolbox/issues/283), for the first findings on Audi button mapping.

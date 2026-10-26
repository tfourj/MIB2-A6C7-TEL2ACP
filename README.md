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
> **Set up SSH (M.I.B. `sshd` mod) before installing** so you can undo it. Use at your own risk.

## Requirements

- Audi MHI2 with firmware **`MHI2_ER_AU57x_K3663_1`** (MU1425), e.g. A6/A7 C7.
  The installer checks the firmware fingerprint and refuses to run on anything else.
- [M.I.B.](https://wiki.mibsolution.one/en/MHI2) on an SD card in the **SD1 slot** (`sda0`), with GEM enabled.
- SSH access to the unit (recommended).

## What's in the `TEL2ACP` folder

| File | Purpose |
|---|---|
| `TEL2ACP.jar` | The patched `HardKeyManager` class |
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

If the MMI doesn't come back after installing, use SSH to put the original `lsd.sh` back:

```sh
on -f rcc /net/mmx/fs/sda0/TEL2ACP/tel2acp.sh restore
```

## What the installer changes

- Copies `TEL2ACP.jar` to `/mnt/app/eso/hmi/lsd/jars/`.
- Adds one line before the J9 start line in `/mnt/app/eso/hmi/lsd/lsd.sh`:

  ```sh
  BOOTCLASSPATH="$BOOTCLASSPATH -Xbootclasspath/p:$BASE_DIR/lsd/jars/TEL2ACP.jar" #TEL2ACP
  ```

  This loads the patched class ahead of the firmware's own copy in `lsd.jxe`. M.I.B.'s NavActiveIgnore patch works the same way.
- Saves the original `lsd.sh` as `lsd.sh.tel2acp.bak` on the unit and `TEL2ACP/backup/lsd.sh` on the card.

It stops without changing anything if the firmware doesn't match, if `lsd.sh` looks different than expected, or if another `-Xbootclasspath/p:` mod is already installed.
`-force` skips only the firmware check.

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

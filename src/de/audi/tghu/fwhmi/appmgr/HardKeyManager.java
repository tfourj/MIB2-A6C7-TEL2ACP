package de.audi.tghu.fwhmi.appmgr;

import java.io.File;
import java.io.FileOutputStream;

import de.audi.atip.base.IFrameworkAccess;
import de.audi.atip.hmi.HMIService;
import de.audi.atip.hmi.model.ButtonModel;
import de.audi.atip.log.LogChannel;

/**
 * Replacement for de.audi.tghu.fwhmi.appmgr.HardKeyManager from lsd.jxe
 * (MHI2_ER_AU57x_K3663_1, MU1425).
 *
 * Rebuilt 1:1 from the original bytecode. The only change is the TEL key
 * (hard-key model 4): it opens Apple CarPlay / terminal mode instead of the
 * phone menu. Pressing TEL while a terminal mode screen is shown falls back
 * to the original phone behaviour. When TEL opens CarPlay it also lights the
 * TEL key, because the terminal mode state never sets a key light itself.
 *
 * Loaded ahead of lsd.jxe with -Xbootclasspath/p:, so fields and method
 * signatures must stay identical to the original class.
 *
 * Boot guard: lsd.sh creates /mnt/persist/tel2acp_pending before starting
 * the HMI with this class. The constructor deletes it, which tells the next
 * lsd.sh run that this class loaded fine. If the flag is still there on the
 * next start, lsd.sh disables the patch and starts the stock HMI.
 */
public class HardKeyManager {

    private static final int HARDKEY_COUNT = 16;

    // System state machine events (de.audi.atip.statemachine.SMEventSystem)
    private static final int HK_TUNER = 101;
    private static final int HK_MEDIA = 102;
    private static final int HK_TEL = 103;
    private static final int HK_NAV = 104;
    private static final int HK_INFO = 105;
    private static final int HK_CAR = 106;
    private static final int HK_NET = 107;
    private static final int HK_SETTINGS = 111;
    private static final int HK_SETUP_RETURN = 151;
    private static final int HK_SETUP_CAR = 152;
    private static final int HK_SETUP_INFO = 153;
    private static final int HK_CAR_INFO = 154;
    private static final int MFL_MENU = 1374;
    private static final int HK_MENU = 1400;
    private static final int SWITCH_TO_TERMINAL_MODE = 1903;

    // TEL is ignored while this popup is shown (original behaviour)
    private static final int POPUP_TEL_BLOCKED = 250002;

    // Key light id of TEL, as the phone state machine passes it to KbdService
    private static final int HK_LIGHT_TEL = 4;

    // Terminal mode app id 24, screens 240000..240009 (TerminalModeScreenFactory)
    private static final int SCREEN_APP_DIVISOR = 10000;
    private static final int TERMINAL_MODE_APP_ID = 24;

    // Original log channel level and message ids
    private static final int LOG_LEVEL = 1000000;
    private static final int LOG_KEY_15 = 1264;
    private static final int LOG_UNKNOWN_KEY = 1265;
    private static final int LOG_FIRE_SM_EVENT = 1266;

    // Boot guard flags, shared with the lsd.sh block written by tel2acp.sh
    private static final String FLAG_PENDING = "/mnt/persist/tel2acp_pending";
    private static final String FLAG_LOADED = "/mnt/persist/tel2acp_loaded";

    private final IFrameworkAccess framework;
    private final LogChannel logChannel;
    private final ButtonModel[] hardkeys;

    public HardKeyManager(IFrameworkAccess framework, LogChannel logChannel) {
        this.framework = framework;
        this.logChannel = logChannel;
        this.hardkeys = new ButtonModel[HARDKEY_COUNT];
        for (int i = 0; i < HARDKEY_COUNT; i++) {
            this.hardkeys[i] = new ButtonModel(i + 1);
        }
        confirmBoot();
    }

    public void triggerKeyEvent(int terminalId, int key) {
        switch (key) {
            case 1:
                fireSMEvent(terminalId, HK_TUNER);
                break;
            case 2:
                fireSMEvent(terminalId, HK_MEDIA);
                break;
            case 3:
                fireSMEvent(terminalId, HK_NET);
                break;
            case 4:
                handleTelKey(terminalId);
                break;
            case 5:
                fireSMEvent(terminalId, HK_NAV);
                break;
            case 6:
                fireSMEvent(terminalId, HK_INFO);
                break;
            case 7:
                fireSMEvent(terminalId, HK_CAR);
                break;
            case 8:
                fireSMEvent(terminalId, HK_SETTINGS);
                break;
            case 9:
                fireSMEvent(terminalId, MFL_MENU);
                break;
            case 10:
                fireSMEvent(terminalId, HK_SETUP_RETURN);
                break;
            case 11:
                fireSMEvent(terminalId, HK_SETUP_CAR);
                break;
            case 12:
                fireSMEvent(terminalId, HK_SETUP_INFO);
                break;
            case 13:
                fireSMEvent(terminalId, HK_CAR_INFO);
                break;
            case 14:
                fireSMEvent(terminalId, HK_NET);
                break;
            case 15:
                getLogChannel().log(LOG_LEVEL, LOG_KEY_15);
                break;
            case 16:
                fireSMEvent(terminalId, HK_MENU);
                break;
            default:
                getLogChannel().log(LOG_LEVEL, LOG_UNKNOWN_KEY, (long) key);
                break;
        }
    }

    public ButtonModel[] getModels() {
        return this.hardkeys;
    }

    public ButtonModel getModel(int id) {
        if (id > 0 && id < this.hardkeys.length + 1) {
            return this.hardkeys[id - 1];
        }
        return null;
    }

    public ButtonModel getModel(int terminalId, int id) {
        return getModel(id);
    }

    /** TEL opens CarPlay; TEL again while CarPlay is on screen opens the phone menu. */
    private void handleTelKey(int terminalId) {
        HMIService hmi = getHmiService();
        if (hmi.getCurrentPopup() == POPUP_TEL_BLOCKED) {
            return;
        }
        if (hmi.getCurrentScreenID() / SCREEN_APP_DIVISOR == TERMINAL_MODE_APP_ID) {
            fireSMEvent(terminalId, HK_TEL);
        } else {
            fireSMEvent(terminalId, SWITCH_TO_TERMINAL_MODE);
            lightTelKey(terminalId);
        }
    }

    /** Lights TEL like the phone screen does. Never throws, the key press already went through. */
    private void lightTelKey(int terminalId) {
        try {
            this.framework.getKbdService().setHKIlluminationExclusive(terminalId, HK_LIGHT_TEL, true);
        } catch (Throwable t) {
            // A missing light must not break the TEL key
        }
    }

    /** Tells the lsd.sh boot guard that the patched class loaded. Never throws. */
    private static void confirmBoot() {
        try {
            new File(FLAG_PENDING).delete();
            new FileOutputStream(FLAG_LOADED).close();
        } catch (Throwable t) {
            // The guard only disables the patch, so a failed write must not stop the HMI
        }
    }

    private void fireSMEvent(int terminalId, int event) {
        getLogChannel().log(LOG_LEVEL, LOG_FIRE_SM_EVENT, (long) terminalId, (long) event);
        getHmiService().fireSMEvent(terminalId, event);
    }

    private HMIService getHmiService() {
        return this.framework.getHMIService();
    }

    private LogChannel getLogChannel() {
        return this.logChannel;
    }
}

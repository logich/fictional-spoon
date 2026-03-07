#include <furi.h>
#include <furi_hal.h>
#include <furi_hal_bt.h>
#include <gui/gui.h>
#include <gui/elements.h>
#include <input/input.h>
#include <notification/notification_messages.h>
#include <stdlib.h>
#include <string.h>

// Proximity UUID — matches ArenaConfiguration.prototype in the iOS app
// and BEACON_UUID in esp32/ibeacon/ibeacon.ino.
// UUID: B9407F30-F5F8-466E-AFF9-25556B57FE6D
static const uint8_t BEACON_UUID[16] = {
    0xB9, 0x40, 0x7F, 0x30,
    0xF5, 0xF8,
    0x46, 0x6E,
    0xAF, 0xF9,
    0x25, 0x55, 0x6B, 0x57, 0xFE, 0x6D,
};

// Measured RSSI at 1 metre — calibration value embedded in each packet.
// -59 dBm is the Apple-recommended default for standard beacons.
#define IBEACON_TX_POWER  ((int8_t)(-59))

// iBeacon advertisement data is always exactly 30 bytes:
//   3  Flags AD
//   27 Manufacturer Specific AD  (Apple header 4B + type 2B + UUID 16B + major 2B + minor 2B + power 1B)
#define ADV_DATA_LEN 30

// Letters and their minor values — must match ArenaConfiguration.prototype
// in the iOS app and the BEACON_MINOR mapping in esp32/ibeacon/ibeacon.ino.
//   minor 0 = A   (bottom center)
//   minor 1 = E   (left wall, halfway)
//   minor 2 = C   (top center)
//   minor 3 = B   (right wall, halfway)
static const char* ARENA_LETTERS[] = { "A", "E", "C", "B" };
#define LETTER_COUNT ((uint8_t)(sizeof(ARENA_LETTERS) / sizeof(ARENA_LETTERS[0])))

typedef struct {
    Gui* gui;
    ViewPort* view_port;
    FuriMessageQueue* event_queue;
    NotificationApp* notification;
    bool advertising;
    uint8_t letter_idx; // index into ARENA_LETTERS; minor = letter_idx + 1
    uint16_t major;     // arena / venue identifier, 1–65535
} IBeaconApp;

// ------------------------------------------------------------
// Build the raw advertisement payload.
// iBeacon format (Apple Proximity Beacon Specification):
//
//   [Flags AD]
//   Len  0x02
//   Type 0x01  (Flags)
//   Val  0x06  (LE General Discoverable | BR/EDR Not Supported)
//
//   [Manufacturer Specific AD]
//   Len  0x1A  (26 bytes follow)
//   Type 0xFF
//   0x4C 0x00  (Apple Inc., little-endian)
//   0x02 0x15  (iBeacon subtype + subtype length = 21 bytes)
//   UUID[16]   (big-endian, as set in your iOS app)
//   Major[2]   (big-endian)
//   Minor[2]   (big-endian)
//   TxPower    (signed, RSSI at 1 m)
// ------------------------------------------------------------
static void build_adv_data(uint8_t buf[ADV_DATA_LEN], const IBeaconApp* app) {
    uint8_t i = 0;

    // Flags
    buf[i++] = 0x02;
    buf[i++] = 0x01;
    buf[i++] = 0x06;

    // Manufacturer specific (26 bytes follow)
    buf[i++] = 0x1A;
    buf[i++] = 0xFF;
    buf[i++] = 0x4C; // Apple Inc. (little-endian low byte)
    buf[i++] = 0x00; // Apple Inc. (high byte)
    buf[i++] = 0x02; // iBeacon subtype
    buf[i++] = 0x15; // Remaining length: 21 bytes

    // UUID (16 bytes)
    memcpy(&buf[i], BEACON_UUID, 16);
    i += 16;

    // Major (big-endian)
    buf[i++] = (uint8_t)(app->major >> 8);
    buf[i++] = (uint8_t)(app->major & 0xFF);

    // Minor = letter index (0=A, 1=E, 2=C, 3=B), big-endian
    uint16_t minor = (uint16_t)app->letter_idx;
    buf[i++] = (uint8_t)(minor >> 8);
    buf[i++] = (uint8_t)(minor & 0xFF);

    // Measured TX power
    buf[i++] = (uint8_t)IBEACON_TX_POWER;

    furi_assert(i == ADV_DATA_LEN);
}

// ------------------------------------------------------------
// BLE helpers
// ------------------------------------------------------------
static bool beacon_start(IBeaconApp* app) {
    uint8_t adv_data[ADV_DATA_LEN];
    build_adv_data(adv_data, app);

    furi_hal_bt_extra_beacon_stop(); // stop any prior session first

    GapExtraBeaconConfig cfg = {
        .min_adv_interval_ms = 200,
        .max_adv_interval_ms = 200,
        .adv_channel_map     = GapAdvChannelMapAll,
        .adv_power_level     = GapAdvPowerLevel_0dBm,
        .address_type        = GapAddressTypePublic,
    };

    if(!furi_hal_bt_extra_beacon_set_config(&cfg)) return false;
    if(!furi_hal_bt_extra_beacon_set_data(adv_data, ADV_DATA_LEN)) return false;
    return furi_hal_bt_extra_beacon_start();
}

static void beacon_stop(void) {
    furi_hal_bt_extra_beacon_stop();
}

// ------------------------------------------------------------
// GUI draw callback
// Layout (128 × 64 px):
//   y= 9  Title
//   y=18  UUID (first 8 hex chars + "…")
//   y=28  Arena (major) — Up/Down to change
//   y=38  Letter (minor) — Left/Right to cycle
//   y=48  separator
//   y=58  status line / hint
// ------------------------------------------------------------
static void draw_cb(Canvas* canvas, void* ctx) {
    IBeaconApp* app = (IBeaconApp*)ctx;
    char buf[32];

    canvas_clear(canvas);

    // Title
    canvas_set_font(canvas, FontPrimary);
    canvas_draw_str(canvas, 0, 9, "iBeacon Emulator");

    canvas_set_font(canvas, FontSecondary);

    // UUID (abbreviated to first 4 bytes to fit the screen)
    snprintf(buf, sizeof(buf), "UUID: %02X%02X%02X%02X...",
             BEACON_UUID[0], BEACON_UUID[1], BEACON_UUID[2], BEACON_UUID[3]);
    canvas_draw_str(canvas, 0, 19, buf);

    // Major — navigated with Up / Down
    snprintf(buf, sizeof(buf), "Arena (major): %u", app->major);
    canvas_draw_str(canvas, 0, 29, buf);
    canvas_draw_str(canvas, 120, 29, app->major > 1    ? "\x75" : " "); // up arrow hint
    canvas_draw_str(canvas, 120, 29, ""); // placeholder — arrows drawn via elements below

    // Minor — navigated with Left / Right
    snprintf(buf, sizeof(buf), "Letter: %s (minor=%u)",
             ARENA_LETTERS[app->letter_idx], app->letter_idx);
    canvas_draw_str(canvas, 0, 39, buf);

    // Separator
    canvas_draw_line(canvas, 0, 43, 128, 43);

    // Status / hint row
    canvas_set_font(canvas, FontPrimary);
    if(app->advertising) {
        canvas_draw_str(canvas, 0,  57, "[OK] Stop");
        canvas_draw_str(canvas, 80, 57, "* TX *");
    } else {
        canvas_draw_str(canvas, 0,  57, "[OK] Start");
    }

    // Navigation arrows (drawn with elements helper if available, otherwise text)
    elements_button_left(canvas, "");   // renders a "<" glyph on the left edge
    elements_button_right(canvas, "");  // renders a ">" glyph on the right edge
}

static void input_cb(InputEvent* event, void* ctx) {
    FuriMessageQueue* queue = (FuriMessageQueue*)ctx;
    furi_message_queue_put(queue, event, FuriWaitForever);
}

// ------------------------------------------------------------
// Entry point
// ------------------------------------------------------------
int32_t ibeacon_app_main(void* p) {
    UNUSED(p);

    IBeaconApp* app = malloc(sizeof(IBeaconApp));
    app->letter_idx  = 0;    // "A"
    app->major       = 1;    // first / only arena
    app->advertising = false;

    app->event_queue = furi_message_queue_alloc(8, sizeof(InputEvent));
    app->view_port   = view_port_alloc();
    view_port_draw_callback_set(app->view_port, draw_cb, app);
    view_port_input_callback_set(app->view_port, input_cb, app->event_queue);

    app->gui = furi_record_open(RECORD_GUI);
    gui_add_view_port(app->gui, app->view_port, GuiLayerFullscreen);

    app->notification = furi_record_open(RECORD_NOTIFICATION);

    // Main loop
    InputEvent event;
    bool running = true;
    while(running) {
        if(furi_message_queue_get(app->event_queue, &event, 100) == FuriStatusOk) {
            if(event.type == InputTypeShort || event.type == InputTypeRepeat) {
                switch(event.key) {

                case InputKeyBack:
                    running = false;
                    break;

                case InputKeyOk:
                    if(app->advertising) {
                        beacon_stop();
                        app->advertising = false;
                        notification_message(app->notification, &sequence_blink_blue_10);
                    } else {
                        if(beacon_start(app)) {
                            app->advertising = true;
                            notification_message(app->notification, &sequence_blink_green_10);
                        } else {
                            notification_message(app->notification, &sequence_error);
                        }
                    }
                    break;

                case InputKeyLeft:
                    // Cycle to previous letter; restart advertising if active
                    if(app->letter_idx == 0)
                        app->letter_idx = LETTER_COUNT - 1;
                    else
                        app->letter_idx--;
                    if(app->advertising) beacon_start(app); // update payload
                    break;

                case InputKeyRight:
                    // Cycle to next letter
                    app->letter_idx = (uint8_t)((app->letter_idx + 1) % LETTER_COUNT);
                    if(app->advertising) beacon_start(app);
                    break;

                case InputKeyUp:
                    if(app->major < 65535) app->major++;
                    if(app->advertising) beacon_start(app);
                    break;

                case InputKeyDown:
                    if(app->major > 1) app->major--;
                    if(app->advertising) beacon_start(app);
                    break;

                default:
                    break;
                }
            }
        }
        view_port_update(app->view_port);
    }

    // Cleanup
    if(app->advertising) beacon_stop();

    furi_record_close(RECORD_NOTIFICATION);
    gui_remove_view_port(app->gui, app->view_port);
    furi_record_close(RECORD_GUI);
    view_port_free(app->view_port);
    furi_message_queue_free(app->event_queue);
    free(app);

    return 0;
}

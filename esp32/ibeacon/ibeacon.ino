/*
 * Dressage Caller — ESP32 iBeacon Transmitter
 *
 * Broadcasts an iBeacon advertisement matching the app's
 * ArenaConfiguration.prototype settings.
 *
 * CONFIGURATION:
 *   Set BEACON_MINOR below to match the arena letter for this device:
 *     4 = A  (bottom center)
 *     5 = E  (left wall, middle)
 *     6 = C  (top center)
 *     7 = B  (right wall, middle)
 *
 * Hardware: Any ESP32 dev board (ESP32, ESP32-S3, ESP32-C3, etc.)
 * Framework: Arduino with ESP32 BLE Arduino library
 *
 * Install:
 *   1. In Arduino IDE, add ESP32 board support:
 *      File → Preferences → Additional Board Manager URLs:
 *      https://espressif.github.io/arduino-esp32/package_esp32_index.json
 *   2. Board Manager → install "esp32 by Espressif Systems"
 *   3. Select your board (e.g. "ESP32 Dev Module")
 *   4. Set BEACON_MINOR below, then Upload
 */

#include <BLEDevice.h>

// ── Configuration ──────────────────────────────────────────────────
#define BEACON_MAJOR      1

// >>> CHANGE THIS PER DEVICE <<<
// 4=A, 5=E, 6=C, 7=B
#define BEACON_MINOR      5

// Measured power: RSSI at 1 meter (calibrate per-device if needed)
#define MEASURED_POWER    (-59)

// Advertising interval in milliseconds
#define ADV_INTERVAL_MS   100

// Onboard LED pin (GPIO 2 on most ESP32 dev boards)
#define LED_PIN           2
// ───────────────────────────────────────────────────────────────────

// Hand-built iBeacon advertisement — 30 bytes, exact Apple spec format.
static uint8_t advData[] = {
  // AD struct 1: Flags
  0x02, 0x01, 0x06,

  // AD struct 2: Manufacturer Specific Data (iBeacon)
  0x1A,       // length: 26 bytes follow
  0xFF,       // AD type: Manufacturer Specific
  0x4C, 0x00, // Apple company ID (little-endian)
  0x02, 0x15, // iBeacon type (0x02), data length (0x15 = 21)

  // Proximity UUID: F7826DA6-4FA2-4E98-8024-BC5B71E0893E (Kontakt factory default, big-endian)
  0xF7, 0x82, 0x6D, 0xA6,
  0x4F, 0xA2,
  0x4E, 0x98,
  0x80, 0x24,
  0xBC, 0x5B, 0x71, 0xE0, 0x89, 0x3E,

  // Major (big-endian)
  (BEACON_MAJOR >> 8) & 0xFF, BEACON_MAJOR & 0xFF,

  // Minor (big-endian)
  (BEACON_MINOR >> 8) & 0xFF, BEACON_MINOR & 0xFF,

  // Measured Power (signed int8)
  (uint8_t)MEASURED_POWER
};

static esp_ble_adv_params_t advParams = {
  .adv_int_min       = (uint16_t)(ADV_INTERVAL_MS * 1000 / 625),
  .adv_int_max       = (uint16_t)(ADV_INTERVAL_MS * 1000 / 625),
  .adv_type          = ADV_TYPE_NONCONN_IND,
  .own_addr_type     = BLE_ADDR_TYPE_PUBLIC,
  .channel_map       = ADV_CHNL_ALL,
  .adv_filter_policy = ADV_FILTER_ALLOW_SCAN_ANY_CON_ANY,
};

void gap_cb(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param) {
  if (event == ESP_GAP_BLE_ADV_DATA_RAW_SET_COMPLETE_EVT) {
    Serial.println("Raw data set, starting advertising...");
    esp_ble_gap_start_advertising(&advParams);
  } else if (event == ESP_GAP_BLE_ADV_START_COMPLETE_EVT) {
    Serial.printf("Advertising start result: %d\n", param->adv_start_cmpl.status);
  }
}

void setup() {
  Serial.begin(115200);

  const char* letterNames[] = {"H", "M", "K", "F", "A", "E", "C", "B"};
  Serial.printf("\n=== Dressage iBeacon ===\n");
  Serial.printf("Letter: %s (minor %d)\n",
                BEACON_MINOR < 8 ? letterNames[BEACON_MINOR] : "?",
                BEACON_MINOR);
  Serial.printf("Major:  %d  Minor: %d\n", BEACON_MAJOR, BEACON_MINOR);
  Serial.printf("TxPow:  %d dBm\n", MEASURED_POWER);

  // Dump raw bytes for verification
  Serial.printf("ADV (%d bytes):", sizeof(advData));
  for (unsigned int i = 0; i < sizeof(advData); i++) {
    Serial.printf(" %02X", advData[i]);
  }
  Serial.println();

  pinMode(LED_PIN, OUTPUT);

  // Init BLE stack only — don't use BLEAdvertising at all
  BLEDevice::init("");

  // Register our own GAP callback and set raw data
  esp_ble_gap_register_callback(gap_cb);
  esp_err_t err = esp_ble_gap_config_adv_data_raw(advData, sizeof(advData));
  Serial.printf("Config result: %d\n", err);
}

void loop() {
  digitalWrite(LED_PIN, LOW);   // OFF 
  delay(2000);
  digitalWrite(LED_PIN, HIGH);  // ON (active-low)
  delay(2000);
}

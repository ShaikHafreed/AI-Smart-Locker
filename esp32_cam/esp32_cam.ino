#include <Arduino.h>
#include "esp_camera.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

#include "board_config.h"

// ===========================
// WiFi / Server
// ===========================
const char *ssid     = "AirFiber-VZS0-SR";
const char *password = "11223344";

const char* serverIP   = "192.168.31.229";
const uint16_t serverPort = 5000;
const char* deviceToken   = "ESP32_DEVICE_SECRET_TOKEN_2026"; // must match DEVICE_TOKEN in backend/app.py

// ===========================
// Pins
// ===========================
#define REED_PIN    13   // door reed switch (INPUT_PULLUP, LOW = closed)
#define BUTTON_PIN  14   // single physical button: short press = mute, long press = full reset
#define BUZZER_PIN  15   // active-LOW buzzer

bool alarmMuted       = false;
bool doorTriggered    = false;
bool intruderDetected = false;

bool cameraFaultActive = false;
int  cameraFailStreak  = 0;

unsigned long alarmStartTime      = 0;      // when the buzzer started, for the 30s auto-timeout
const unsigned long ALARM_TIMEOUT_MS = 30000;

const unsigned long LONG_PRESS_MS = 3000;   // hold this long to trigger a full reset instead of mute
unsigned long lastFaultBeep  = 0;

void startCameraServer();
void setupLedFlash();

// =====================================================
// JSON matching helper - Flask's spacing can vary by
// version, so strip spaces before substring-matching.
// =====================================================
String compact(const String &s) {
  String out = s;
  out.replace(" ", "");
  return out;
}

// =====================================================
// Buzzer / reset / fault handling
// =====================================================
void buzzerOn()  { digitalWrite(BUZZER_PIN, LOW);  }
void buzzerOff() { digitalWrite(BUZZER_PIN, HIGH); }

// One physical button, two functions:
//   - short press (released before LONG_PRESS_MS): mute the current alarm
//   - long press (held for LONG_PRESS_MS+): full reset - kills the buzzer and
//     reboots, so camera, WiFi and every fault/alarm flag come back clean.
//     Works whether the buzzer is stuck on or the camera has stopped
//     capturing - both get fixed by the reboot.
void handleButton() {
  static bool wasPressed      = false;
  static unsigned long pressStart = 0;
  static bool longPressFired  = false;

  bool isPressed = (digitalRead(BUTTON_PIN) == LOW);

  if (isPressed && !wasPressed) {
    pressStart     = millis();
    longPressFired = false;
  }

  if (isPressed && !longPressFired && millis() - pressStart >= LONG_PRESS_MS) {
    longPressFired = true;
    Serial.println("[RESET] Button held - resetting full hardware function...");
    buzzerOff();
    delay(50);
    ESP.restart();
  }

  if (!isPressed && wasPressed && !longPressFired) {
    alarmMuted = true;
    Serial.println("ALARM MUTED");
  }

  wasPressed = isPressed;
}

void enterCameraFault() {
  cameraFaultActive = true;
  Serial.println("[FAULT] Camera not capturing images. Press RESET to recover.");
  buzzerOn(); delay(150); buzzerOff(); delay(150);
  buzzerOn(); delay(150); buzzerOff();
}

void faultBeepNonBlocking() {
  unsigned long now = millis();
  if (now - lastFaultBeep >= 2000) {
    lastFaultBeep = now;
    buzzerOn(); delay(120); buzzerOff();
  }
}

// Retries a capture a few times before giving up on this event.
camera_fb_t* captureWithRetry(int maxAttempts, int delayMs) {
  for (int i = 1; i <= maxAttempts; i++) {
    camera_fb_t* fb = esp_camera_fb_get();
    if (fb) return fb;
    Serial.printf("Capture attempt %d/%d failed.\n", i, maxAttempts);
    delay(delayMs);
  }
  return nullptr;
}

// =====================================================
// HTTP - multipart image upload (matches Flask's
// request.files["image"] on /verify and /evidence)
// =====================================================
bool postImage(const char* endpointPath, camera_fb_t* fb, String &responseOut) {
  if (WiFi.status() != WL_CONNECTED) return false;

  String boundary = "----ESP32CAMBoundary7MA4YWxkTrZu0gW";
  String head = "--" + boundary + "\r\n"
                "Content-Disposition: form-data; name=\"image\"; filename=\"capture.jpg\"\r\n"
                "Content-Type: image/jpeg\r\n\r\n";
  String tail = "\r\n--" + boundary + "--\r\n";

  size_t totalLen = head.length() + fb->len + tail.length();
  uint8_t* body = (uint8_t*)malloc(totalLen);
  if (!body) {
    Serial.println("malloc failed for HTTP body");
    return false;
  }
  memcpy(body, head.c_str(), head.length());
  memcpy(body + head.length(), fb->buf, fb->len);
  memcpy(body + head.length() + fb->len, tail.c_str(), tail.length());

  HTTPClient http;
  String url = String("http://") + serverIP + ":" + String(serverPort) + endpointPath;
  http.begin(url);
  // DeepFace (ArcFace + MTCNN) can take several seconds per comparison on CPU,
  // especially the first request after the backend starts - the 5s library
  // default reads as a timeout well before the backend actually responds.
  http.setTimeout(20000);
  http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary);
  http.addHeader("Authorization", String("Device ") + deviceToken);

  int code = http.POST(body, totalLen);
  bool ok = code > 0;
  if (ok) {
    responseOut = http.getString();
  } else {
    Serial.printf("HTTP POST %s failed: %s\n", endpointPath, http.errorToString(code).c_str());
  }
  http.end();
  free(body);
  return ok;
}

bool getPendingStatus(String &responseOut) {
  if (WiFi.status() != WL_CONNECTED) return false;
  HTTPClient http;
  String url = String("http://") + serverIP + ":" + String(serverPort) + "/pending_access";
  http.begin(url);
  http.setTimeout(10000);
  http.addHeader("Authorization", String("Device ") + deviceToken);
  int code = http.GET();
  bool ok = code > 0;
  if (ok) responseOut = http.getString();
  http.end();
  return ok;
}

// =====================================================
// Capture + verify a visitor against /verify
// =====================================================
String verifyVisitor() {
  camera_fb_t *fb = captureWithRetry(3, 300);
  if (!fb) {
    cameraFailStreak++;
    Serial.printf("Camera Capture Failed (streak %d)\n", cameraFailStreak);
    if (cameraFailStreak >= 3) enterCameraFault();
    return "";
  }
  cameraFailStreak = 0;

  Serial.println("Uploading Image...");
  String response;
  bool sent = postImage("/verify", fb, response);
  esp_camera_fb_return(fb);

  if (!sent) {
    Serial.println("Upload Failed (network/server).");
    return "";
  }

  Serial.print("HTTP Response: ");
  Serial.println(response);
  return response;
}

void captureEvidenceImages() {
  Serial.println("EVIDENCE MODE STARTED");

  for (int i = 0; i < 10; i++) {
    handleButton();
    Serial.print("Evidence Image ");
    Serial.println(i + 1);

    camera_fb_t *fb = captureWithRetry(2, 300);
    if (fb) {
      String resp;
      postImage("/evidence", fb, resp);
      esp_camera_fb_return(fb);
    } else {
      Serial.println("Evidence capture failed.");
    }
    delay(1000);
  }

  Serial.println("EVIDENCE MODE FINISHED");
}

// Polls /pending_access until the owner approves/rejects or 30s pass.
void waitForOwnerDecision() {
  Serial.println("WAITING FOR OWNER DECISION...");

  unsigned long startTime = millis();
  bool decisionReceived = false;

  while (millis() - startTime < 30000) {
    handleButton();

    String status;
    if (getPendingStatus(status)) {
      Serial.println(status);
      String c = compact(status);

      if (c.indexOf("\"status\":\"APPROVED\"") >= 0) {
        Serial.println("OWNER APPROVED ACCESS");
        intruderDetected = false;
        buzzerOff();
        decisionReceived = true;
        break;
      }

      if (c.indexOf("\"status\":\"REJECTED\"") >= 0) {
        Serial.println("OWNER REJECTED ACCESS");
        intruderDetected = true;
        alarmStartTime   = millis();
        buzzerOn();
        captureEvidenceImages();
        decisionReceived = true;
        break;
      }
    }

    delay(1000);
  }

  if (!decisionReceived) {
    Serial.println("NO RESPONSE FROM OWNER");
    intruderDetected = true;
    alarmStartTime   = millis();
    buzzerOn();
  }
}

// =====================================================
// Camera init with retry (camera can fail on underpowered USB)
// =====================================================
bool initCameraOnce() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk  = XCLK_GPIO_NUM;
  config.pin_pclk  = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href  = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn  = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 10000000; // lower than the usual 20MHz - reduces the camera's
                                   // own current draw during init, on top of the reduced
                                   // WiFi TX power, to buy more margin on a weak supply
  config.pixel_format  = PIXFORMAT_JPEG;
  config.frame_size    = FRAMESIZE_QVGA;
  config.jpeg_quality  = 12;
  config.fb_count       = 1;

  return esp_camera_init(&config) == ESP_OK;
}

void initCameraWithRetry() {
  const int maxAttempts = 3;
  for (int i = 1; i <= maxAttempts; i++) {
    Serial.printf("Camera init attempt %d/%d...\n", i, maxAttempts);
    if (initCameraOnce()) {
      Serial.println("Camera ready.");
      return;
    }
    Serial.println("Camera init failed.");
    if (i < maxAttempts) delay(5000);
  }
  Serial.println("Camera init failed after all attempts.");
  enterCameraFault();
}

void setup() {
  // AI-Thinker ESP32-CAM boards commonly trip the brownout detector on the
  // camera's init current inrush even on adequate power - disabling it stops
  // the reset-loop. This does not fix a genuinely weak supply; still power
  // the 5V pin directly (not through the FTDI adapter) and add a bulk
  // capacitor across 5V/GND if resets or capture failures continue.
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);

  Serial.begin(115200);
  Serial.setDebugOutput(true);
  Serial.println();

  pinMode(REED_PIN, INPUT_PULLUP);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);
  buzzerOff();

  delay(300); // let the supply settle after the initial boot current draw,
              // before the camera's own init current spike hits it

  initCameraWithRetry(); // no longer aborts setup() on failure - WiFi still comes up
                          // so the board stays reachable and RESET can recover it

  // Lower TX power before the radio powers up - WiFi's current draw on top of
  // an already-running camera is what's tipping a marginal supply over the edge.
  // This buys headroom; a proper 5V supply (not through the FTDI adapter) is
  // still the real fix if crashes continue.
  WiFi.mode(WIFI_STA);
  WiFi.setTxPower(WIFI_POWER_7dBm);

  WiFi.begin(ssid, password);
  Serial.print("Connecting WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.println("WiFi Connected");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());

  startCameraServer();
  Serial.println("System Ready");
}

void loop() {
  handleButton();

  if (cameraFaultActive) {
    faultBeepNonBlocking();
    delay(50);
    return;
  }

  int doorState = digitalRead(REED_PIN);

  // ===================
  // Door Closed
  // ===================
  if (doorState == LOW) {
    doorTriggered    = false;
    alarmMuted       = false;
    intruderDetected = false;
    buzzerOff();
  }
  // ===================
  // Door Open
  // ===================
  else {
    if (!doorTriggered) {
      Serial.println("DOOR OPEN DETECTED");

      String result = verifyVisitor();
      String c = compact(result);

      if (c.indexOf("\"verified\":true") >= 0) {
        Serial.println("OWNER VERIFIED - ACCESS GRANTED");
        intruderDetected = false;
      } else if (c.indexOf("\"verified\":false") >= 0) {
        intruderDetected = false; // set true only if owner actually rejects/times out
        waitForOwnerDecision();
      } else {
        Serial.println("Verify request failed (network/server) - no alarm triggered.");
      }

      doorTriggered = true;
    }

    // Auto-clear the alarm 30s after it started, even if the door stays open
    // and nobody presses the button - device returns to normal on its own.
    if (intruderDetected && millis() - alarmStartTime >= ALARM_TIMEOUT_MS) {
      intruderDetected = false;
      Serial.println("ALARM TIMEOUT - returning to normal");
    }

    if (intruderDetected && !alarmMuted) {
      buzzerOn();
    } else {
      buzzerOff();
    }
  }

  delay(200);
}

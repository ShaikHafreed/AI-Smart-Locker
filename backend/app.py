from flask import (
    Flask,
    request,
    jsonify,
    send_file,
    send_from_directory
)

from flask_cors import CORS

from deepface import DeepFace

from datetime import datetime

from fcm_service import send_notification

import requests
import sqlite3
import os
import uuid

# ==========================================
# APP
# ==========================================

app = Flask(__name__)
CORS(app)

# ==========================================
# NETWORK CONFIG
# ==========================================

SERVER_IP = "192.168.31.172"

# ==========================================
# TELEGRAM
# ==========================================

BOT_TOKEN = os.environ.get("LOCKER_BOT_TOKEN", "")
CHAT_ID = os.environ.get("LOCKER_CHAT_ID", "")

# ==========================================
# PATHS
# ==========================================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
OWNER_FOLDER = os.path.join(BASE_DIR, "owner_faces")
DATABASE_FILE = os.path.join(BASE_DIR, "locker.db")

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(OWNER_FOLDER, exist_ok=True)

# ==========================================
# RUNTIME STORAGE
# ==========================================

mobile_token = ""

pending_access = {
    "status": "NONE",
    "result": "",
    "time": "",
    "image": "",
    "similarity": ""
}

# ==========================================
# GLOBAL VARIABLES
# ==========================================

access_status = "WAITING"

VISITORS_FOLDER = UPLOAD_FOLDER
DB_PATH = DATABASE_FILE
LATEST_VISITOR_IMAGE = ""

# ==========================================
# SQLITE CONNECTION
# ==========================================

def get_db():
    connection = sqlite3.connect(DATABASE_FILE, check_same_thread=False)
    connection.row_factory = sqlite3.Row
    return connection

# ==========================================
# CREATE DATABASE
# ==========================================

conn = get_db()
cursor = conn.cursor()

cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS mobile_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        token TEXT,
        created_at TEXT
    )
    """
)

cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS visitor_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_time TEXT,
        result TEXT,
        similarity REAL,
        image_name TEXT
    )
    """
)

cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS visitor_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_name TEXT,
        image_url TEXT,
        created_at TEXT
    )
    """
)

cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS approval_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_time TEXT,
        status TEXT,
        similarity REAL,
        image_name TEXT
    )
    """
)

cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS system_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_time TEXT,
        description TEXT
    )
    """
)

conn.commit()
conn.close()

print("DATABASE READY")

# ==========================================
# LOAD LAST FCM TOKEN FROM DATABASE
# So Flask does not lose the token on restart
# ==========================================

def load_latest_fcm_token():
    global mobile_token
    try:
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT token FROM mobile_tokens ORDER BY id DESC LIMIT 1"
        )
        row = cursor.fetchone()
        conn.close()
        if row:
            mobile_token = row["token"]
            print(f"FCM TOKEN LOADED: {mobile_token[:30]}...")
        else:
            print("FCM TOKEN: None saved yet — open the app once to register")
    except Exception as e:
        print("FCM TOKEN LOAD ERROR:", e)

load_latest_fcm_token()

# ==========================================
# LOG EVENT
# ==========================================

def log_event(result, similarity=0, image_name=""):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO visitor_logs (event_time, result, similarity, image_name)
        VALUES (?, ?, ?, ?)
        """,
        (str(datetime.now()), result, similarity, image_name)
    )
    conn.commit()
    conn.close()

# ==========================================
# SAVE VISITOR IMAGE RECORD
# ==========================================

def save_visitor_image(image_name):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO visitor_images (image_name, image_url, created_at)
        VALUES (?, ?, ?)
        """,
        (
            image_name,
            f"http://{SERVER_IP}:5000/image/{image_name}",
            str(datetime.now())
        )
    )
    conn.commit()
    conn.close()

# ==========================================
# SAVE SYSTEM EVENT
# ==========================================

def add_system_event(description):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO system_events (event_time, description)
        VALUES (?, ?)
        """,
        (str(datetime.now()), description)
    )
    conn.commit()
    conn.close()

# ==========================================
# TELEGRAM FUNCTIONS
# ==========================================

def send_telegram_message(message):
    try:
        url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
        requests.post(
            url,
            data={"chat_id": CHAT_ID, "text": message},
            timeout=3
        )
        print("TELEGRAM MESSAGE SENT")
    except Exception as e:
        print("TELEGRAM ERROR:", str(e))


def send_telegram_photo(image_path, caption=""):
    try:
        url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendPhoto"
        with open(image_path, "rb") as photo:
            requests.post(
                url,
                data={"chat_id": CHAT_ID, "caption": caption},
                files={"photo": photo},
                timeout=5
            )
        print("TELEGRAM PHOTO SENT")
    except Exception as e:
        print("TELEGRAM PHOTO ERROR:", str(e))

# ==========================================
# TOKEN REGISTRATION
# ==========================================

@app.route("/register_token", methods=["POST"])
def register_token():
    global mobile_token
    try:
        data = request.json
        token = data.get("token", "")

        if token == "":
            return jsonify({"success": False, "message": "Token Missing"})

        mobile_token = token

        conn = get_db()
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO mobile_tokens (token, created_at)
            VALUES (?, ?)
            """,
            (token, str(datetime.now()))
        )
        conn.commit()
        conn.close()

        add_system_event("FCM Token Registered")
        print("\nTOKEN REGISTERED\n")

        return jsonify({"success": True, "message": "Token Registered"})

    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

# ==========================================
# TEST TELEGRAM
# ==========================================

@app.route("/test_telegram")
def test_telegram():
    send_telegram_message(
        "✅ AI SMART LOCKER\n\nTelegram Connection Successful"
    )
    return jsonify({"success": True})

# ==========================================
# TEST FCM
# ==========================================

@app.route("/test_fcm")
def test_fcm():
    global mobile_token
    try:
        if mobile_token == "":
            return jsonify({"success": False, "message": "No Mobile Token"})

        send_notification(mobile_token, "AI Smart Locker", "FCM Notification Test")
        return jsonify({"success": True})

    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

# ==========================================
# GET REGISTERED TOKENS
# ==========================================

@app.route("/tokens")
def get_tokens():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM mobile_tokens ORDER BY id DESC")
    rows = cursor.fetchall()
    conn.close()
    return jsonify([dict(row) for row in rows])

# ==========================================
# GET LOGS FROM SQLITE
# ==========================================

def get_logs():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM visitor_logs ORDER BY id ASC")
    rows = cursor.fetchall()
    conn.close()
    return [dict(row) for row in rows]

# ==========================================
# SAVE LOG
# ==========================================

def save_log(result, similarity=0, image_name=""):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO visitor_logs (event_time, result, similarity, image_name)
        VALUES (?, ?, ?, ?)
        """,
        (str(datetime.now()), result, similarity, image_name)
    )
    conn.commit()
    conn.close()

# ==========================================
# ROOT API
# ==========================================

@app.route("/")
def home():
    return jsonify({
        "project": "AI Smart Locker",
        "status": "Running",
        "database": "locker.db",
        "telegram": "Enabled",
        "firebase": "Enabled"
    })

# ==========================================
# TEST ALL SERVICES
# ==========================================

@app.route("/test_all")
def test_all():
    try:
        send_telegram_message("✅ AI SMART LOCKER TEST")

        if mobile_token != "":
            send_notification(mobile_token, "AI Smart Locker", "FCM Test Successful")

        return jsonify({"success": True, "message": "All Services Working"})

    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

# ==========================================
# STATUS API
# ==========================================

@app.route("/status")
def status():
    logs = get_logs()
    intruders = len([x for x in logs if "Intruder" in x["result"]])
    last_event = logs[-1]["result"] if len(logs) > 0 else "No Activity"

    return jsonify({
        "locker": "ONLINE",
        "pending": pending_access["status"],
        "total_logs": len(logs),
        "intruders": intruders,
        "last_event": last_event
    })

# ==========================================
# LOGS API
# ==========================================

@app.route("/logs")
def logs_api():
    return jsonify(get_logs())

# ==========================================
# PENDING ACCESS
# ==========================================

@app.route("/pending_access")
def pending_access_api():
    return jsonify(pending_access)

# ==========================================
# APPROVE
# ==========================================

@app.route("/approve")
def approve():
    global pending_access, access_status

    access_status = "APPROVED"
    pending_access["status"] = "APPROVED"

    save_log("Access Approved")
    send_telegram_message("✅ ACCESS APPROVED")

    return jsonify({"success": True})

# ==========================================
# REJECT
# ==========================================

@app.route("/reject")
def reject():
    global pending_access, access_status

    access_status = "REJECTED"
    pending_access["status"] = "REJECTED"

    save_log("Access Rejected")
    send_telegram_message("❌ ACCESS REJECTED")

    return jsonify({"success": True})

# ==========================================
# VISITOR IMAGE
# ==========================================

@app.route("/visitor_image")
def visitor_image():
    # Return most recently captured visitor image (not evidence)
    if LATEST_VISITOR_IMAGE and os.path.exists(LATEST_VISITOR_IMAGE):
        return send_file(LATEST_VISITOR_IMAGE, mimetype="image/jpeg")

    # Fallback: find newest non-evidence jpg
    try:
        files = [
            os.path.join(VISITORS_FOLDER, f)
            for f in os.listdir(VISITORS_FOLDER)
            if f.lower().endswith(".jpg") and not f.startswith("evidence_")
        ]
        if files:
            latest = max(files, key=os.path.getmtime)
            return send_file(latest, mimetype="image/jpeg")
    except Exception:
        pass

    return jsonify({"success": False, "message": "No Visitor Image"}), 404

# ==========================================
# VIEW STORED IMAGE
# ==========================================

@app.route("/image/<filename>")
def get_image(filename):
    return send_from_directory(VISITORS_FOLDER, filename)

# ==========================================
# IMAGE GALLERY LIST
# ==========================================

@app.route("/images")
def get_images():
    if not os.path.exists(VISITORS_FOLDER):
        return jsonify([])

    # Sort by modification time — newest first
    entries = []
    for f in os.listdir(VISITORS_FOLDER):
        if f.lower().endswith((".jpg", ".jpeg", ".png")):
            full_path = os.path.join(VISITORS_FOLDER, f)
            entries.append((full_path, os.path.getmtime(full_path)))

    entries.sort(key=lambda x: x[1], reverse=True)

    files = [
        f"http://{SERVER_IP}:5000/image/{os.path.basename(p)}"
        for p, _ in entries
    ]
    return jsonify(files)

# ==========================================
# VERIFY FACE
# ==========================================

@app.route("/verify", methods=["POST"])
def verify_face():
    global pending_access, LATEST_VISITOR_IMAGE

    try:
        if "image" not in request.files:
            return jsonify({"success": False, "message": "No Image"})

        image = request.files["image"]
        filename = f"{uuid.uuid4()}.jpg"
        image_path = os.path.join(VISITORS_FOLDER, filename)

        image.save(image_path)
        LATEST_VISITOR_IMAGE = image_path

        print("VISITOR SAVED:", image_path)

        save_visitor_image(filename)

        # --------------------------------------------------
        # STEP 1 — confirm a real face exists
        # --------------------------------------------------
        try:
            faces = DeepFace.extract_faces(
                img_path=image_path,
                detector_backend="mtcnn",
                enforce_detection=True
            )

            if len(faces) == 0:
                raise ValueError("No face found")

        except Exception as detect_error:
            print("NO FACE DETECTED:", detect_error)
            save_log("No Face Detected", 0, filename)
            return jsonify({"success": False, "message": "No face detected"})

        # --------------------------------------------------
        # STEP 2 — verify against owner photos.
        # EARLY EXIT: stops as soon as first match is found
        # so we never wait for remaining owner photos
        # unnecessarily — fixes the timeout issue.
        # --------------------------------------------------
        best_similarity = 0
        owner_match_found = False

        for owner_image in os.listdir(OWNER_FOLDER):
            owner_path = os.path.join(OWNER_FOLDER, owner_image)

            try:
                result = DeepFace.verify(
                    img1_path=owner_path,
                    img2_path=image_path,
                    model_name="ArcFace",
                    detector_backend="mtcnn",
                    enforce_detection=True
                )

                similarity = round((1 - result["distance"]) * 100, 2)
                print(owner_image, similarity, "verified:", result["verified"])

                if similarity > best_similarity:
                    best_similarity = similarity

                # Require BOTH DeepFace verified AND similarity >= 50
                # to prevent false positives on other people
                if result["verified"] and similarity >= 50:
                    owner_match_found = True
                    break   # ← EARLY EXIT — owner found, stop checking

            except Exception as face_error:
                print("FACE ERROR:", face_error)

        print("BEST SIMILARITY:", best_similarity)

        if owner_match_found:
            save_log("Owner Verified", best_similarity, filename)
            send_telegram_message(
                f"✅ OWNER VERIFIED\n\nSimilarity: {best_similarity}%"
            )
            if mobile_token:
                try:
                    send_notification(
                        mobile_token,
                        "✅ Owner Verified",
                        f"Welcome! Locker opened by owner. Similarity: {best_similarity}%"
                    )
                    print("FCM SENT: Owner Verified notification")
                except Exception as fcm_err:
                    print("FCM ERROR:", fcm_err)
            return jsonify({
                "success": True,
                "verified": True,
                "similarity": best_similarity,
                "message": "Owner Verified"
            })

        pending_access = {
            "status": "WAITING",
            "result": "Unknown Visitor",
            "time": str(datetime.now()),
            "image": f"http://{SERVER_IP}:5000/visitor_image",
            "similarity": best_similarity
        }

        save_log("Intruder Detected", best_similarity, filename)
        send_telegram_message(
            f"🚨 INTRUDER DETECTED\n\nSimilarity: {best_similarity}%"
        )
        send_telegram_photo(image_path, "Approval Required")
        if mobile_token:
            try:
                send_notification(
                    mobile_token,
                    "🚨 Intruder Detected!",
                    f"Unknown visitor at your locker! Similarity: {best_similarity}%. Open app to Approve or Reject."
                )
                print("FCM SENT: Intruder notification")
            except Exception as fcm_err:
                print("FCM ERROR:", fcm_err)

        return jsonify({
            "success": True,
            "verified": False,
            "similarity": best_similarity,
            "message": "Intruder Detected"
        })

    except Exception as e:
        return jsonify({"success": False, "message": str(e)})


# ==========================================
# EVIDENCE CAPTURE (called by ESP32 after rejection)
# Saves each photo, logs it, sends to Telegram
# ==========================================

@app.route("/evidence", methods=["POST"])
def save_evidence():
    try:
        if "image" not in request.files:
            return jsonify({"success": False, "message": "No Image"})

        image = request.files["image"]

        # Use timestamp + uuid so all 10 photos have unique names
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"evidence_{timestamp}_{uuid.uuid4().hex[:8]}.jpg"
        image_path = os.path.join(VISITORS_FOLDER, filename)

        image.save(image_path)
        print("EVIDENCE SAVED:", image_path)

        # Save to DB so it appears in the app gallery
        save_visitor_image(filename)
        save_log("Evidence Captured", 0, filename)

        # Send to Telegram (fails silently if network blocked)
        send_telegram_photo(image_path, "🚨 INTRUDER EVIDENCE PHOTO")

        return jsonify({"success": True, "filename": filename})

    except Exception as e:
        return jsonify({"success": False, "message": str(e)})


# ==========================================
# APPROVAL PAGE — open this in browser/phone
# Shows visitor photo + Approve / Reject buttons
# Auto-refreshes every 2 seconds
# ==========================================

@app.route("/approval_page")
def approval_page():
    status = pending_access.get("status", "NONE")
    image_url = f"http://{SERVER_IP}:5000/visitor_image"
    similarity = pending_access.get("similarity", "")
    event_time = pending_access.get("time", "")

    if status == "WAITING":
        body_content = f"""
        <div class='card'>
          <h2>⚠️ Unknown Visitor Detected</h2>
          <p>Similarity: <b>{similarity}%</b> &nbsp;|&nbsp; Time: {event_time}</p>
          <img src='{image_url}' onerror='this.src=""'>
          <div class='buttons'>
            <a href='/approve' class='btn approve'>✅ APPROVE</a>
            <a href='/reject' class='btn reject'>❌ REJECT</a>
          </div>
        </div>
        """
    elif status == "APPROVED":
        body_content = "<div class='card ok'><h2>✅ Access Approved</h2><p>Visitor was approved. Waiting for next event...</p></div>"
    elif status == "REJECTED":
        body_content = "<div class='card bad'><h2>❌ Access Rejected</h2><p>Intruder mode activated. Evidence photos being captured...</p></div>"
    else:
        body_content = "<div class='card'><h2>✅ Locker Secure</h2><p>No pending access requests. Waiting for trigger...</p></div>"

    html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset='UTF-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1.0'>
  <title>AI Smart Locker</title>
  <meta http-equiv='refresh' content='2'>
  <style>
    body {{ font-family: Arial, sans-serif; background: #1a1a2e; color: #eee;
            display: flex; justify-content: center; align-items: center;
            min-height: 100vh; margin: 0; padding: 16px; box-sizing: border-box; }}
    .card {{ background: #16213e; border-radius: 16px; padding: 24px;
             max-width: 400px; width: 100%; text-align: center; box-shadow: 0 4px 20px #0005; }}
    .card h2 {{ margin-top: 0; font-size: 1.3em; }}
    .card img {{ width: 100%; border-radius: 12px; margin: 16px 0;
                 border: 2px solid #0f3460; max-height: 280px; object-fit: cover; }}
    .buttons {{ display: flex; gap: 12px; margin-top: 16px; }}
    .btn {{ flex: 1; padding: 16px; border-radius: 12px; text-decoration: none;
            font-size: 1.1em; font-weight: bold; color: #fff; }}
    .approve {{ background: #27ae60; }}
    .reject  {{ background: #c0392b; }}
    .ok  {{ border: 2px solid #27ae60; }}
    .bad {{ border: 2px solid #c0392b; }}
    p {{ color: #aaa; font-size: 0.9em; }}
  </style>
</head>
<body>
  {body_content}
</body>
</html>"""
    return html

# ==========================================
# MAIN — must stay at the very bottom of the file.
# Every @app.route(...) above this point WILL register;
# anything added below app.run() will NOT.
# ==========================================

if __name__ == "__main__":
    add_system_event("Server Started")
    print("SERVER READY")
    app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False)
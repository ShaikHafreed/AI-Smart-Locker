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
# NOTE: move these into environment variables and rotate the
# bot token via BotFather, since it's been exposed in plaintext.

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
# SAVE VISITOR IMAGE RECORD (permanent image history)
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
# VISITOR IMAGE (latest, fixed filename)
# ==========================================

@app.route("/visitor_image")
def visitor_image():
    image_path = os.path.join(VISITORS_FOLDER, "visitor.jpg")

    if os.path.exists(image_path):
        return send_file(image_path, mimetype="image/jpeg")

    return jsonify({"success": False, "message": "No Visitor Image"})

# ==========================================
# VIEW STORED IMAGE (by filename, used by /images gallery)
# ==========================================

@app.route("/image/<filename>")
def get_image(filename):
    return send_from_directory(VISITORS_FOLDER, filename)

# ==========================================
# IMAGE GALLERY LIST
# ==========================================

@app.route("/images")
def get_images():
    files = []

    if os.path.exists(VISITORS_FOLDER):
        for file in os.listdir(VISITORS_FOLDER):
            if file.lower().endswith((".jpg", ".jpeg", ".png")):
                files.append(f"http://{SERVER_IP}:5000/image/{file}")

    files.reverse()
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
        # STEP 1 — confirm a real face exists before anything
        # else runs. retinaface is much stricter than opencv
        # and avoids false positives on blank/room images.
        # --------------------------------------------------
        try:
            faces = DeepFace.extract_faces(
                img_path=image_path,
                detector_backend="retinaface",
                enforce_detection=True
            )

            if len(faces) == 0:
                raise ValueError("No face found")

        except Exception as detect_error:
            print("NO FACE DETECTED:", detect_error)

            save_log("No Face Detected", 0, filename)

            return jsonify({"success": False, "message": "No face detected"})

        # --------------------------------------------------
        # STEP 2 — only now run verification against owners
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
                    detector_backend="retinaface",
                    enforce_detection=True
                )

                similarity = round((1 - result["distance"]) * 100, 2)
                print(owner_image, similarity, "verified:", result["verified"])

                if similarity > best_similarity:
                    best_similarity = similarity

                if result["verified"]:
                    owner_match_found = True

            except Exception as face_error:
                print("FACE ERROR:", face_error)

        print("BEST SIMILARITY:", best_similarity)

        if owner_match_found:

            save_log("Owner Verified", best_similarity, filename)
            send_telegram_message(f"✅ OWNER VERIFIED\n\nSimilarity: {best_similarity}%")

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
        send_telegram_message(f"🚨 INTRUDER DETECTED\n\nSimilarity: {best_similarity}%")
        send_telegram_photo(image_path, "Approval Required")

        return jsonify({
            "success": True,
            "verified": False,
            "similarity": best_similarity,
            "message": "Intruder Detected"
        })

    except Exception as e:
        return jsonify({"success": False, "message": str(e)})
    # ==========================================
# MAIN — must stay at the very bottom of the file.
# Every @app.route(...) above this point WILL register;
# anything added below app.run() will NOT.
# ==========================================

if __name__ == "__main__":
    add_system_event("Server Started")
    print("SERVER READY")
    app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False)
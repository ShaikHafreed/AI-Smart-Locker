from flask import Flask, request, jsonify, send_file, send_from_directory
from flask_cors import CORS
from deepface import DeepFace
from datetime import datetime, timedelta
from fcm_service import send_notification
from functools import wraps

import requests
import sqlite3
import os
import sys
import uuid
import hashlib
import jwt
import secrets
import time

# Windows' console defaults to cp1252, which can't encode the emoji used in
# several print() calls below (crashes the request with UnicodeEncodeError).
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

# ==========================================
# APP
# ==========================================

app = Flask(__name__)
CORS(app)

# ==========================================
# SECRETS
# ==========================================

JWT_SECRET       = "ai_smart_locker_jwt_secret_2026"
JWT_EXPIRY_DAYS  = 30
DEVICE_TOKEN     = "ESP32_DEVICE_SECRET_TOKEN_2026"
GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID", "")

# ==========================================
# MSG91 CONFIG — set these in environment or replace directly
# Get from: https://msg91.com → API → OTP
# ==========================================
MSG91_API_KEY     = os.environ.get("MSG91_API_KEY", "YOUR_MSG91_API_KEY")
MSG91_TEMPLATE_ID = os.environ.get("MSG91_TEMPLATE_ID", "YOUR_TEMPLATE_ID")
MSG91_SENDER_ID   = os.environ.get("MSG91_SENDER_ID", "AILOCK")  # 6 chars

# ==========================================
# CONFIG
# ==========================================

SERVER_IP    = "192.168.31.229"
BOT_TOKEN    = os.environ.get("LOCKER_BOT_TOKEN", "")
CHAT_ID      = os.environ.get("LOCKER_CHAT_ID", "")

BASE_DIR      = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
OWNER_FOLDER  = os.path.join(BASE_DIR, "owner_faces")
DATABASE_FILE = os.path.join(BASE_DIR, "locker.db")

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(OWNER_FOLDER,  exist_ok=True)

# ==========================================
# RUNTIME STATE
# ==========================================

mobile_token = ""
pending_access = {"status": "NONE", "result": "", "time": "", "image": "", "similarity": ""}
access_status        = "WAITING"
VISITORS_FOLDER      = UPLOAD_FOLDER
DB_PATH              = DATABASE_FILE
LATEST_VISITOR_IMAGE = ""

# In-memory OTP store: { phone: { otp, expires_at, attempts, sent_at } }
otp_store = {}
OTP_RESEND_COOLDOWN = 30   # seconds between OTP requests for the same phone
OTP_MAX_ATTEMPTS    = 5    # wrong guesses allowed before the OTP is invalidated

# ==========================================
# DATABASE
# ==========================================

def get_db():
    conn = sqlite3.connect(DATABASE_FILE, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

conn   = get_db()
cursor = conn.cursor()

cursor.executescript("""
    CREATE TABLE IF NOT EXISTS users (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT    DEFAULT '',
        email         TEXT    UNIQUE,
        phone         TEXT    UNIQUE,
        password_hash TEXT,
        google_id     TEXT    UNIQUE,
        auth_method   TEXT    DEFAULT 'phone',
        created_at    TEXT,
        last_login    TEXT
    );

    CREATE TABLE IF NOT EXISTS mobile_tokens (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER,
        token      TEXT,
        created_at TEXT
    );

    CREATE TABLE IF NOT EXISTS visitor_logs (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        event_time TEXT,
        result     TEXT,
        similarity REAL,
        image_name TEXT
    );

    CREATE TABLE IF NOT EXISTS visitor_images (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        image_name TEXT,
        image_url  TEXT,
        created_at TEXT
    );

    CREATE TABLE IF NOT EXISTS approval_requests (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        request_time TEXT,
        status       TEXT,
        similarity   REAL,
        image_name   TEXT
    );

    CREATE TABLE IF NOT EXISTS system_events (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        event_time  TEXT,
        description TEXT
    );
""")

conn.commit()
conn.close()
print("DATABASE READY")

# ==========================================
# HELPERS — PASSWORD
# ==========================================

def hash_password(password: str) -> str:
    salt = "ai_locker_salt_2026"
    return hashlib.sha256(f"{salt}{password}".encode()).hexdigest()

# ==========================================
# HELPERS — JWT
# ==========================================

def generate_jwt(user_id: int, phone: str = None, email: str = None) -> str:
    payload = {
        "user_id": user_id,
        "phone":   phone,
        "email":   email,
        "exp":     datetime.utcnow() + timedelta(days=JWT_EXPIRY_DAYS),
        "iat":     datetime.utcnow()
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

def decode_jwt(token: str) -> dict:
    return jwt.decode(token, JWT_SECRET, algorithms=["HS256"])

# ==========================================
# AUTH DECORATOR
# ==========================================

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")

        # Allow ESP32 device token
        if auth_header == f"Device {DEVICE_TOKEN}":
            request.user_id = None
            return f(*args, **kwargs)

        # JWT Bearer token
        if not auth_header.startswith("Bearer "):
            return jsonify({"success": False, "message": "Authorization required"}), 401

        token = auth_header.split(" ")[1]
        try:
            payload = decode_jwt(token)
            request.user_id = payload.get("user_id")
            return f(*args, **kwargs)
        except jwt.ExpiredSignatureError:
            return jsonify({"success": False, "message": "Token expired. Please login again."}), 401
        except jwt.InvalidTokenError:
            return jsonify({"success": False, "message": "Invalid token"}), 401

    return decorated

# ==========================================
# HELPERS — DB
# ==========================================

def get_logs():
    conn   = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM visitor_logs ORDER BY id ASC")
    rows   = cursor.fetchall()
    conn.close()
    return [dict(row) for row in rows]

def save_log(result, similarity=0, image_name=""):
    conn   = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO visitor_logs (event_time, result, similarity, image_name) VALUES (?, ?, ?, ?)",
        (str(datetime.now()), result, similarity, image_name)
    )
    conn.commit()
    conn.close()

def save_visitor_image(image_name):
    conn   = get_db()
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO visitor_images (image_name, image_url, created_at) VALUES (?, ?, ?)",
        (image_name, f"http://{SERVER_IP}:5000/image/{image_name}", str(datetime.now()))
    )
    conn.commit()
    conn.close()

def add_system_event(description):
    conn   = get_db()
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO system_events (event_time, description) VALUES (?, ?)",
        (str(datetime.now()), description)
    )
    conn.commit()
    conn.close()

def load_latest_fcm_token():
    global mobile_token
    try:
        conn   = get_db()
        cursor = conn.cursor()
        cursor.execute("SELECT token FROM mobile_tokens ORDER BY id DESC LIMIT 1")
        row = cursor.fetchone()
        conn.close()
        if row:
            mobile_token = row["token"]
            print(f"FCM TOKEN LOADED: {mobile_token[:30]}...")
        else:
            print("FCM TOKEN: None saved yet")
    except Exception as e:
        print("FCM TOKEN LOAD ERROR:", e)

load_latest_fcm_token()

# ==========================================
# SMS — MSG91
# ==========================================

def send_otp_msg91(phone: str, otp: str) -> bool:
    """
    Send OTP via MSG91.
    Docs: https://docs.msg91.com/reference/send-otp
    """
    try:
        # Remove country code if present, add +91
        phone_clean = phone.replace("+91", "").replace(" ", "").strip()
        phone_with_cc = f"91{phone_clean}"

        url = "https://control.msg91.com/api/v5/otp"
        payload = {
            "template_id": MSG91_TEMPLATE_ID,
            "mobile":      phone_with_cc,
            "authkey":     MSG91_API_KEY,
            "otp":         otp,
        }
        headers = {
            "Content-Type": "application/json",
            "authkey":      MSG91_API_KEY
        }
        r = requests.post(url, json=payload, headers=headers, timeout=10)
        data = r.json()
        print(f"MSG91 Response: {data}")

        if data.get("type") == "success":
            print(f"✅ OTP sent to {phone} via MSG91")
            return True
        else:
            print(f"❌ MSG91 error: {data}")
            return False

    except Exception as e:
        print(f"MSG91 Exception: {e}")
        return False

# ==========================================
# TELEGRAM
# ==========================================

def send_telegram_message(message):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
                      data={"chat_id": CHAT_ID, "text": message}, timeout=3)
    except Exception as e:
        print("TELEGRAM ERROR:", str(e))

def send_telegram_photo(image_path, caption=""):
    try:
        with open(image_path, "rb") as photo:
            requests.post(f"https://api.telegram.org/bot{BOT_TOKEN}/sendPhoto",
                          data={"chat_id": CHAT_ID, "caption": caption},
                          files={"photo": photo}, timeout=5)
    except Exception as e:
        print("TELEGRAM PHOTO ERROR:", str(e))

# ==========================================
# AUTH ROUTES
# ==========================================

@app.route("/auth/send_otp", methods=["POST"])
def send_otp():
    try:
        data  = request.json
        phone = data.get("phone", "").strip()
        if not phone:
            return jsonify({"success": False, "message": "Phone number required"})

        # Server-side resend cooldown — a client-side timer alone can be
        # bypassed by just calling the API directly, letting someone spam
        # SMS sends or hammer a fresh OTP for guessing attempts.
        existing = otp_store.get(phone)
        if existing:
            elapsed = time.time() - existing["sent_at"]
            if elapsed < OTP_RESEND_COOLDOWN:
                wait = int(OTP_RESEND_COOLDOWN - elapsed)
                return jsonify({"success": False, "message": f"Please wait {wait}s before requesting another OTP"})

        # secrets.randbelow is a CSPRNG — random.randint is predictable and
        # unsuitable for anything auth-related.
        otp = str(secrets.randbelow(900000) + 100000)
        otp_store[phone] = {
            "otp":        otp,
            "expires_at": time.time() + 300,  # 5 minutes
            "sent_at":    time.time(),
            "attempts":   0,
        }

        print(f"\n📱 OTP for {phone}: {otp}\n")

        # Try MSG91 first
        sms_sent = False
        if MSG91_API_KEY != "YOUR_MSG91_API_KEY":
            sms_sent = send_otp_msg91(phone, otp)

        if sms_sent:
            # Real SMS sent — don't expose OTP
            return jsonify({
                "success":  True,
                "message":  f"OTP sent to +91 {phone[-10:]}",
                "sms_sent": True
            })
        else:
            # Demo mode — show OTP in response (remove in production)
            return jsonify({
                "success":   True,
                "message":   "OTP generated (demo mode — check Flask console)",
                "sms_sent":  False,
                "demo_otp":  otp   # ← remove after MSG91 is configured
            })

    except Exception as e:
        return jsonify({"success": False, "message": str(e)})


@app.route("/auth/verify_otp", methods=["POST"])
def verify_otp():
    try:
        data  = request.json
        phone = data.get("phone", "").strip()
        otp   = data.get("otp", "").strip()
        name  = data.get("name", "").strip()

        if not phone or not otp:
            return jsonify({"success": False, "message": "Phone and OTP required"})

        stored = otp_store.get(phone)
        if not stored:
            return jsonify({"success": False, "message": "OTP not found. Request a new one."})
        if time.time() > stored["expires_at"]:
            del otp_store[phone]
            return jsonify({"success": False, "message": "OTP expired. Request a new one."})
        if stored["otp"] != otp:
            stored["attempts"] += 1
            if stored["attempts"] >= OTP_MAX_ATTEMPTS:
                del otp_store[phone]
                return jsonify({"success": False, "message": "Too many incorrect attempts. Request a new OTP."})
            left = OTP_MAX_ATTEMPTS - stored["attempts"]
            return jsonify({"success": False, "message": f"Incorrect OTP. {left} attempt{'s' if left != 1 else ''} left."})

        del otp_store[phone]

        conn   = get_db()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM users WHERE phone = ?", (phone,))
        user = cursor.fetchone()

        if user:
            cursor.execute("UPDATE users SET last_login = ? WHERE phone = ?",
                           (str(datetime.now()), phone))
            conn.commit()
            user_id   = user["id"]
            user_name = user["name"] or name or "Owner"
            is_new    = False
        else:
            cursor.execute(
                "INSERT INTO users (name, phone, auth_method, created_at, last_login) VALUES (?, ?, ?, ?, ?)",
                (name or "Owner", phone, "phone", str(datetime.now()), str(datetime.now()))
            )
            conn.commit()
            user_id   = cursor.lastrowid
            user_name = name or "Owner"
            is_new    = True

        conn.close()

        token = generate_jwt(user_id, phone=phone)
        add_system_event(f"User {'registered' if is_new else 'logged in'}: {phone}")

        return jsonify({
            "success": True,
            "is_new":  is_new,
            "token":   token,
            "user": {
                "id":    user_id,
                "name":  user_name,
                "phone": phone,
                "email": ""
            }
        })

    except Exception as e:
        return jsonify({"success": False, "message": str(e)})


@app.route("/auth/google", methods=["POST"])
def google_auth():
    try:
        data      = request.json
        id_token  = data.get("id_token", "")
        name      = data.get("name", "")
        email     = data.get("email", "")
        google_id = data.get("google_id", "")

        if not google_id or not email:
            return jsonify({"success": False, "message": "Google credentials required"})

        # Verify token with Google
        try:
            verify_url  = f"https://oauth2.googleapis.com/tokeninfo?id_token={id_token}"
            r           = requests.get(verify_url, timeout=5)
            google_data = r.json()

            if "error" in google_data:
                return jsonify({"success": False, "message": "Invalid Google token. Please try again."})

            # Verify email matches
            if google_data.get("email") != email:
                return jsonify({"success": False, "message": "Email mismatch"})

        except Exception as verify_err:
            print(f"Google verify warning: {verify_err}")
            # Continue with provided data in demo mode

        conn   = get_db()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM users WHERE google_id = ? OR email = ?", (google_id, email))
        user = cursor.fetchone()

        if user:
            cursor.execute("UPDATE users SET last_login = ?, google_id = ? WHERE id = ?",
                           (str(datetime.now()), google_id, user["id"]))
            conn.commit()
            user_id   = user["id"]
            user_name = user["name"] or name
            is_new    = False
        else:
            cursor.execute(
                "INSERT INTO users (name, email, google_id, auth_method, created_at, last_login) VALUES (?, ?, ?, ?, ?, ?)",
                (name, email, google_id, "google", str(datetime.now()), str(datetime.now()))
            )
            conn.commit()
            user_id   = cursor.lastrowid
            user_name = name
            is_new    = True

        conn.close()

        token = generate_jwt(user_id, email=email)
        add_system_event(f"Google {'register' if is_new else 'login'}: {email}")

        return jsonify({
            "success": True,
            "is_new":  is_new,
            "token":   token,
            "user": {
                "id":    user_id,
                "name":  user_name,
                "email": email,
                "phone": ""
            }
        })

    except Exception as e:
        return jsonify({"success": False, "message": str(e)})


@app.route("/auth/me")
@require_auth
def get_me():
    try:
        conn   = get_db()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT id, name, email, phone, auth_method, created_at FROM users WHERE id = ?",
            (request.user_id,))
        user = cursor.fetchone()
        conn.close()
        if user:
            return jsonify({"success": True, "user": dict(user)})
        return jsonify({"success": False, "message": "User not found"}), 404
    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

# ==========================================
# PROTECTED ROUTES
# ==========================================

@app.route("/")
def home():
    return jsonify({"project": "AI Smart Locker", "status": "Running"})

@app.route("/register_token", methods=["POST"])
@require_auth
def register_token():
    global mobile_token
    try:
        data  = request.json
        token = data.get("token", "")
        if not token:
            return jsonify({"success": False, "message": "Token Missing"})
        mobile_token = token
        conn   = get_db()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO mobile_tokens (user_id, token, created_at) VALUES (?, ?, ?)",
            (getattr(request, 'user_id', None), token, str(datetime.now())))
        conn.commit()
        conn.close()
        add_system_event("FCM Token Registered")
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

@app.route("/status")
@require_auth
def status():
    logs       = get_logs()
    intruders  = len([x for x in logs if "Intruder" in x["result"]])
    last_event = logs[-1]["result"] if logs else "No Activity"
    return jsonify({
        "locker":     "ONLINE",
        "pending":    pending_access["status"],
        "total_logs": len(logs),
        "intruders":  intruders,
        "last_event": last_event
    })

@app.route("/logs")
@require_auth
def logs_api():
    return jsonify(get_logs())

@app.route("/pending_access")
@require_auth
def pending_access_api():
    return jsonify(pending_access)

@app.route("/approve")
@require_auth
def approve():
    global pending_access, access_status
    access_status            = "APPROVED"
    pending_access["status"] = "APPROVED"
    save_log("Access Approved")
    send_telegram_message("✅ ACCESS APPROVED")
    return jsonify({"success": True})

@app.route("/reject")
@require_auth
def reject():
    global pending_access, access_status
    access_status            = "REJECTED"
    pending_access["status"] = "REJECTED"
    save_log("Access Rejected")
    send_telegram_message("❌ ACCESS REJECTED")
    return jsonify({"success": True})

@app.route("/visitor_image")
@require_auth
def visitor_image():
    if LATEST_VISITOR_IMAGE and os.path.exists(LATEST_VISITOR_IMAGE):
        return send_file(LATEST_VISITOR_IMAGE, mimetype="image/jpeg")
    try:
        files = [os.path.join(VISITORS_FOLDER, f) for f in os.listdir(VISITORS_FOLDER)
                 if f.lower().endswith(".jpg") and not f.startswith("evidence_")]
        if files:
            return send_file(max(files, key=os.path.getmtime), mimetype="image/jpeg")
    except Exception:
        pass
    return jsonify({"success": False, "message": "No image"}), 404

@app.route("/image/<filename>")
@require_auth
def get_image(filename):
    return send_from_directory(VISITORS_FOLDER, filename)

@app.route("/image/<filename>", methods=["DELETE"])
@require_auth
def delete_image(filename):
    try:
        safe_name = os.path.basename(filename)
        file_path = os.path.join(VISITORS_FOLDER, safe_name)
        if not os.path.exists(file_path):
            return jsonify({"success": False, "message": "File not found"})
        os.remove(file_path)
        add_system_event(f"Gallery image deleted: {safe_name}")
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

@app.route("/images")
@require_auth
def get_images():
    if not os.path.exists(VISITORS_FOLDER):
        return jsonify([])
    entries = []
    for f in os.listdir(VISITORS_FOLDER):
        if f.lower().endswith((".jpg", ".jpeg", ".png")):
            fp = os.path.join(VISITORS_FOLDER, f)
            entries.append((fp, os.path.getmtime(fp)))
    entries.sort(key=lambda x: x[1], reverse=True)
    return jsonify([f"http://{SERVER_IP}:5000/image/{os.path.basename(p)}" for p, _ in entries])

@app.route("/verify", methods=["POST"])
@require_auth
def verify_face():
    global pending_access, LATEST_VISITOR_IMAGE
    try:
        if "image" not in request.files:
            return jsonify({"success": False, "message": "No Image"})
        image      = request.files["image"]
        filename   = f"{uuid.uuid4()}.jpg"
        image_path = os.path.join(VISITORS_FOLDER, filename)
        image.save(image_path)
        LATEST_VISITOR_IMAGE = image_path
        save_visitor_image(filename)

        try:
            faces = DeepFace.extract_faces(img_path=image_path,
                                           detector_backend="mtcnn",
                                           enforce_detection=True)
            if not faces:
                raise ValueError("No face")
        except Exception:
            save_log("No Face Detected", 0, filename)
            return jsonify({"success": False, "message": "No face detected"})

        best_similarity   = 0
        owner_match_found = False

        for owner_image in os.listdir(OWNER_FOLDER):
            owner_path = os.path.join(OWNER_FOLDER, owner_image)
            try:
                result     = DeepFace.verify(img1_path=owner_path, img2_path=image_path,
                                             model_name="ArcFace", detector_backend="mtcnn",
                                             enforce_detection=True)
                similarity = round((1 - result["distance"]) * 100, 2)
                if similarity > best_similarity:
                    best_similarity = similarity
                if result["verified"] and similarity >= 50:
                    owner_match_found = True
                    break
            except Exception as e:
                print("FACE ERROR:", e)

        if owner_match_found:
            save_log("Owner Verified", best_similarity, filename)
            send_telegram_message(f"✅ OWNER VERIFIED\nSimilarity: {best_similarity}%")
            if mobile_token:
                try:
                    send_notification(mobile_token, "✅ Owner Verified",
                                      f"Similarity: {best_similarity}%")
                except Exception:
                    pass
            return jsonify({"success": True, "verified": True,
                            "similarity": best_similarity, "message": "Owner Verified"})

        pending_access = {"status": "WAITING", "result": "Unknown Visitor",
                          "time": str(datetime.now()),
                          "image": f"http://{SERVER_IP}:5000/visitor_image",
                          "similarity": best_similarity}
        save_log("Intruder Detected", best_similarity, filename)
        send_telegram_message(f"🚨 INTRUDER DETECTED\nSimilarity: {best_similarity}%")
        send_telegram_photo(image_path, "Approval Required")
        if mobile_token:
            try:
                send_notification(mobile_token, "🚨 Intruder Detected!",
                                  f"Similarity: {best_similarity}%. Approve or Reject.")
            except Exception:
                pass
        return jsonify({"success": True, "verified": False,
                        "similarity": best_similarity, "message": "Intruder Detected"})

    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

@app.route("/evidence", methods=["POST"])
@require_auth
def save_evidence():
    try:
        if "image" not in request.files:
            return jsonify({"success": False, "message": "No Image"})
        image      = request.files["image"]
        timestamp  = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename   = f"evidence_{timestamp}_{uuid.uuid4().hex[:8]}.jpg"
        image_path = os.path.join(VISITORS_FOLDER, filename)
        image.save(image_path)
        save_visitor_image(filename)
        save_log("Evidence Captured", 0, filename)
        send_telegram_photo(image_path, "🚨 INTRUDER EVIDENCE")
        return jsonify({"success": True, "filename": filename})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

# ==========================================
# OWNER FACES
# ==========================================

@app.route("/owner_faces")
@require_auth
def list_owner_faces():
    try:
        files = [f for f in os.listdir(OWNER_FOLDER)
                 if f.lower().endswith((".jpg", ".jpeg", ".png"))]
        return jsonify({"success": True, "faces": [{"filename": f} for f in files]})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

@app.route("/owner_face_image/<filename>")
@require_auth
def get_owner_face_image(filename):
    return send_from_directory(OWNER_FOLDER, filename)

@app.route("/upload_owner_face", methods=["POST"])
@require_auth
def upload_owner_face():
    try:
        if "image" not in request.files:
            return jsonify({"success": False, "message": "No image"})
        image    = request.files["image"]
        existing = [f for f in os.listdir(OWNER_FOLDER)
                    if f.lower().endswith((".jpg", ".jpeg", ".png"))]
        filename  = f"owner_face{len(existing)+1}.png"
        save_path = os.path.join(OWNER_FOLDER, filename)
        image.save(save_path)
        add_system_event(f"Owner face uploaded: {filename}")
        return jsonify({"success": True, "filename": filename})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

@app.route("/owner_faces/<filename>", methods=["DELETE"])
@require_auth
def delete_owner_face(filename):
    try:
        file_path = os.path.join(OWNER_FOLDER, filename)
        if not os.path.exists(file_path):
            return jsonify({"success": False, "message": "File not found"})
        os.remove(file_path)
        add_system_event(f"Owner face deleted: {filename}")
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

@app.route("/test_fcm")
@require_auth
def test_fcm():
    global mobile_token
    try:
        if not mobile_token:
            return jsonify({"success": False, "message": "No token"})
        send_notification(mobile_token, "AI Smart Locker", "FCM Test")
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)})

@app.route("/approval_page")
def approval_page():
    s          = pending_access.get("status", "NONE")
    image_url  = f"http://{SERVER_IP}:5000/visitor_image"
    similarity = pending_access.get("similarity", "")
    event_time = pending_access.get("time", "")
    if s == "WAITING":
        body = f"<div class='card'><h2>⚠️ Unknown Visitor</h2><p>Similarity: <b>{similarity}%</b> | {event_time}</p><img src='{image_url}'><div class='buttons'><a href='/approve' class='btn approve'>✅ APPROVE</a><a href='/reject' class='btn reject'>❌ REJECT</a></div></div>"
    elif s == "APPROVED":
        body = "<div class='card ok'><h2>✅ Approved</h2></div>"
    elif s == "REJECTED":
        body = "<div class='card bad'><h2>❌ Rejected</h2></div>"
    else:
        body = "<div class='card'><h2>✅ Secure</h2></div>"
    return f"""<!DOCTYPE html><html><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>AI Smart Locker</title><meta http-equiv='refresh' content='2'><style>body{{font-family:Arial,sans-serif;background:#1a1a2e;color:#eee;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;padding:16px}}.card{{background:#16213e;border-radius:16px;padding:24px;max-width:400px;width:100%;text-align:center}}.card img{{width:100%;border-radius:12px;margin:16px 0;max-height:280px;object-fit:cover}}.buttons{{display:flex;gap:12px;margin-top:16px}}.btn{{flex:1;padding:16px;border-radius:12px;text-decoration:none;font-size:1.1em;font-weight:bold;color:#fff}}.approve{{background:#27ae60}}.reject{{background:#c0392b}}</style></head><body>{body}</body></html>"""

# ==========================================
# MAIN
# ==========================================

if __name__ == "__main__":
    add_system_event("Server Started")
    print("SERVER READY")
    app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False, threaded=True)
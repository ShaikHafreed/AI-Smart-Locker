from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from recognize_uploaded import recognize_person
from datetime import datetime
import requests
import os

app = Flask(__name__)
CORS(app)

# ==========================================
# CONFIG
# ==========================================

UPLOAD_FOLDER = "uploads"

BOT_TOKEN = "8789816213:AAEfGykEzavCywDbMHcMy0S5fV0fmREiC3s"
CHAT_ID = "8698563696"

os.makedirs(
    UPLOAD_FOLDER,
    exist_ok=True
)

# ==========================================
# STATUS STORAGE
# ==========================================

locker_status = {
    "locker": "ONLINE",
    "door": "CLOSED",
    "owner": "UNKNOWN",
    "alert": "NO ALERT",
    "time": "-"
}

# ==========================================
# ACCESS LOGS
# ==========================================

access_logs = []

# ==========================================
# PENDING APPROVAL
# ==========================================

pending_access = {
    "status": "NONE",
    "image": "",
    "time": "",
    "result": ""
}

# ==========================================
# TELEGRAM MESSAGE
# ==========================================

def send_telegram_alert(message):

    try:

        url = (
            f"https://api.telegram.org/bot"
            f"{BOT_TOKEN}/sendMessage"
        )

        requests.post(
            url,
            data={
                "chat_id": CHAT_ID,
                "text": message
            }
        )

    except Exception as e:

        print(
            "Telegram Message Error:",
            e
        )

# ==========================================
# TELEGRAM PHOTO
# ==========================================

def send_telegram_photo(
    image_path,
    caption
):

    try:

        url = (
            f"https://api.telegram.org/bot"
            f"{BOT_TOKEN}/sendPhoto"
        )

        with open(
            image_path,
            "rb"
        ) as photo:

            requests.post(
                url,
                data={
                    "chat_id": CHAT_ID,
                    "caption": caption
                },
                files={
                    "photo": photo
                }
            )

    except Exception as e:

        print(
            "Telegram Photo Error:",
            e
        )

# ==========================================
# TEST
# ==========================================

@app.route("/test")
def test():

    return "TEST WORKING"

# ==========================================
# STATUS
# ==========================================

@app.route("/status")
def status():

    return jsonify(
        locker_status
    )

# ==========================================
# PENDING ACCESS
# ==========================================

@app.route("/pending_access")
def pending_access_route():

    return jsonify(
        pending_access
    )

# ==========================================
# APPROVE
# ==========================================

@app.route("/approve")
def approve():

    pending_access["status"] = "APPROVED"

    return jsonify({
        "message": "APPROVED"
    })

# ==========================================
# REJECT
# ==========================================

@app.route("/reject")
def reject():

    pending_access["status"] = "REJECTED"

    return jsonify({
        "message": "REJECTED"
    })


# ==========================================
# CHECK ACCESS STATUS
# ==========================================

@app.route("/check_access_status")
def check_access_status():

    return jsonify({
        "status":
            pending_access["status"]
    })


# ==========================================
# RESET ACCESS STATUS
# ==========================================

@app.route("/reset_access_status")
def reset_access_status():

    pending_access["status"] = "NONE"

    return jsonify({
        "message":
            "RESET SUCCESS"
    })

# ==========================================
# IMAGE UPLOAD
# ==========================================

@app.route(
    "/upload",
    methods=["POST"]
)
def upload():

    image = request.data

    if len(image) == 0:

        return "NO IMAGE", 400

    filename = (
        f"intruder_"
        f"{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
    )

    filepath = os.path.join(
        UPLOAD_FOLDER,
        filename
    )

    with open(
        filepath,
        "wb"
    ) as f:

        f.write(image)

    print(
        "IMAGE SAVED:",
        filepath
    )

    result = recognize_person(
        filepath
    )

    print(
        "RECOGNITION:",
        result
    )

    current_time = datetime.now().strftime(
        "%d-%m-%Y %H:%M:%S"
    )

    locker_status["door"] = "OPEN"
    locker_status["time"] = current_time

    # ======================================
    # OWNER
    # ======================================

    if result == "OWNER":

        locker_status["owner"] = "VERIFIED"

        locker_status["alert"] = (
            "OWNER VERIFIED"
        )

        pending_access["status"] = "NONE"
        pending_access["image"] = ""
        pending_access["time"] = ""
        pending_access["result"] = ""

        send_telegram_alert(
            f"✅ OWNER VERIFIED\n\n"
            f"Time: {current_time}"
        )

    # ======================================
    # UNKNOWN / INTRUDER
    # ======================================

    else:

        locker_status["owner"] = "UNKNOWN"

        locker_status["alert"] = (
            "ACCESS APPROVAL REQUIRED"
        )

        pending_access["status"] = "WAITING"

        pending_access["image"] = (
            f"http://192.168.31.229:5000/image/{filename}"
        )

        pending_access["time"] = (
            current_time
        )

        pending_access["result"] = (
            result
        )

        send_telegram_alert(
            f"🚨 ACCESS REQUEST\n\n"
            f"Result: {result}\n"
            f"Time: {current_time}\n\n"
            f"Open mobile app and "
            f"Approve or Reject."
        )

        send_telegram_photo(
            filepath,
            "🚨 Approval Required"
        )

    access_logs.insert(
        0,
        {
            "time": current_time,
            "result": result
        }
    )

    return jsonify(
        {
            "result": result
        }
    )

# ==========================================
# LOGS
# ==========================================

@app.route("/logs")
def logs():

    return jsonify(
        access_logs
    )

# ==========================================
# DOOR CLOSED
# ==========================================

@app.route("/door_closed")
def door_closed():

    locker_status["door"] = "CLOSED"

    return "OK"

# ==========================================
# IMAGES
# ==========================================

@app.route("/images")
def images():

    files = os.listdir(
        UPLOAD_FOLDER
    )

    image_urls = []

    for file in reversed(files):

        image_urls.append(
            f"http://192.168.31.229:5000/image/{file}"
        )

    return jsonify(
        image_urls
    )

# ==========================================
# VIEW IMAGE
# ==========================================

@app.route("/image/<filename>")
def image(filename):

    return send_from_directory(
        UPLOAD_FOLDER,
        filename
    )

# ==========================================
# MAIN
# ==========================================

if __name__ == "__main__":

    app.run(
        host="0.0.0.0",
        port=5000
    )
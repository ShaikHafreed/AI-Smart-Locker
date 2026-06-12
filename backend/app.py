from flask import (
    Flask,
    request,
    jsonify,
    send_file
)

from deepface import DeepFace
from datetime import datetime
import os

app = Flask(__name__)

# ====================================
# PATHS
# ====================================

BASE_DIR = os.path.dirname(
    os.path.abspath(__file__)
)

OWNER_FACE = os.path.join(
    BASE_DIR,
    "owner_face.jpg"
)

VISITOR_FACE = os.path.join(
    BASE_DIR,
    "visitor.jpg"
)

# ====================================
# MEMORY STORAGE
# ====================================

pending_access = {
    "status": "No Request",
    "result": "",
    "time": "",
    "image": "",
    "similarity": ""
}

logs = []

# ====================================
# VERIFY FACE
# ====================================

@app.route(
    "/verify",
    methods=["POST"]
)
def verify_face():

    global pending_access

    if "image" not in request.files:
        return jsonify({
            "success": False,
            "message": "No image uploaded"
        })

    image = request.files["image"]

    image.save(
        VISITOR_FACE
    )

    try:

        result = DeepFace.verify(
            img1_path=OWNER_FACE,
            img2_path=VISITOR_FACE,
            model_name="Facenet512",
            enforce_detection=True
        )

        print("\n========== RESULT ==========")
        print(result)
        print("============================\n")

        distance = float(
            result["distance"]
        )

        similarity = round(
            (1 - distance) * 100,
            2
        )

        # --------------------------------
        # PROJECT RULE
        # --------------------------------

        if similarity >= 80:
            decision = "OWNER"

        elif similarity >= 70:
            decision = "REVIEW"

        else:
            decision = "INTRUDER"

        # =================================
        # OWNER VERIFIED
        # =================================

        if decision == "OWNER":

            logs.append({
                "time":
                str(datetime.now()),

                "result":
                "Owner Verified",

                "similarity":
                similarity
            })

            return jsonify({

                "success": True,

                "verified": True,

                "distance": distance,

                "similarity":
                similarity,

                "message":
                f"✅ Owner Verified\nSimilarity: {similarity}%"

            })

        # =================================
        # INTRUDER DETECTED
        # =================================

        else:

            pending_access = {

                "status":
                "Pending Approval",

                "result":
                "Unknown Visitor",

                "time":
                str(datetime.now()),

                "similarity":
                similarity,

                "image":
                "http://192.168.31.172:5000/visitor_image"
            }

            logs.append({

                "time":
                str(datetime.now()),

                "result":
                "Intruder Detected",

                "similarity":
                similarity
            })

            return jsonify({

                "success": True,

                "verified": False,

                "distance": distance,

                "similarity":
                similarity,

                "message":
                f"🚨 Intruder Detected\nSimilarity: {similarity}%"

            })

    except Exception as e:

        print(
            "DEEPFACE ERROR:",
            str(e)
        )

        return jsonify({

            "success": False,

            "message":
            str(e)

        })

# ====================================
# PENDING ACCESS
# ====================================

@app.route("/pending_access")
def get_pending_access():

    return jsonify(
        pending_access
    )

# ====================================
# APPROVE ACCESS
# ====================================

@app.route("/approve")
def approve():

    global pending_access

    logs.append({

        "time":
        str(datetime.now()),

        "result":
        "Access Approved"
    })

    pending_access = {

        "status":
        "Approved",

        "result":
        "Visitor Approved",

        "time":
        str(datetime.now()),

        "image":
        "",

        "similarity":
        ""
    }

    return jsonify({

        "success": True,

        "message":
        "Access Approved"
    })

# ====================================
# REJECT ACCESS
# ====================================

@app.route("/reject")
def reject():

    global pending_access

    logs.append({

        "time":
        str(datetime.now()),

        "result":
        "Access Rejected"
    })

    pending_access = {

        "status":
        "Rejected",

        "result":
        "Visitor Rejected",

        "time":
        str(datetime.now()),

        "image":
        "",

        "similarity":
        ""
    }

    return jsonify({

        "success": True,

        "message":
        "Access Rejected"
    })

# ====================================
# STATUS
# ====================================

# ====================================
# STATUS
# ====================================

@app.route("/status")
def status():

    total_logs = len(logs)

    last_event = (
        logs[-1]["result"]
        if len(logs) > 0
        else "No Activity"
    )

    intruder_count = len([
        log for log in logs
        if log["result"] == "Intruder Detected"
    ])

    return jsonify({

        "locker": "Locked",

        "pending":
        pending_access["status"],

        "total_logs":
        total_logs,

        "last_event":
        last_event,

        "intruder_count":
        intruder_count
    })

# ====================================
# LOGS
# ====================================

@app.route("/logs")
def get_logs():

    return jsonify(
        logs
    )

# ====================================
# VISITOR IMAGE
# ====================================

@app.route("/visitor_image")
def visitor_image():

    if os.path.exists(
        VISITOR_FACE
    ):

        return send_file(
            VISITOR_FACE,
            mimetype="image/jpeg"
        )

    return jsonify({

        "success": False,

        "message":
        "No image found"
    })

# ====================================
# RUN SERVER
# ====================================

if __name__ == "__main__":

    app.run(
        host="0.0.0.0",
        port=5000,
        debug=True
    )
from flask import (
    Flask,
    request,
    jsonify,
    send_file
)

from deepface import DeepFace

from datetime import datetime

from fcm_service import (
    send_notification
)

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
# STORAGE
# ====================================

mobile_token = ""

pending_access = {

    "status": "No Request",

    "result": "",

    "time": "",

    "image": "",

    "similarity": ""
}

logs = []

# ====================================
# REGISTER TOKEN
# ====================================

@app.route(
    "/register_token",
    methods=["POST"]
)
def register_token():

    global mobile_token

    data = request.json

    mobile_token = data["token"]

    print(
        "\nTOKEN SAVED\n",
        mobile_token
    )

    return jsonify({
        "success": True
    })

# ====================================
# VERIFY FACE
# ====================================

@app.route("/verify", methods=["POST"])
def verify_face():

    print("\nVERIFY API CALLED\n")

    global pending_access
    

    image = request.files["image"]

    image.save(
        VISITOR_FACE
        print("VISITOR SAVED:", VISITOR_FACE)
        print("FILE EXISTS:", os.path.exists(VISITOR_FACE))
    )

    try:

        owner_folder = os.path.join(
            BASE_DIR,
            "owner_faces"
        )

        best_similarity = 0
        best_owner_image = ""

        for file in os.listdir(owner_folder):

            if not file.lower().endswith(
                (".jpg", ".jpeg", ".png")
            ):
                continue

            owner_image = os.path.join(
                owner_folder,
                file
            )

            try:

                result = DeepFace.verify(
                    img1_path=owner_image,
                    img2_path=VISITOR_FACE,
                    model_name="ArcFace",
                    detector_backend="opencv",
                    enforce_detection=True
                )

                distance = float(
                    result["distance"]
                )

                similarity = round(
                    (1 - distance) * 100,
                    2
                )

                print(
                    f"{file} => {similarity}%"
                )

                if similarity > best_similarity:

                    best_similarity = similarity
                    best_owner_image = file

            except Exception as face_error:

                print(
                    "FACE ERROR:",
                    face_error
                )

        print(
            "\nBEST MATCH:",
            best_owner_image,
            best_similarity
        )

        similarity = best_similarity

        # ==========================
        # OWNER VERIFIED
        # ==========================

        if similarity >= 80:

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

                "similarity":
                similarity,

                "message":
                f"Owner Verified {similarity}%"
            })

        # ==========================
        # INTRUDER
        # ==========================

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

        if mobile_token != "":

            send_notification(

                mobile_token,

                "🚨 Unknown Visitor",

                f"Similarity {similarity}% - Approval Required"
            )

        return jsonify({

            "success": True,

            "verified": False,

            "similarity":
            similarity,

            "message":
            f"Intruder Detected {similarity}%"
        })

    except Exception as e:

        return jsonify({

            "success": False,

            "message":
            str(e)
        })
# ====================================
# APPROVE
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

    if mobile_token != "":

        send_notification(

            mobile_token,

            "✅ Access Approved",

            "Visitor Approved"
        )

    return jsonify({

        "success": True
    })

# ====================================
# REJECT
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

    if mobile_token != "":

        send_notification(

            mobile_token,

            "❌ Access Rejected",

            "Visitor Rejected"
        )

    return jsonify({

        "success": True
    })

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

        log

        for log in logs

        if log["result"]
        ==
        "Intruder Detected"
    ])

    return jsonify({

        "locker":
        "Locked",

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
# PENDING ACCESS
# ====================================

@app.route("/pending_access")
def get_pending_access():

    return jsonify(
        pending_access
    )

# ====================================
# VISITOR IMAGE
# ====================================

@app.route("/visitor_image")
def visitor_image():

    global LATEST_VISITOR_IMAGE

    try:

        if (
            LATEST_VISITOR_IMAGE != ""
            and
            os.path.exists(
                LATEST_VISITOR_IMAGE
            )
        ):

            return send_file(
                LATEST_VISITOR_IMAGE,
                mimetype="image/jpeg"
            )

        return jsonify({

            "success": False,

            "message":
            "No Visitor Image"
        })

    except Exception as e:

        return jsonify({

            "success": False,

            "message":
            str(e)
        })
# ====================================
# MAIN
# ====================================

if __name__ == "__main__":

    app.run(

        host="0.0.0.0",

        port=5000,

        debug=True
    )
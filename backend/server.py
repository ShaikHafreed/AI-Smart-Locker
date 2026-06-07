from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from recognize_uploaded import recognize_person

from datetime import datetime
import os

app = Flask(__name__)
CORS(app)

UPLOAD_FOLDER = "uploads"

os.makedirs(
    UPLOAD_FOLDER,
    exist_ok=True
)

locker_status = {
    "locker": "ONLINE",
    "door": "CLOSED",
    "owner": "UNKNOWN",
    "alert": "NO ALERT"
}


@app.route("/test")
def test():
    return "TEST WORKING"


@app.route("/status")
def status():

    return jsonify(locker_status)


@app.route('/upload', methods=['POST'])
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

    with open(filepath, "wb") as f:
        f.write(image)

    print("IMAGE SAVED:", filepath)

    result = recognize_person(filepath)

    print("RECOGNITION:", result)

    locker_status["door"] = "OPEN"

    if result == "OWNER":

        locker_status["owner"] = "VERIFIED"
        locker_status["alert"] = "NO INTRUDER DETECTED"

    else:

        locker_status["owner"] = "UNKNOWN"
        locker_status["alert"] = "INTRUDER DETECTED"

    return "SUCCESS", 200

@app.route("/images")
def images():

    files = os.listdir(UPLOAD_FOLDER)

    image_urls = []

    for file in files:

        image_urls.append(
            f"http://192.168.31.229:5000/image/{file}"
        )

    return jsonify(image_urls)


@app.route("/image/<filename>")
def image(filename):

    return send_from_directory(
        UPLOAD_FOLDER,
        filename
    )


if __name__ == "__main__":

    app.run(
        host="0.0.0.0",
        port=5000
    )
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from datetime import datetime
import os

app = Flask(__name__)
CORS(app)

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


# -------------------------
# Locker Status API
# -------------------------
@app.route('/test')
def test():
    return "TEST WORKING"

@app.route('/status')
def status():

    return jsonify({
        "locker": "ONLINE",
        "door": "CLOSED",
        "owner": "VERIFIED",
        "alert": "NO INTRUDER DETECTED"
    })


# -------------------------
# ESP32 Upload API
# -------------------------
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

    return "SUCCESS", 200


# -------------------------
# Get All Images
# -------------------------
@app.route('/images')
def images():

    files = os.listdir(UPLOAD_FOLDER)

    image_urls = []

    for file in files:

        image_urls.append(
            f"http://192.168.31.229:5000/image/{file}"
        )

    return jsonify(image_urls)


# -------------------------
# Serve Single Image
# -------------------------
@app.route('/image/<filename>')
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
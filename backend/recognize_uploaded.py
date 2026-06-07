import cv2
import os

recognizer = cv2.face.LBPHFaceRecognizer_create()

MODEL_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "ai_recognition",
    "owner_model.yml"
)

recognizer.read(MODEL_PATH)

face_detector = cv2.CascadeClassifier(
    cv2.data.haarcascades +
    "haarcascade_frontalface_default.xml"
)


def recognize_person(image_path):

    image = cv2.imread(image_path)

    if image is None:
        return "UNKNOWN"

    gray = cv2.cvtColor(
        image,
        cv2.COLOR_BGR2GRAY
    )

    faces = face_detector.detectMultiScale(
        gray,
        1.2,
        5
    )

    for (x, y, w, h) in faces:

        face = gray[y:y+h, x:x+w]

        _, confidence = recognizer.predict(face)

        print("Confidence:", confidence)

        if confidence < 60:
            return "OWNER"

        return "INTRUDER"

    return "NO_FACE"
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
        scaleFactor=1.1,
        minNeighbors=4,
        minSize=(50, 50)
    )

    print("Faces Found:", len(faces))

    for (x, y, w, h) in faces:

        face = gray[y:y+h, x:x+w]

        try:
            face = cv2.resize(
                face,
                (200, 200)
            )
        except:
            continue

        label, confidence = recognizer.predict(face)

        print("Confidence:", confidence)

        # Lower confidence = better match

        if confidence < 100:
            return "OWNER"

        return "INTRUDER"

    return "NO_FACE"
import cv2
import os
import time

# Load trained model
recognizer = cv2.face.LBPHFaceRecognizer_create()
recognizer.read("face_recognition/owner_model.yml")

# Face detector
face_detector = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

# Camera
camera = cv2.VideoCapture(0)

# Create intruder folder
os.makedirs("images/intruders", exist_ok=True)

print("🔐 AI Smart Locker Started")

while True:

    ret, frame = camera.read()

    if not ret:
        print("❌ Camera error")
        break

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    faces = face_detector.detectMultiScale(
        gray,
        scaleFactor=1.1,
        minNeighbors=5,
        minSize=(100, 100)
    )

    for (x, y, w, h) in faces:

        face = gray[y:y+h, x:x+w]

        id, confidence = recognizer.predict(face)

        # Lower confidence = better match
        if confidence < 60:

            label = "OWNER DETECTED"
            color = (0, 255, 0)

        else:

            label = "INTRUDER ALERT!"
            color = (0, 0, 255)

            # Save intruder image
            timestamp = int(time.time())

            intruder_path = f"images/intruders/intruder_{timestamp}.jpg"

            cv2.imwrite(intruder_path, frame)

            print(f"🚨 Intruder saved: {intruder_path}")

        # Draw rectangle
        cv2.rectangle(frame, (x, y), (x+w, y+h), color, 3)

        # Show label
        cv2.putText(
            frame,
            label,
            (x, y - 10),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            color,
            2
        )

    cv2.imshow("AI SMART LOCKER", frame)

    key = cv2.waitKey(1)

    if key == ord('q'):
        break

camera.release()
cv2.destroyAllWindows()
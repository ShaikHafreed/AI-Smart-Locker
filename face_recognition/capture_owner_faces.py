import cv2
import os

# Create folder if not exists
dataset_path = "images/owner"
os.makedirs(dataset_path, exist_ok=True)

# Load camera
camera = cv2.VideoCapture(0)

# Load face detector
face_detector = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

count = 0

print("📸 Capturing owner face images...")

while True:
    ret, frame = camera.read()

    if not ret:
        print("❌ Failed to access camera")
        break

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    faces = face_detector.detectMultiScale(gray, 1.3, 5)

    for (x, y, w, h) in faces:

        count += 1

        face_image = gray[y:y+h, x:x+w]

        file_name = os.path.join(dataset_path, f"owner_{count}.jpg")

        cv2.imwrite(file_name, face_image)

        cv2.rectangle(frame, (x, y), (x+w, y+h), (0,255,0), 2)

        print(f"✅ Saved: {file_name}")

    cv2.imshow("Owner Face Capture", frame)

    key = cv2.waitKey(1)

    if key == ord('q') or count >= 20:
        break

camera.release()
cv2.destroyAllWindows()

print("✅ Dataset collection completed!")
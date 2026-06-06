import cv2
import os
import numpy as np
from PIL import Image

# Create recognizer
recognizer = cv2.face.LBPHFaceRecognizer_create()

# Haarcascade face detector
detector = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

# Dataset path
dataset_path = "images/owner"

face_samples = []
ids = []

# Read all images
for image_name in os.listdir(dataset_path):

    image_path = os.path.join(dataset_path, image_name)

    print("Reading:", image_path)

    pil_image = Image.open(image_path).convert('L')

    image_np = np.array(pil_image, 'uint8')

    faces = detector.detectMultiScale(image_np)

    for (x, y, w, h) in faces:
        face_samples.append(image_np[y:y+h, x:x+w])
        ids.append(1)

# Check if faces found
if len(face_samples) == 0:
    print("❌ No faces detected in images.")
    exit()

# Train model
recognizer.train(face_samples, np.array(ids))

# Save model
recognizer.save("face_recognition/owner_model.yml")

print("✅ Face Recognition Model Trained Successfully!")
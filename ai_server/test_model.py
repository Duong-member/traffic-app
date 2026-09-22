from ultralytics import YOLO

# Load model
model = YOLO("models/best.pt")

# Ảnh biển 80
IMAGE_PATH = r"test_images\bien80-crop.jpg"

print("\n==============================")
print("MODEL CLASSES")
print("==============================")

print("Class 53 =", model.names[53])

print("\n==============================")
print("TEST BIEN 80")
print("==============================")

results = model.predict(
    source=IMAGE_PATH,
    conf=0.00001,
    imgsz=640,
    verbose=True
)

for result in results:

    if result.boxes is None or len(result.boxes) == 0:
        print("KHONG CO DETECTION")
        continue

    print("\n===== DETECTIONS =====")

    for box in result.boxes:

        class_id = int(box.cls[0])
        confidence = float(box.conf[0])

        print(
            f"class_id={class_id} | "
            f"name={model.names[class_id]} | "
            f"confidence={confidence:.6f}"
        )
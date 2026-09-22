from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO
from PIL import Image
import io
import os


# =========================================================
# FASTAPI
# =========================================================

app = FastAPI(
    title="Traffic Sign AI Server",
    description="YOLOv8 Traffic Sign Recognition API",
    version="1.0"
)


# =========================================================
# CORS
# =========================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =========================================================
# LOAD MODEL
# =========================================================

MODEL_PATH = os.path.join(
    os.path.dirname(__file__),
    "models",
    "best.pt"
)

print("======================================")
print("       TRAFFIC SIGN AI SERVER")
print("======================================")
print("Model:", MODEL_PATH)

if not os.path.exists(MODEL_PATH):
    raise FileNotFoundError(
        f"Không tìm thấy model: {MODEL_PATH}"
    )

model = YOLO(MODEL_PATH)

print("Model loaded successfully!")
print("Task:", model.task)
print("Number of classes:", len(model.names))

print("\nClasses:")
for class_id, class_name in model.names.items():
    print(f"{class_id}: {class_name}")

print("======================================")


# =========================================================
# SPEED LIMIT CONFIGURATION
# =========================================================

# Class ID của các biển giới hạn tốc độ
SPEED_LIMIT_CLASSES = {
    50: 40,
    51: 50,
    52: 60,
    53: 80
}

# Confidence tối thiểu để công nhận biển báo
SPEED_LIMIT_MIN_CONFIDENCE = 0.50


# =========================================================
# HEALTH CHECK
# =========================================================

@app.get("/")
def root():

    return {
        "status": "ok",
        "message": "Traffic Sign AI Server is running",
        "model": "best.pt",
        "task": model.task
    }


# =========================================================
# MODEL INFORMATION
# =========================================================

@app.get("/model")
def model_info():

    return {
        "model": "best.pt",
        "task": model.task,
        "number_of_classes": len(model.names),
        "classes": model.names
    }


# =========================================================
# PREDICT
# =========================================================

@app.post("/predict")
async def predict(
    file: UploadFile = File(...)
):

    # =====================================================
    # 1. KIỂM TRA FILE
    # =====================================================

    if not file.content_type:

        return {
            "success": False,
            "message": "Không xác định được loại file"
        }

    if not file.content_type.startswith("image/"):

        return {
            "success": False,
            "message": "File gửi lên phải là hình ảnh"
        }


    # =====================================================
    # 2. ĐỌC ẢNH
    # =====================================================

    try:

        image_bytes = await file.read()

        if not image_bytes:

            return {
                "success": False,
                "message": "File ảnh rỗng"
            }

        image = Image.open(
            io.BytesIO(image_bytes)
        ).convert("RGB")

    except Exception as e:

        return {
            "success": False,
            "message": f"Không thể đọc ảnh: {str(e)}"
        }


    # =====================================================
    # 3. YOLO PREDICTION
    # =====================================================

    try:

        results = model.predict(
            source=image,

            # Giữ thấp để model có cơ hội phát hiện
            conf=0.001,

            # Kích thước ảnh
            imgsz=640,

            # IoU cho NMS
            iou=0.5,

            verbose=False
        )

    except Exception as e:

        return {
            "success": False,
            "message": f"Lỗi khi chạy YOLO: {str(e)}"
        }


    # =====================================================
    # 4. LẤY KẾT QUẢ DETECTION
    # =====================================================

    detections = []

    for result in results:

        if result.boxes is None:
            continue

        for box in result.boxes:

            class_id = int(box.cls[0])

            confidence = float(box.conf[0])

            xyxy = box.xyxy[0].tolist()

            detection = {
                "class_id": class_id,
                "name": model.names[class_id],
                "confidence": round(confidence, 4),

                "bbox": {
                    "x1": round(xyxy[0], 2),
                    "y1": round(xyxy[1], 2),
                    "x2": round(xyxy[2], 2),
                    "y2": round(xyxy[3], 2)
                }
            }

            detections.append(detection)


    # =====================================================
    # 5. SẮP XẾP CONFIDENCE CAO → THẤP
    # =====================================================

    detections.sort(
        key=lambda x: x["confidence"],
        reverse=True
    )


    # =====================================================
    # 6. TÌM BIỂN GIỚI HẠN TỐC ĐỘ
    # =====================================================

    speed_limit = None

    for detection in detections:

        class_id = detection["class_id"]

        confidence = detection["confidence"]

        if (
            class_id in SPEED_LIMIT_CLASSES
            and
            confidence >= SPEED_LIMIT_MIN_CONFIDENCE
        ):

            speed_limit = {
                "class_id": class_id,
                "name": detection["name"],
                "speed": SPEED_LIMIT_CLASSES[class_id],
                "confidence": confidence,
                "bbox": detection["bbox"]
            }

            break


    # =====================================================
    # 7. TRẠNG THÁI BIỂN GIỚI HẠN TỐC ĐỘ
    # =====================================================

    detected_speed_limit = speed_limit is not None


    # =====================================================
    # 8. TRẢ KẾT QUẢ
    # =====================================================

    return {

        "success": True,

        "filename": file.filename,

        # Có phát hiện biển giới hạn tốc độ hay không
        "detected_speed_limit": detected_speed_limit,

        # Thông tin biển tốc độ
        "speed_limit": speed_limit,

        # Tất cả detection của YOLO
        "detections": detections,

        # Số lượng detection
        "count": len(detections)
    }


# =========================================================
# RUN SERVER
# =========================================================

if __name__ == "__main__":

    import uvicorn

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000
    )
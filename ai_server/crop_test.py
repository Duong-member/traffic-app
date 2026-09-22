from PIL import Image

IMAGE_PATH = r"C:\Users\nguye\Downloads\bien80-dataset.jpg"

image = Image.open(IMAGE_PATH)

# Crop rộng hơn quanh biển 80
crop = image.crop((
    165,   # x1
    165,   # y1
    225,   # x2
    220    # y2
))

crop.save("test_images/bien80-crop.jpg")

print("Đã tạo: test_images/bien80-crop.jpg")
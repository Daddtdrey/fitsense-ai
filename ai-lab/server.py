from fastapi import FastAPI, UploadFile, File
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware # <--- NEW IMPORT
from rembg import remove
from PIL import Image
import io

app = FastAPI()

# --- NEW: ALLOW CHROME TO TALK TO PYTHON ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# -------------------------------------------

print("--- FitSense AI Server is Starting ---")

@app.get("/")
def home():
    return {"message": "FitSense AI is alive!"}

@app.post("/clean-image")
async def clean_image(file: UploadFile = File(...)):
    print(f"Received file: {file.filename}")
    image_data = await file.read()
    input_image = Image.open(io.BytesIO(image_data))
    
    print("Removing background...")
    clean_image = remove(input_image)

    output_buffer = io.BytesIO()
    clean_image.save(output_buffer, format="PNG")
    output_bytes = output_buffer.getvalue()

    return Response(content=output_bytes, media_type="image/png")
import os
import gc
from fastapi import FastAPI, UploadFile, File
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
from rembg import remove, new_session
from PIL import Image
import io

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# LOAD LITE MODEL
print("--- Loading Lite AI Model... ---")
# 'u2netp' is the lightweight version
session = new_session("u2netp")
print("--- Model Loaded. ---")

@app.get("/")
def home():
    return {"message": "FitSense AI (Lite + Resize) is Online"}

@app.post("/clean-image")
async def clean_image(file: UploadFile = File(...)):
    try:
        print(f"Received file: {file.filename}")

        # 1. Read Image
        image_data = await file.read()
        input_image = Image.open(io.BytesIO(image_data))

        # 2. THE FIX: Resize massive photos
        # We cap the size at 500x500 pixels. 
        # This keeps RAM usage VERY low.
        input_image.thumbnail((500, 500)) 
        print(f"Resized image to: {input_image.size}")

        # 3. Process with Lite Session
        print("Removing background...")
        clean_image = remove(input_image, session=session)

        # 4. Save to Buffer
        output_buffer = io.BytesIO()
        clean_image.save(output_buffer, format="PNG")
        output_bytes = output_buffer.getvalue()

        # 5. Aggressive Cleanup
        del input_image
        del clean_image
        del image_data
        gc.collect()

        return Response(content=output_bytes, media_type="image/png")
    
    except Exception as e:
        print(f"ERROR: {e}")
        return Response(content=f"Server Error: {e}".encode(), status_code=500)
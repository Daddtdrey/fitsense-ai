import os
import gc
from fastapi import FastAPI, UploadFile, File
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
from rembg import remove, new_session
from PIL import Image
import io

app = FastAPI()

# 1. ALLOW CHROME/VERCEL ACCESS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. LOAD THE "LITE" MODEL (u2netp)
# This model is 4MB (vs the standard 176MB)
print("--- Loading Lite AI Model... ---")
model_name = "u2netp" 
session = new_session(model_name)
print("--- Model Loaded. ---")

@app.get("/")
def home():
    return {"message": "FitSense AI is online (Lite Mode)"}

@app.post("/clean-image")
async def clean_image(file: UploadFile = File(...)):
    print(f"Received file: {file.filename}")

    # A. Read Image
    image_data = await file.read()
    input_image = Image.open(io.BytesIO(image_data))

    # B. Process with Lite Session
    print("Removing background...")
    clean_image = remove(input_image, session=session)

    # C. Save to Buffer
    output_buffer = io.BytesIO()
    clean_image.save(output_buffer, format="PNG")
    output_bytes = output_buffer.getvalue()

    # D. MEMORY CLEANUP (Crucial for Free Tier)
    del input_image
    del clean_image
    del image_data
    gc.collect() # Force Python to empty the trash
    print("Memory cleaned.")

    return Response(content=output_bytes, media_type="image/png")
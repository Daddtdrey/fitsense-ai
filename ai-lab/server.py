from fastapi import FastAPI, UploadFile, File
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
from rembg import remove, new_session 
from PIL import Image
import io

app = FastAPI()

# Allow Chrome/Vercel to talk to us
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# PRE-LOAD THE LIGHTWEIGHT MODEL
# We do this once at startup so it doesn't crash during the request
print("--- Loading AI Model (Lite Version)... ---")
model_name = "u2netp" # <--- The Lite Model (Uses less RAM)
session = new_session(model_name)
print("--- Model Loaded! Server Ready. ---")

@app.get("/")
def home():
    return {"message": "FitSense AI is alive!"}

@app.post("/clean-image")
async def clean_image(file: UploadFile = File(...)):
    print(f"Received file: {file.filename}")

    image_data = await file.read()
    input_image = Image.open(io.BytesIO(image_data))

    print("Removing background...")
    # Use the pre-loaded lite session
    clean_image = remove(input_image, session=session)

    output_buffer = io.BytesIO()
    clean_image.save(output_buffer, format="PNG")
    output_bytes = output_buffer.getvalue()

    return Response(content=output_bytes, media_type="image/png")
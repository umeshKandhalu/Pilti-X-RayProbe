# Clinical Decision Support System - Backend

## Setup
1. Create a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Running the Server
Start the FastAPI server with uvicorn:
```bash
uvicorn main:app --reload
```

The API will be available at `http://127.0.0.1:8000`.

## Endpoints
- `POST /analyze`: Upload an image file to get predictions and heatmap.
- `POST /generate_report`: Send analysis data to get a PDF report.
- `GET /health`: Check server status.

## Notes
- The model currently loads a pretrained DenseNet121 (ImageNet weights) adapted for 14 classes as a placeholder.
- Grad-CAM heatmap is currently a placeholder returning the original image.

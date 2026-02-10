from fastapi import APIRouter, HTTPException, Response, Depends
from app.models.schemas import ReportRequest
from app.services.report import ReportGenerator
from app.services.storage import MinioStorage
from app.api.deps import get_report_generator, get_storage
import base64
import io

router = APIRouter()

@router.post("/generate_report")
async def generate_report(
    request: ReportRequest,
    report_gen: ReportGenerator = Depends(get_report_generator),
    storage: MinioStorage = Depends(get_storage)
):
    try:
        # Decode base64 images
        def decode_image(b64_str):
            if not b64_str: return None
            if "," in b64_str:
                _, encoded = b64_str.split(",", 1)
            else:
                encoded = b64_str
            return base64.b64decode(encoded)

        original_image_bytes = decode_image(request.original_image)
        heatmap_image_bytes = decode_image(request.heatmap_image)
        
        pdf_bytes = report_gen.create_report(
            patient_id=request.patient_id,
            patient_name=request.patient_name,
            dob=request.dob,
            email=request.email,
            findings=request.findings,
            original_image_bytes=original_image_bytes,
            heatmap_image_bytes=heatmap_image_bytes,
            model_info=request.model_info
        )
        
        # Upload to MinIO
        # Folder structure: email/patient_id/
        base_path = f"{request.email}/{request.patient_id}"
        
        # Upload Original Image
        if original_image_bytes:
            storage.upload_file(
                io.BytesIO(original_image_bytes),
                f"{base_path}/original_xray.jpg",
                "image/jpeg"
            )
            
        # Upload Heatmap
        if heatmap_image_bytes:
            storage.upload_file(
                io.BytesIO(heatmap_image_bytes),
                f"{base_path}/heatmap.jpg",
                "image/jpeg"
            )
            
        # Upload PDF
        # Sanitize patient name for filename
        safe_name = "".join(c for c in request.patient_name if c.isalnum() or c in (' ', '_', '-')).strip().replace(' ', '_')
        pdf_filename = f"report_{request.patient_id}_{safe_name}.pdf"
        
        storage.upload_file(
            io.BytesIO(pdf_bytes),
            f"{base_path}/{pdf_filename}",
            "application/pdf"
        )
        
        return Response(content=pdf_bytes, media_type="application/pdf", headers={
            "Content-Disposition": f"attachment; filename={pdf_filename}"
        })
    except Exception as e:
        print(f"Error generating report: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/reports/{email}")
async def list_reports(email: str, storage: MinioStorage = Depends(get_storage)):
    """Lists all reports for a given email."""
    try:
        # List all objects under the email prefix
        objects = storage.list_files(f"{email}/")
        
        reports = []
        for obj in objects:
            key = obj['Key']
            # Expected structure: email/patient_id/report_patient_id_Name.pdf
            # Or legacy: email/patient_id/report_patient_id.pdf
            if key.endswith(".pdf"):
                parts = key.split("/")
                if len(parts) >= 3:
                    file_name = parts[-1]
                    patient_id = parts[1]
                    last_modified = obj['LastModified']
                    
                    # Extract name from filename report_{id}_{name}.pdf
                    patient_name = "Unknown"
                    try:
                        # Remove extension
                        name_part = file_name.replace(".pdf", "")
                        # Remove prefix "report_"
                        if name_part.startswith("report_"):
                            name_part = name_part[7:]
                        
                        # Remove patient_id if present at start
                        if name_part.startswith(patient_id):
                            name_part = name_part[len(patient_id):]
                        
                        # Clean up leading underscores/hyphens
                        name_part = name_part.lstrip("_-")
                        
                        if name_part:
                            patient_name = name_part.replace("_", " ")
                    except Exception as e:
                         print(f"Error parsing name: {e}")
                         pass

                    reports.append({
                        "patient_id": patient_id,
                        "patient_name": patient_name,
                        "date": last_modified.isoformat(),
                        "file_name": file_name
                    })
        
        # Sort by date, newest first
        reports.sort(key=lambda x: x['date'], reverse=True)
        return reports
    except Exception as e:
        print(f"Error listing reports: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/reports/{email}/{patient_id}/pdf")
async def get_report_pdf(email: str, patient_id: str, storage: MinioStorage = Depends(get_storage)):
    """Retrieves the PDF report for a specific patient."""
    try:
        # We need to find the file because the name part is variable
        prefix = f"{email}/{patient_id}/"
        objects = storage.list_files(prefix)
        
        target_key = None
        for obj in objects:
            key = obj['Key']
            if key.endswith(".pdf"):
                target_key = key
                break
        
        if not target_key:
             # Fallback to legacy path if list failed or empty
            target_key = f"{email}/{patient_id}/report_{patient_id}.pdf"

        file_bytes = storage.get_file(target_key)
        
        if not file_bytes:
            raise HTTPException(status_code=404, detail="Report not found")
            
        filename = target_key.split("/")[-1]
        return Response(content=file_bytes, media_type="application/pdf", headers={
            "Content-Disposition": f"inline; filename={filename}"
        })
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error retrieving report: {e}")
        raise HTTPException(status_code=500, detail=str(e))

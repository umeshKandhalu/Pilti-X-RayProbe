from fastapi import APIRouter, HTTPException, Response, Depends
from app.models.schemas import ReportRequest
from app.services.report import ReportGenerator
from app.services.storage import MinioStorage
from app.api.deps import get_report_generator, get_storage, get_current_user, get_auth_service, AuthService
import base64
import io

router = APIRouter()

@router.post("/generate_report")
async def generate_report(
    request: ReportRequest,
    report_gen: ReportGenerator = Depends(get_report_generator),
    storage: MinioStorage = Depends(get_storage),
    auth_service: AuthService = Depends(get_auth_service),
    current_user: str = Depends(get_current_user)
):
    # 1. Check Usage Limits (Storage only here, runs already checked in /analyze)
    allowed, message = auth_service.check_limits(current_user)
    if not allowed:
        raise HTTPException(status_code=403, detail=f"Quota Exceeded: {message}")

    if request.email != current_user:
        raise HTTPException(status_code=403, detail="Not authorized to generate report for another user")
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
        pinpoint_image_bytes = decode_image(request.pinpoint_image)
        
        waveform_image_bytes = decode_image(request.waveform_image)
        
        # Collect marked images
        marked_images_bytes = []
        if request.doctor_marked_images:
            for img_b64 in request.doctor_marked_images:
                img_bytes = decode_image(img_b64)
                if img_bytes:
                    marked_images_bytes.append(img_bytes)

        pdf_bytes = report_gen.create_report(
            patient_id=request.patient_id,
            patient_name=request.patient_name,
            dob=request.dob,
            email=request.email,
            findings=request.findings,
            original_image_bytes=original_image_bytes,
            heatmap_image_bytes=heatmap_image_bytes,
            pinpoint_image_bytes=pinpoint_image_bytes,
            doctor_marked_images_bytes=marked_images_bytes,
            model_info=request.model_info,
            is_ecg=request.is_ecg,
            waveform_image_bytes=waveform_image_bytes
        )
        
        # Upload to MinIO
        # Folder structure: email/patient_id/
        base_path = f"{request.email}/{request.patient_id}"
        
        # Sanitize patient name for filenames
        safe_name = "".join(c for c in request.patient_name if c.isalnum() or c in (' ', '_', '-')).strip().replace(' ', '_')
        
        # Upload Original Image
        if original_image_bytes:
            orig_filename = f"Original_{request.patient_id}_{safe_name}.jpg"
            storage.upload_file(
                io.BytesIO(original_image_bytes),
                f"{base_path}/{orig_filename}",
                "image/jpeg"
            )
            
        # Upload Heatmap (X-ray specific)
        if heatmap_image_bytes:
            analyzed_filename = f"Analyzed_{request.patient_id}_{safe_name}.jpg"
            storage.upload_file(
                io.BytesIO(heatmap_image_bytes),
                f"{base_path}/{analyzed_filename}",
                "image/jpeg"
            )

        # Upload Pinpoint
        if pinpoint_image_bytes:
            pinpoint_filename = f"Pinpoint_{request.patient_id}_{safe_name}.jpg"
            storage.upload_file(
                io.BytesIO(pinpoint_image_bytes),
                f"{base_path}/{pinpoint_filename}",
                "image/jpeg"
            )

        # Upload Waveform (ECG specific)
        if waveform_image_bytes:
            waveform_filename = f"Waveform_{request.patient_id}_{safe_name}.png"
            storage.upload_file(
                io.BytesIO(waveform_image_bytes),
                f"{base_path}/{waveform_filename}",
                "image/png"
            )
            
        # Upload Doctor Marked Images
        for i, img_bytes in enumerate(marked_images_bytes):
            marked_filename = f"DoctorMarked_{i}_{request.patient_id}_{safe_name}.jpg"
            storage.upload_file(
                io.BytesIO(img_bytes),
                f"{base_path}/{marked_filename}",
                "image/jpeg"
            )
            
        # Upload PDF
        pdf_filename = f"Report_{request.patient_id}_{safe_name}.pdf"
        
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
async def list_reports(email: str, storage: MinioStorage = Depends(get_storage), current_user: str = Depends(get_current_user)):
    if email != current_user:
        raise HTTPException(status_code=403, detail="Not authorized to view these reports")
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
                    
                    # Extract name from filename Report_{id}_{name}.pdf
                    patient_name = "Unknown"
                    try:
                        # Remove extension
                        name_part = file_name.replace(".pdf", "")
                        # Remove prefix "Report_" (case-insensitive check)
                        if name_part.lower().startswith("report_"):
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
                        "file_name": file_name,
                        "size_bytes": obj.get('Size', 0)
                    })
        
        # Sort by date, newest first
        reports.sort(key=lambda x: x['date'], reverse=True)
        return reports
    except Exception as e:
        print(f"Error listing reports: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/reports/{email}/{patient_id}/pdf")
async def get_report_pdf(email: str, patient_id: str, storage: MinioStorage = Depends(get_storage), current_user: str = Depends(get_current_user)):
    if email != current_user:
        raise HTTPException(status_code=403, detail="Not authorized to view this report")
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

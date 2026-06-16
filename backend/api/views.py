import os
from django.utils import timezone
import uuid
import json
import hmac
import hashlib
import tempfile
import base64
import requests
import mimetypes
import logging

import numpy as np
import face_recognition 
from django.conf import settings
from django.db import transaction
from django.db.models import Q, Avg, Count
from django.contrib.auth.models import User
from django.views.decorators.csrf import csrf_exempt
from firebase_admin import messaging
from rest_framework import viewsets, status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes, authentication_classes, action, parser_classes
from rest_framework.permissions import IsAuthenticated, AllowAny 
from rest_framework.exceptions import ValidationError
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser 
 
import firebase_admin
from firebase_admin import auth, storage
from cryptography.fernet import Fernet
from PIL import Image, ImageOps
# Custom Authentication & Permissions
from .authentication import FirebaseAuthentication
from .permissions import IsAttendant, IsLandlord
from .face_utils import perform_verification, decrypt_to_base64

# Models
from .models import (
    AdminProfile, LandlordProfile, Block, Unit, Accommodation, Notification, Room, StudentProfile, 
    AttendantProfile, Issue, Charge, LeavePermit, RoomInspection, GatePass,
    CampusLocation, StudentMedicalProfile, EmergencyReport, EmergencyAccessLog
)

# Serializers
from .serializers import (
    AdminProfileSerializer, EmergencyAccessLogSerializer, GatePassSerializer, LandlordProfileSerializer, BlockSerializer, UnitSerializer, AccommodationSerializer, 
    RoomSerializer, StudentProfileSerializer, AttendantProfileSerializer, IssueSerializer, 
    ChargeSerializer, LeavePermitSerializer, RoomInspectionSerializer, NotificationSerializer,
    CampusLocationSerializer, StudentMedicalProfileSerializer, EmergencyReportSerializer
)
from .models import MedicalResponderProfile
from .serializers import MedicalResponderProfileSerializer
logger = logging.getLogger(__name__)

MAX_UPLOAD_SIZE = 5 * 1024 * 1024  

def _extract_blob_path(url):
    """Helper to extract the relative storage blob path from a full public URL."""
    if not url:
        return url
    try:
        bucket_name = storage.bucket().name
        if f"{bucket_name}/" in url:
            return url.split(f"{bucket_name}/")[-1].split('?')[0]
    except Exception as e:
        logger.error(f"Error extracting blob path: {e}")
    return url

class BaseSecureViewSet(viewsets.ModelViewSet):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

# ----------------------------------------------------------------------
# NEW EMERGENCY AND MAPS LOGIC
# ----------------------------------------------------------------------

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def create_emergency_report(request):
    """Handles emergency creation and instant 1:N patient identification."""
    try:
        reporting_student = StudentProfile.objects.get(firebase_uid=request.user.firebase_uid)
        situation_image = request.FILES.get('situation_image')
        
        if not situation_image:
            return Response({"error": "Situation image required for patient identification."}, status=400)

        # 1. Save temp image for the AI to process
        temp_img = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
        with open(temp_img, 'wb+') as f:
            for chunk in situation_image.chunks(): f.write(chunk)

       # ====================================================================
        # 2. FAST 1:N AI IDENTIFICATION LOGIC & ENCODING CAPTURE
        # ====================================================================
        identified_patient_profile = None
        face_encoding_string = "" 
        
        try:
            # --- THE FIX: Force Upright Orientation & RGB Format ---
            pil_image = Image.open(temp_img)
            pil_image = ImageOps.exif_transpose(pil_image) # Auto-rotates upright based on EXIF
            if pil_image.mode != 'RGB':
                pil_image = pil_image.convert('RGB') # Strips mobile alpha/transparency channels
            
            # Convert to numpy array for the AI
            live_image = np.array(pil_image) 
            # -------------------------------------------------------

            live_encodings = face_recognition.face_encodings(live_image)

            if live_encodings:
                live_encoding = live_encodings[0]
                face_encoding_string = json.dumps(live_encoding.tolist()) 
                print(f"✅ FACE DETECTED! Live encoding captured.") 
                
                best_match_id = None
                min_distance = 0.55 
                
                students = StudentProfile.objects.exclude(face_encoding_json__isnull=True).exclude(face_encoding_json="")
                
                for student in students:
                    try:
                        db_encoding = np.array(json.loads(student.face_encoding_json))
                        distance = face_recognition.face_distance([db_encoding], live_encoding)[0]
                        
                        if distance < min_distance:
                            min_distance = distance
                            best_match_id = student.id
                    except Exception:
                        continue
                
                if best_match_id:
                    identified_patient_profile = StudentProfile.objects.get(id=best_match_id)
            else:
                print("🚨 AI WARNING: STILL no face detected. The image is either too blurry, too dark, or doesn't contain a face.")
                    
        except Exception as e:
            logger.error(f"AI Identification Failed: {e}", exc_info=True)

        # ====================================================================
        # 3. Encrypt and Upload the Image to Firebase
        # ====================================================================
        cipher_suite = Fernet(settings.FERNET_KEY)
        encrypted_bytes = cipher_suite.encrypt(open(temp_img, 'rb').read())
        filename = f"secure_emergencies/req_{uuid.uuid4().hex}.jpg.enc"
        
        bucket = storage.bucket()
        blob = bucket.blob(filename)
        blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
        blob.make_public()
        image_url = blob.public_url

        os.remove(temp_img)

        # ====================================================================
        # 4. Create the Report in the Database
        # ====================================================================
        emergency = EmergencyReport.objects.create(
            reporting_student=reporting_student,
            identified_patient=identified_patient_profile,
            latitude=request.data.get('latitude', 0.0),
            longitude=request.data.get('longitude', 0.0),
            emergency_type=request.data.get('emergency_type', 'Other'),
            description=request.data.get('description', ''),
            situation_image_url=image_url,
            face_encoding_json=face_encoding_string # Saved directly into the report
        )

        # ====================================================================
        # 5. Alert Responders
        # ====================================================================
        patient_name = f"{identified_patient_profile.name} {identified_patient_profile.surname}" if identified_patient_profile else "Unidentified Student"
        
        staff_tokens = MedicalResponderProfile.objects.filter(is_active=True).exclude(fcm_token__isnull=True).values_list('fcm_token', flat=True)
        if staff_tokens:
            msg = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=f"CRITICAL: {emergency.emergency_type.upper()}", 
                    body=f"Patient: {patient_name}. Tap to view location and file."
                ),
                tokens=list(staff_tokens),
            )
            messaging.send_multicast(msg)

        return Response({"message": "Alert Sent."}, status=201)

    except StudentProfile.DoesNotExist:
        return Response({"error": "Auth error."}, status=403)
    except Exception as e:
        logger.error(f"Emergency Creation Error: {e}", exc_info=True)
        return Response({"error": "Failed to dispatch emergency."}, status=500)

class EmergencyAccessLogViewSet(BaseSecureViewSet):
    """Immutable POPIA audit logs for admin viewing."""
    queryset = EmergencyAccessLog.objects.select_related('student_accessed', 'report').all().order_by('-created_at')
    serializer_class = EmergencyAccessLogSerializer
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [permissions.IsAdminUser()]
        return super().get_permissions()

class MedicalResponderProfileViewSet(viewsets.ModelViewSet):
    """Viewset for fetching and deleting medical responders."""
    queryset = MedicalResponderProfile.objects.all()
    serializer_class = MedicalResponderProfileSerializer
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['firebase_uid']

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        try:
            auth.delete_user(instance.firebase_uid)
        except Exception as e:
            logger.warning(f"Firebase warning during responder deletion: {str(e)}")
        self.perform_destroy(instance)
        return Response({"message": "Responder and Firebase account permanently deleted."}, status=status.HTTP_200_OK)
    
@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def add_medical_responder(request):
    """Securely registers a new Medical Responder and encrypts their biometrics."""
    id_number = request.data.get('id_number')
    name = request.data.get('name')
    email = request.data.get('email')
    surname = request.data.get('surname')
    phone = request.data.get('phone', '')
    face_image = request.FILES.get('face_image')  

    if not all([id_number, name, email, surname]):
        return Response({"error": "Missing required fields."}, status=400)

    if face_image and face_image.size > MAX_UPLOAD_SIZE:
        return Response({"error": "Face image exceeds the 5MB size limit."}, status=400)

    password = id_number[:6]
    
    try: 
        firebase_user = auth.create_user(email=email, password=password, display_name=f"{name} {surname}")
        
        try:
            with transaction.atomic():
                face_url = None
                
                if face_image:
                    file_bytes = face_image.read()
                    cipher_suite = Fernet(settings.FERNET_KEY)
                    encrypted_bytes = cipher_suite.encrypt(file_bytes)

                    ext = os.path.splitext(face_image.name)[1]
                    filename = f"secure_faces/responder_{uuid.uuid4().hex}{ext}.enc"
                    
                    bucket = storage.bucket()
                    blob = bucket.blob(filename)
                    blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                    blob.make_public()

                    face_url = blob.public_url 

                responder = MedicalResponderProfile.objects.create(
                    firebase_uid=firebase_user.uid, 
                    name=name, 
                    surname=surname,
                    email=email, 
                    phone=phone, 
                    face_url=face_url
                )

            return Response({"message": "Medical Responder successfully registered.", "responder_id": responder.id}, status=201)
            
        except Exception as e:
            auth.delete_user(firebase_user.uid)
            logger.error(f"Responder DB/Storage Error: {e}", exc_info=True)
            return Response({"error": "Failed to encrypt biometrics or complete registration."}, status=500)

    except auth.EmailAlreadyExistsError:
        return Response({"error": "An account with this email already exists."}, status=400)
    except Exception as e:
        logger.error(f"Firebase Creation Error: {e}", exc_info=True)
        return Response({"error": "Authentication provider error."}, status=500)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def verify_responder_login(request):
    """Validates the live facial scan of a Medical Responder against their encrypted reference photo."""
    live_file = request.FILES.get('live_face')
    
    if not live_file:
        return Response({'error': 'Missing live face image.'}, status=400)
        
    if live_file.size > MAX_UPLOAD_SIZE:
        return Response({'error': 'Face image exceeds 5MB limit.'}, status=400)

    try:
        responder = MedicalResponderProfile.objects.get(firebase_uid=request.user.firebase_uid)
        
        if not responder.face_url:
            return Response({'error': 'Responder has no registered biometric data. Contact System Administrator.'}, status=400)

        temp_live = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
        with open(temp_live, 'wb+') as f:
            for chunk in live_file.chunks(): 
                f.write(chunk)
                
        try:
            result = perform_verification(
                live_path=temp_live, 
                ref_path=_extract_blob_path(responder.face_url), 
                is_encrypted_ref=True
            )
            
            if result.get('error'): 
                return Response({'error': 'Verification engine processing error.'}, status=400)
                
            if result.get('matched'):
                return Response({'message': 'Biometric match successful. Dispatch access granted.'}, status=200)
            else:
                return Response({'error': 'Biometric mismatch. Unauthorized access attempt logged.'}, status=403)
                
        finally:
            if os.path.exists(temp_live): 
                os.remove(temp_live)

    except MedicalResponderProfile.DoesNotExist:
        return Response({'error': 'Medical Responder profile not found in system.'}, status=404)
    except Exception as e:
        logger.error(f"Responder Login Verification Error: {e}", exc_info=True)
        return Response({'error': 'An internal server error occurred during biometric verification.'}, status=500)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
def unlock_medical_data(request):
    """Simplified Security Protocol. Staff confirms access, generates audit log, decrypts POPIA health data and retrieves full student profile."""
    report_id = request.data.get('report_id')
    patient_id = request.data.get('patient_id') # Pull the ID sent from Flutter

    if not report_id:
        return Response({'error': 'Missing report ID.'}, status=400)

    try:
        report = EmergencyReport.objects.get(id=report_id)
        staff_user = request.user 
        
        # Use the explicit patient_id if provided, otherwise fallback to the AI identified patient
        if patient_id:
            try:
                target_student = StudentProfile.objects.get(id=patient_id)
            except StudentProfile.DoesNotExist:
                return Response({'error': 'Patient not found in system.'}, status=404)
        else:
            target_student = report.identified_patient
            
        if not target_student:
            return Response({'error': 'No patient identified in this report.'}, status=404)

        # Audit Log Generation (Cannot be bypassed)
        with transaction.atomic():
            EmergencyAccessLog.objects.create(
                report=report,
                accessed_by_uid=staff_user.firebase_uid,
                student_accessed=target_student # Log the correct victim!
            )
            
            # --- NEW: Safely extract room and block data from the StudentProfile ---
            room_number = "Unassigned"
            block_name = "Unassigned Block"
            
            if target_student.room:
                room_number = target_student.room.room_number
                if hasattr(target_student.room, 'unit') and target_student.room.unit and target_student.room.unit.block:
                    block_name = target_student.room.unit.block.name
                elif target_student.room.block:
                    block_name = target_student.room.block.name
            
            # Fetch and Decrypt Data
            try:
                medical_profile = StudentMedicalProfile.objects.get(student=target_student)
                return Response({
                    # --- INJECTING FULL STUDENT DETAILS ---
                    "student_name": f"{target_student.name} {target_student.surname}",
                    "student_number": target_student.student_number,
                    "face_url": target_student.face_url,
                    "room_number": room_number,
                    "block_name": block_name,
                    # ----------------------------------------
                    "blood_type": medical_profile.blood_type,
                    "allergies": medical_profile.allergies,
                    "medical_conditions": medical_profile.medical_conditions,
                    "emergency_contact_name": medical_profile.emergency_contact_name,
                    "emergency_contact_phone": medical_profile.emergency_contact_phone,
                    "emergency_contact_relation": medical_profile.emergency_contact_relation
                }, status=200)
                
            except StudentMedicalProfile.DoesNotExist:
                # NEW: Return the identity & room data even if they skipped the medical form!
                return Response({
                    "student_name": f"{target_student.name} {target_student.surname}",
                    "student_number": target_student.student_number,
                    "face_url": target_student.face_url,
                    "room_number": room_number,
                    "block_name": block_name,
                    "blood_type": "Unknown",
                    "allergies": "No profile recorded",
                    "medical_conditions": "No profile recorded",
                    "emergency_contact_name": "N/A",
                    "emergency_contact_phone": "N/A",
                    "emergency_contact_relation": "N/A"
                }, status=200)

    except EmergencyReport.DoesNotExist:
        return Response({'error': 'Emergency report not found.'}, status=404)
    except Exception as e:
        logger.error(f"Medical Access Error: {e}", exc_info=True)
        return Response({'error': 'An internal server error occurred.'}, status=500)     
class CampusLocationViewSet(BaseSecureViewSet):
    """Provides coordinates for the mobile frontend maps SDK."""
    queryset = CampusLocation.objects.all()
    serializer_class = CampusLocationSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['location_type']

    def get_permissions(self):
        if self.request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
            return [IsAuthenticated(), IsLandlord()] 
        return [IsAuthenticated()]

class StudentMedicalProfileViewSet(BaseSecureViewSet):
    """Allows students to self-report and update their encrypted medical profiles."""
    serializer_class = StudentMedicalProfileSerializer

    def get_queryset(self):
        if hasattr(self.request.user, 'firebase_uid') and getattr(self.request.user, 'role', 'student') == 'student':
            return StudentMedicalProfile.objects.filter(student=self.request.user)
        return StudentMedicalProfile.objects.none()

    def perform_create(self, serializer):
        try:
            student = StudentProfile.objects.get(firebase_uid=self.request.user.firebase_uid)
            serializer.save(student=student)
        except StudentProfile.DoesNotExist:
            raise ValidationError({"error": "Only student profiles can update medical data."})
        
class EmergencyReportViewSet(BaseSecureViewSet):
    """Handles student-initiated panic alerts with GPS pinpointing and images."""
    queryset = EmergencyReport.objects.select_related('reporting_student', 'resolved_by').all().order_by('-created_at')
    serializer_class = EmergencyReportSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['status']
    
    parser_classes = [MultiPartParser, FormParser, JSONParser] 
      
@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def unlock_medical_data_dual(request):
    """
    The Dual-Scan Security Protocol. 
    Requires Staff Face + Student Face matching to generate an audit log and decrypt POPIA health data.
    """
    report_id = request.data.get('report_id')
    staff_face = request.FILES.get('staff_face')
    student_face = request.FILES.get('student_face')

    if not all([report_id, staff_face, student_face]):
        return Response({'error': 'Missing report ID or facial scans.'}, status=400)
        
    if staff_face.size > MAX_UPLOAD_SIZE or student_face.size > MAX_UPLOAD_SIZE:
        return Response({'error': 'Facial scan images exceed size limit.'}, status=400)

    try:
        report = EmergencyReport.objects.get(id=report_id)
        student = report.reporting_student
        staff_user = request.user 
        
        if not hasattr(staff_user, 'face_url') or not staff_user.face_url:
            return Response({'error': 'Authorized responder has no registered face.'}, status=403)
        if not student.face_url:
            return Response({'error': 'Student has no registered face.'}, status=400)

        temp_staff = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
        temp_student = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
        
        try:
            with open(temp_staff, 'wb+') as f:
                for chunk in staff_face.chunks(): f.write(chunk)
            with open(temp_student, 'wb+') as f:
                for chunk in student_face.chunks(): f.write(chunk)
                
            staff_result = perform_verification(live_path=temp_staff, ref_path=_extract_blob_path(staff_user.face_url), is_encrypted_ref=True)
            if not staff_result.get('matched'):
                return Response({'error': 'Responder biometric verification failed. Access Denied.'}, status=403)

            student_result = perform_verification(live_path=temp_student, ref_path=_extract_blob_path(student.face_url), is_encrypted_ref=True)
            if not student_result.get('matched'):
                return Response({'error': 'Student biometric verification failed. Ensure you are scanning the correct patient.'}, status=403)
            
            with transaction.atomic():
                EmergencyAccessLog.objects.create(
                    report=report,
                    accessed_by_uid=staff_user.firebase_uid,
                    student_accessed=student
                )
                
                try:
                    medical_profile = StudentMedicalProfile.objects.get(student=student)
                    return Response({
                        "blood_type": medical_profile.blood_type,
                        "allergies": medical_profile.allergies,
                        "medical_conditions": medical_profile.medical_conditions,
                        "emergency_contact_name": medical_profile.emergency_contact_name,
                        "emergency_contact_phone": medical_profile.emergency_contact_phone,
                        "emergency_contact_relation": medical_profile.emergency_contact_relation
                    }, status=200)
                except StudentMedicalProfile.DoesNotExist:
                    return Response({'error': 'Patient identified, but no medical profile exists on file.'}, status=404)
                
        finally:
            if os.path.exists(temp_staff): os.remove(temp_staff)
            if os.path.exists(temp_student): os.remove(temp_student)

    except EmergencyReport.DoesNotExist:
        return Response({'error': 'Emergency report not found.'}, status=404)
    except Exception as e:
        logger.error(f"Dual-Scan Security Error: {e}", exc_info=True)
        return Response({'error': 'An internal server error occurred during decryption protocol.'}, status=500)


# ----------------------------------------------------------------------
# LANDLORD APP BIOMETRIC VERIFICATION
# ----------------------------------------------------------------------

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated, IsLandlord])
@parser_classes([MultiPartParser, FormParser]) 
def verify_landlord_identity_app(request):
    landlord = getattr(request.user, 'landlord_profile', None)
    if not landlord:
        return Response({'error': 'User profile is not registered as a landlord.'}, status=status.HTTP_400_BAD_REQUEST)

    live_face = request.FILES.get('face_image')
    id_document = request.FILES.get('id_document')
    contract_file = request.FILES.get('contract_file')

    if not live_face or not id_document or not contract_file:
        return Response({'error': 'Missing required files. Please upload face, ID, and contract.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        cipher_suite = Fernet(settings.FERNET_KEY)
        bucket = storage.bucket()

        live_face.seek(0)
        face_blob_name = f"secure_faces/landlord_{landlord.id}_live_{uuid.uuid4().hex}.jpg.enc"
        face_blob = bucket.blob(face_blob_name)
        face_blob.upload_from_string(
            cipher_suite.encrypt(live_face.read()), 
            content_type='application/octet-stream'
        )
        face_blob.make_public()
        landlord.face_url = face_blob.public_url

        id_document.seek(0)
        id_ext = os.path.splitext(id_document.name)[1].lower()
        if not id_ext:
            id_ext = '.jpg'  
        id_blob_name = f"secure_docs/landlord_{landlord.id}_id_{uuid.uuid4().hex}{id_ext}.enc"
        id_blob = bucket.blob(id_blob_name)
        id_blob.upload_from_string(
            cipher_suite.encrypt(id_document.read()), 
            content_type='application/octet-stream'
        )
        id_blob.make_public()
        landlord.id_document_url = id_blob.public_url

        contract_file.seek(0)
        contract_ext = os.path.splitext(contract_file.name)[1].lower()
        if not contract_ext:
            contract_ext = '.pdf'
        contract_blob_name = f"secure_contracts/landlord_{landlord.id}_contract_{uuid.uuid4().hex}{contract_ext}.enc"
        contract_blob = bucket.blob(contract_blob_name)
        contract_blob.upload_from_string(
            cipher_suite.encrypt(contract_file.read()), 
            content_type='application/octet-stream'
        )
        contract_blob.make_public()
        landlord.contract_url = contract_blob.public_url

        landlord.is_identity_verified = False  
        landlord.save()

        return Response({
            'message': 'Identity documents successfully uploaded and encrypted.',
            'face_url': landlord.face_url,
            'id_document_url': landlord.id_document_url,
            'contract_url': landlord.contract_url
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error during landlord verification asset upload: {e}", exc_info=True)
        return Response({'error': 'Internal server error processing security files.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated, IsLandlord])
def request_manual_review(request):
    try:
        landlord = LandlordProfile.objects.get(firebase_uid=request.user.firebase_uid)
        landlord.manual_verification_status = True
        landlord.save()
        return Response({'message': 'Account officially flagged for manual administrator review.'}, status=200)
    except LandlordProfile.DoesNotExist:
        return Response({'error': 'Landlord profile not found.'}, status=404)


# ----------------------------------------------------------------------
# OTHER ENDPOINTS
# ----------------------------------------------------------------------

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated]) 
def verify_permit_qr(request):
    qr_reference = request.data.get('qr_reference')

    if not qr_reference:
        return Response({'error': 'No QR reference provided.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        permit = LeavePermit.objects.get(qr_reference=qr_reference)
        student = permit.student
        
        response_data = {
            'id': permit.id,
            'status': permit.status,
            'student_name': f"{student.name} {student.surname}",
            'student_number': getattr(student, 'student_number', 'N/A'),
            'destination': permit.destination_province,
            'face_url': None, 
        }
        
        if getattr(student, 'face_url', None):
            host = request.get_host()
            scheme = request.scheme
            response_data['face_url'] = f"{scheme}://{host}/api/fetch-decrypted-face/{student.id}/"

        if permit.status != 'APPROVED':
            response_data['message'] = "This permit is not valid for exit."

        return Response(response_data, status=status.HTTP_200_OK)

    except LeavePermit.DoesNotExist:
        return Response({'error': 'INVALID OR FAKE QR CODE DETECTED.'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"QR Verification Error: {e}", exc_info=True)
        return Response({'error': 'An internal server error occurred.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@authentication_classes([FirebaseAuthentication])
@parser_classes([MultiPartParser, FormParser])
def verify_face_match(request):
    permit_id = request.data.get('permit_id')
    live_file = request.FILES.get('live_face')

    if not permit_id or not live_file:
        return Response({'error': 'Missing permit ID or live face image.'}, status=400)
        
    if live_file.size > MAX_UPLOAD_SIZE:
        return Response({'error': 'Face image exceeds the size limit.'}, status=400)

    try:
        permit = LeavePermit.objects.get(id=permit_id)
        student = permit.student
        
        if not student.face_url:
            return Response({'error': 'Student has no registered face.'}, status=400)

        temp_live = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
        with open(temp_live, 'wb+') as f:
            for chunk in live_file.chunks(): 
                f.write(chunk)
                
        try:
            result = perform_verification(
                live_path=temp_live, 
                ref_path=_extract_blob_path(student.face_url), 
                is_encrypted_ref=True
            )
            
            if result.get('error'): 
                return Response({'error': 'Verification engine error.'}, status=400)
                
            if result.get('matched'):
                return Response({'message': 'Biometric match successful.', 'distance': result.get('score', 0.0)}, status=200)
            else:
                return Response({'error': 'Biometric mismatch. Identity theft suspected.'}, status=403)
                
        finally:
            if os.path.exists(temp_live): 
                os.remove(temp_live)

    except LeavePermit.DoesNotExist:
        return Response({'error': 'Permit not found.'}, status=404)
    except Exception as e:
        logger.error(f"Face Match Error: {e}", exc_info=True)
        return Response({'error': 'An internal server error occurred.'}, status=500)


@api_view(['GET'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
def fetch_decrypted_face(request, student_id):
    try:
        student = StudentProfile.objects.get(id=student_id)
        
        if not student.face_url:
            return Response({'error': 'No face registered.'}, status=404)
            
        file_url = student.face_url
        
        try:
            resp = requests.get(file_url)
            if resp.status_code != 200:
                return Response({'error': 'Encrypted file not found in storage.'}, status=404)
                
            encrypted_data = resp.content
                
            cipher_suite = Fernet(settings.FERNET_KEY)
            decrypted_data = cipher_suite.decrypt(encrypted_data)
            face_base64 = base64.b64encode(decrypted_data).decode('utf-8')
            
            return Response({'face_base64': face_base64})
            
        except Exception as e:
            logger.error(f"Decryption Error: {e}", exc_info=True)
            return Response({'error': 'Decryption process failed.'}, status=500)
        
    except StudentProfile.DoesNotExist:
        return Response({'error': 'Student not found'}, status=404)
    except Exception as e:
        logger.error(f"Server Error: {e}", exc_info=True)
        return Response({'error': 'Server error.'}, status=500)


# ----------------------------------------------------------------------
# BASE VIEWSETS
# ----------------------------------------------------------------------


class LandlordProfileViewSet(BaseSecureViewSet):
    queryset = LandlordProfile.objects.all()
    serializer_class = LandlordProfileSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['firebase_uid']

    @action(detail=True, methods=['get'], url_path='decrypted-document')
    def get_decrypted_document(self, request, pk=None):
        import requests
        import base64
        import mimetypes

        doc_type = request.query_params.get('type')
        if doc_type not in ['contract', 'face', 'id_document']:
            return Response({'error': 'Invalid document type requested.'}, status=status.HTTP_400_BAD_REQUEST)

        landlord = self.get_object()
        
        if doc_type == 'contract':
            file_url = landlord.contract_url
        elif doc_type == 'face':
            file_url = landlord.face_url
        else:
            file_url = landlord.id_document_url

        if not file_url:
            return Response({'error': 'Requested secure document path does not exist.'}, status=status.HTTP_404_NOT_FOUND)

        try:
            resp = requests.get(file_url)
            if resp.status_code != 200:
                return Response({'error': 'Failed to stream asset payload from storage cluster.'}, status=status.HTTP_404_NOT_FOUND)
            
            cipher_suite = Fernet(settings.FERNET_KEY)
            decrypted_data = cipher_suite.decrypt(resp.content)
            
            filename = file_url.split('?')[0].replace('.enc', '')
            mime_type, _ = mimetypes.guess_type(filename)
            
            if not mime_type:
                if doc_type == 'face':
                    mime_type = 'image/jpeg'
                elif doc_type == 'contract':
                    mime_type = 'application/pdf'
                else:
                    mime_type = 'application/octet-stream'

            doc_base64 = base64.b64encode(decrypted_data).decode('utf-8')
            
            return Response({
                'document_base64': doc_base64,
                'mime_type': mime_type
            }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Landlord Secure Decryption Core Failure: {e}", exc_info=True)
            return Response({'error': 'Decryption pipeline aborted due to an internal execution error.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class BlockViewSet(BaseSecureViewSet):
    queryset = Block.objects.all()
    serializer_class = BlockSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['accommodation__id']

class UnitViewSet(BaseSecureViewSet):
    queryset = Unit.objects.all()
    serializer_class = UnitSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['block__id', 'block__accommodation__id']


class AccommodationViewSet(BaseSecureViewSet):
    serializer_class = AccommodationSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser] 

    def get_queryset(self):
        return Accommodation.objects.filter(landlord__is_verified=True)

    def get_authenticators(self):
        if self.request and self.request.method == 'GET':
            return [] 
        return super().get_authenticators()

    def get_permissions(self):
        if self.request and self.request.method == 'GET':
            return [AllowAny()]
        return super().get_permissions()

    def _handle_logo_upload(self, instance, request):
        logo_file = request.FILES.get('accommodation_logo')
        if logo_file:
            if logo_file.size > 5 * 1024 * 1024:  
                raise ValidationError({"error": "Logo image exceeds the 5MB limit."})
            
            try:
                ext = os.path.splitext(logo_file.name)[1]
                filename = f"public_logos/acc_{instance.id}_{uuid.uuid4().hex}{ext}"
                
                bucket = storage.bucket()
                blob = bucket.blob(filename)
                blob.upload_from_file(logo_file.file, content_type=logo_file.content_type)
                blob.make_public()
                
                instance.accommodation_logo_url = blob.public_url
                instance.save()
            except Exception as e:
                logger.error(f"Failed to upload accommodation logo: {e}", exc_info=True)

    def perform_create(self, serializer):
        landlord = LandlordProfile.objects.filter(firebase_uid=self.request.user.firebase_uid).first()
        instance = serializer.save(landlord=landlord)
        self._handle_logo_upload(instance, self.request)

    def perform_update(self, serializer):
        instance = serializer.save()
        self._handle_logo_upload(instance, self.request)
    
class RoomViewSet(BaseSecureViewSet):
    queryset = Room.objects.all()
    serializer_class = RoomSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['block__accommodation__id', 'room_number', 'block__id', 'unit__id'] 

class StudentProfileViewSet(BaseSecureViewSet):
    queryset = StudentProfile.objects.select_related(
        'room__unit__block__accommodation', 
        'room__block__accommodation', 
        'applied_accommodation'
    ).all()
    serializer_class = StudentProfileSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['firebase_uid', 'student_number', 'is_cleared_for_exit', 'landlord__id']

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        try:
            auth.delete_user(instance.firebase_uid)
        except Exception as e:
            logger.warning(f"Firebase warning during deletion: {str(e)}")
        self.perform_destroy(instance)
        return Response({"message": "Student and Firebase account permanently deleted."}, status=status.HTTP_200_OK)
    
    @action(detail=False, methods=['get'], url_path='me')
    def get_current_profile(self, request):
        uid = getattr(request.user, 'firebase_uid', None) or getattr(request.user, 'username', None)
        try:
            student = StudentProfile.objects.get(firebase_uid=uid)
            serializer = self.get_serializer(student)
            return Response(serializer.data, status=status.HTTP_200_OK)
        except StudentProfile.DoesNotExist:
            return Response({"error": "Student profile not found."}, status=status.HTTP_404_NOT_FOUND)
        
    def perform_update(self, serializer):
        instance = serializer.save()
        face_image = self.request.FILES.get('face_image')
        
        if face_image:
            if face_image.size > MAX_UPLOAD_SIZE:
                raise ValidationError({"error": "Face image exceeds the 5MB size limit."})
            
            try:
                file_bytes = face_image.read()
                
                temp_face = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
                with open(temp_face, 'wb+') as f:
                    f.write(file_bytes)
                
                try:
                    import face_recognition
                    img_data = face_recognition.load_image_file(temp_face)
                    encodings = face_recognition.face_encodings(img_data)
                    if encodings:
                        instance.face_encoding_json = json.dumps(encodings[0].tolist())
                except Exception as e:
                    logger.error(f"Failed to generate face encoding during update: {e}")
                finally:
                    if os.path.exists(temp_face):
                        os.remove(temp_face)

                cipher_suite = Fernet(settings.FERNET_KEY)
                encrypted_bytes = cipher_suite.encrypt(file_bytes)
                ext = os.path.splitext(face_image.name)[1]
                filename = f"secure_faces/{instance.student_number}_{uuid.uuid4().hex}{ext}.enc"
                
                bucket = storage.bucket()
                blob = bucket.blob(filename)
                blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                blob.make_public() 
                
                instance.face_url = blob.public_url
                instance.save()
            except Exception as e:
                logger.error(f"Firebase Facial Upload Error: {str(e)}", exc_info=True)
                raise ValidationError({"error": "Failed to process and secure the facial biometric data."})
                
    @action(detail=True, methods=['get'], url_path='decrypted-document')
    def get_decrypted_document(self, request, pk=None):
        doc_type = request.query_params.get('type')
        if doc_type not in ['id', 'proof']:
            return Response({'error': 'Invalid document type requested. Use ?type=id or ?type=proof'}, status=status.HTTP_400_BAD_REQUEST)

        student = self.get_object()
        file_url = student.id_document_url if doc_type == 'id' else student.proof_of_registration_url

        if not file_url:
            return Response({'error': 'Document does not exist for this applicant.'}, status=status.HTTP_404_NOT_FOUND)

        try:
            resp = requests.get(file_url)
            if resp.status_code != 200:
                return Response({'error': 'Failed to retrieve encrypted file from storage.'}, status=status.HTTP_404_NOT_FOUND)
            
            cipher_suite = Fernet(settings.FERNET_KEY)
            decrypted_data = cipher_suite.decrypt(resp.content)
            
            filename = file_url.split('?')[0].replace('.enc', '')
            mime_type, _ = mimetypes.guess_type(filename)
            if not mime_type:
                mime_type = 'application/octet-stream'

            doc_base64 = base64.b64encode(decrypted_data).decode('utf-8')
            
            return Response({
                'document_base64': doc_base64,
                'mime_type': mime_type
            }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Document Decryption Error: {e}", exc_info=True)
            return Response({'error': 'Decryption failed due to an internal error.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=False, methods=['post'], url_path='update-documents', parser_classes=[MultiPartParser, FormParser])
    def update_documents(self, request):
        uid = getattr(request.user, 'firebase_uid', None) or getattr(request.user, 'username', None)
        try:
            student = StudentProfile.objects.get(firebase_uid=uid)
        except StudentProfile.DoesNotExist:
            return Response({"error": "Student profile not found."}, status=status.HTTP_404_NOT_FOUND)

        id_document = request.FILES.get('id_document')
        proof_of_registration = request.FILES.get('proof_of_registration')
        
        if id_document and id_document.size > MAX_UPLOAD_SIZE:
             return Response({"error": "ID Document exceeds 5MB limit."}, status=400)
        if proof_of_registration and proof_of_registration.size > MAX_UPLOAD_SIZE:
             return Response({"error": "Proof of registration exceeds 5MB limit."}, status=400)
        
        cipher_suite = Fernet(settings.FERNET_KEY)
        bucket = storage.bucket()

        try:
            if id_document:
                file_bytes = id_document.read()
                encrypted_bytes = cipher_suite.encrypt(file_bytes)
                ext = os.path.splitext(id_document.name)[1]
                filename = f"secure_docs/ID_{student.student_number}_{uuid.uuid4().hex}{ext}.enc"
                blob = bucket.blob(filename)
                blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                blob.make_public()
                student.id_document_url = blob.public_url

            if proof_of_registration:
                file_bytes = proof_of_registration.read()
                encrypted_bytes = cipher_suite.encrypt(file_bytes)
                ext = os.path.splitext(proof_of_registration.name)[1]
                filename = f"secure_docs/PROOF_{student.student_number}_{uuid.uuid4().hex}{ext}.enc"
                blob = bucket.blob(filename)
                blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                blob.make_public()
                student.proof_of_registration_url = blob.public_url

            student.save()
            return Response({"message": "Documents securely uploaded and encrypted."}, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Document Update Error: {e}", exc_info=True)
            return Response({"error": "Document security management failed."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class AttendantProfileViewSet(BaseSecureViewSet):
    serializer_class = AttendantProfileSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['firebase_uid', 'landlord__id']

    def get_queryset(self):
        return AttendantProfile.objects.annotate(
            average_rating=Avg('assigned_issues__attendant_rating'),
            resolved_issues_count=Count('assigned_issues', filter=Q(assigned_issues__status='RESOLVED'))
        )

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        try:
            auth.delete_user(instance.firebase_uid)
        except Exception as e:
            logger.warning(f"Firebase warning during attendant deletion: {str(e)}")
        self.perform_destroy(instance)
        return Response({"message": "Staff member and Firebase account permanently deleted."}, status=status.HTTP_200_OK)
    
class IssueViewSet(BaseSecureViewSet):
    queryset = Issue.objects.select_related('student', 'room__block', 'room__unit', 'assigned_attendant').all()
    serializer_class = IssueSerializer
    filter_backends = [DjangoFilterBackend] 
    filterset_fields = ['status', 'student__firebase_uid', 'assigned_attendant__firebase_uid', 'is_priority']
    
    def perform_update(self, serializer):
        instance = serializer.save()
        if instance.status == 'ATTENDING' and not instance.assigned_attendant:
            if hasattr(self.request.user, 'role'): 
                instance.assigned_attendant = self.request.user
                instance.save()
                
    def perform_create(self, serializer):
        try:
            student = StudentProfile.objects.get(firebase_uid=self.request.user.firebase_uid)
            issue = serializer.save(student=student, room=student.room)
             
            if issue.custom_issue_title == "Lost Key":
                Charge.objects.create(
                    student=student,
                    issue=issue,
                    amount=150.00, 
                    description="Payment required for: Lost Key",
                    is_paid=False
                )
                
        except StudentProfile.DoesNotExist:
            raise Response({"error": "Authenticated user does not have an associated student profile."}, status=status.HTTP_400_BAD_REQUEST)

class ChargeViewSet(BaseSecureViewSet):
    queryset = Charge.objects.select_related('student__room__block').all()
    serializer_class = ChargeSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['is_paid', 'student__firebase_uid']
 
class LeavePermitViewSet(BaseSecureViewSet):
    serializer_class = LeavePermitSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['status']

    def get_queryset(self):
        user = self.request.user
        uid = getattr(user, 'firebase_uid', None) or getattr(user, 'username', None)
        
        if not uid:
            return LeavePermit.objects.none()
        
        if StudentProfile.objects.filter(firebase_uid=uid).exists():
            return LeavePermit.objects.filter(student__firebase_uid=uid)
            
        if AttendantProfile.objects.filter(firebase_uid=uid).exists():
            return LeavePermit.objects.filter(
                Q(assigned_attendant__firebase_uid=uid) | 
                Q(status='REQUESTED', assigned_attendant__isnull=True)
            )
            
        if LandlordProfile.objects.filter(firebase_uid=uid).exists():
            return LeavePermit.objects.filter(student__landlord__firebase_uid=uid)
            
        return LeavePermit.objects.none()

    def perform_create(self, serializer):
        user = self.request.user
        uid = getattr(user, 'firebase_uid', None) or getattr(user, 'username', None)
        
        try:
            student = StudentProfile.objects.get(firebase_uid=uid)
            serializer.save(student=student)
        except StudentProfile.DoesNotExist:
            raise ValidationError({"error": "Authenticated user does not have an associated student profile."})

class RoomInspectionViewSet(BaseSecureViewSet):
    queryset = RoomInspection.objects.all()
    serializer_class = RoomInspectionSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['is_damage_found', 'attendant__firebase_uid', 'permit__student__firebase_uid']

class GatePassViewSet(BaseSecureViewSet):
    queryset = GatePass.objects.all()
    serializer_class = GatePassSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['is_active', 'student__firebase_uid', 'attendant__firebase_uid']

    def perform_create(self, serializer):
        try:
            student = StudentProfile.objects.get(firebase_uid=self.request.user.firebase_uid)
            serializer.save(student=student)
            
        except StudentProfile.DoesNotExist: 
            raw_data = self.request.data
            
            student_id = raw_data.get('student') or raw_data.get('student_id')
            
            if not student_id:
                raise ValidationError({"error": f"Student missing. Payload received by Django: {raw_data}"})
            
            try:
                target_student = StudentProfile.objects.get(id=student_id)
                serializer.save(student=target_student)
            except StudentProfile.DoesNotExist:
                raise ValidationError({"error": f"Student record {student_id} does not exist in the database."})
                
        except AttributeError:
            raise ValidationError({"error": "Authentication token missing valid UID."})

class NotificationViewSet(BaseSecureViewSet):
    serializer_class = NotificationSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['is_read']

    def get_queryset(self):
        user = self.request.user
        if isinstance(user, StudentProfile):
            return Notification.objects.filter(student=user).order_by('-created_at')
        elif isinstance(user, AttendantProfile):
            return Notification.objects.filter(attendant=user).order_by('-created_at')
        elif isinstance(user, LandlordProfile):
            return Notification.objects.filter(landlord=user).order_by('-created_at')
        return Notification.objects.none()

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        notification = self.get_object()
        if not notification.is_read:
            notification.is_read = True
            notification.save()
        return Response({'status': 'Notification marked as read'})


# ----------------------------------------------------------------------
# FUNCTION VIEWS & CUSTOM APIs
# ----------------------------------------------------------------------

class LandlordDashboardStatsView(APIView):
    permission_classes = [IsAuthenticated, IsLandlord]
    def get(self, request):
        landlord = request.user
        accommodations_count = Accommodation.objects.filter(landlord=landlord).count()
        return Response({
            "total_accommodations": accommodations_count,
            "professional_name": f"{landlord.name} {landlord.surname}",
        })

class GlobalSearchView(APIView):
    permission_classes = [IsAuthenticated, IsLandlord]
    def get(self, request):
        query = request.query_params.get('q', '').strip()
        landlord = request.user  

        if not query or len(query) < 2:
            return Response({"results": []})

        results = []
        students = StudentProfile.objects.filter(landlord=landlord).filter(
            Q(name__icontains=query) | Q(surname__icontains=query) | Q(student_number__icontains=query)
        )[:5] 

        for s in students:
            results.append({
                "type": "student", "title": f"{s.name} {s.surname}",
                "subtitle": f"SN: {s.student_number}", "id": str(s.id),
                "link": f"/landlord/students/{s.id}"
            })

        rooms = Room.objects.filter(block__accommodation__landlord=landlord).filter(
            Q(room_number__icontains=query)
        )[:5]

        for r in rooms:
            results.append({
                "type": "room", "title": f"Room {r.room_number}",
                "subtitle": r.block.accommodation.name if r.block else "Unassigned",
                "id": str(r.id), "link": f"/landlord/accommodations/rooms/{r.id}"
            })

        return Response({"results": results})

class RegisterLandlordView(APIView):
    permission_classes = [permissions.AllowAny]
    def post(self, request):
        firebase_uid = request.data.get('firebase_uid')
        email = request.data.get('email')
        
        name = request.data.get('name')
        surname = request.data.get('surname')
        phone = request.data.get('phone')

        if not firebase_uid or not email:
            return Response({"error": "firebase_uid and email are strictly required."}, status=status.HTTP_400_BAD_REQUEST)

        if LandlordProfile.objects.filter(firebase_uid=firebase_uid).exists():
            return Response({"error": "A landlord with this Firebase UID already exists."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            with transaction.atomic():
                user, created = User.objects.get_or_create(username=firebase_uid, defaults={'email': email})
                if not created:
                    return Response({"error": "User already exists in auth system."}, status=400)
                
                landlord = LandlordProfile.objects.create(
                    firebase_uid=firebase_uid, 
                    email=email,
                    name=name,
                    surname=surname,
                    phone=phone,
                    is_verified=False,
                    digital_verification_status=False,
                    manual_verification_status=False
                )
                return Response({
                    "message": "Landlord account created successfully. Please log into the mobile app to complete your biometric verification.", 
                    "firebase_uid": landlord.firebase_uid
                }, status=status.HTTP_201_CREATED)
        except Exception as e:
            logger.error(f"Landlord Registration Error: {e}", exc_info=True)
            return Response({"error": "Database error occurred during registration."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([AllowAny]) 
def login_user(request):
    id_token = request.data.get('id_token')
    if not id_token:
        return Response({"error": "No id_token provided."}, status=400)
        
    try:
        decoded_token = auth.verify_id_token(id_token)
        firebase_uid = decoded_token.get('uid') 
        
        admin_user = AdminProfile.objects.filter(firebase_uid=firebase_uid).first()
        if admin_user:
            serializer = AdminProfileSerializer(admin_user)
            return Response({"message": "Login successful", "role": "admin", "user_data": serializer.data}, status=200)

        landlord = LandlordProfile.objects.filter(firebase_uid=firebase_uid).first()
        if landlord:
            serializer = LandlordProfileSerializer(landlord)
            return Response({"message": "Login successful", "role": "landlord", "user_data": serializer.data}, status=200)

        student = StudentProfile.objects.filter(firebase_uid=firebase_uid).first()
        if student:
            serializer = StudentProfileSerializer(student)
            return Response({"message": "Login successful", "role": "student", "user_data": serializer.data }, status=200) 
       
        responder = MedicalResponderProfile.objects.filter(firebase_uid=firebase_uid).first()
        if responder:
            serializer = MedicalResponderProfileSerializer(responder)
            return Response({"message": "Login successful", "role": "responder", "user_data": serializer.data}, status=200)
        
        attendant = AttendantProfile.objects.filter(firebase_uid=firebase_uid).first()
        if attendant:
            serializer = AttendantProfileSerializer(attendant)
            return Response({"message": "Login successful", "role": "staff", "user_data": serializer.data}, status=200)
        
        return Response({"error": "No matching profile found."}, status=404)
        
    except auth.InvalidIdTokenError:
        return Response({"error": "Invalid or expired Firebase token."}, status=401)
    except Exception as e:
        logger.error(f"Login Error: {e}", exc_info=True)
        return Response({"error": "An internal server error occurred."}, status=500)


@api_view(['POST'])
@authentication_classes([FirebaseAuthentication]) 
@permission_classes([IsAuthenticated, IsLandlord]) 
def add_attendant_by_landlord(request):
    id_number = request.data.get('id_number')
    name = request.data.get('name')
    email = request.data.get('email')
    surname = request.data.get('surname')
    phone = request.data.get('phone', '')
    face_url = request.data.get('face_url', '')  
    role = request.data.get('role', 'ATTENDANT') 

    if not all([id_number, name, email, surname]):
        return Response({"error": "Missing fields."}, status=400)

    password = id_number[:6]
    landlord = request.user  
    
    try: 
        firebase_user = auth.create_user(email=email, password=password, display_name=f"{name} {surname}")
        try:
            with transaction.atomic():
                attendant = AttendantProfile.objects.create(
                    landlord=landlord, firebase_uid=firebase_user.uid, name=name, surname=surname,
                    email=email, phone=phone, face_url=face_url, role=role 
                )

            return Response({"message": "Staff registered.", "attendant_id": attendant.id}, status=201)
        except Exception as e:
            auth.delete_user(firebase_user.uid)
            raise e

    except auth.EmailAlreadyExistsError:
        return Response({"error": "Staff exists."}, status=400)
    except Exception as e:
        logger.error(f"Add Attendant Error: {e}", exc_info=True)
        return Response({"error": "Failed to add staff member due to an internal error."}, status=500)


@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated, IsLandlord])
def send_communication(request):
    title = request.data.get('title')
    message = request.data.get('message')
    send_mode = request.data.get('send_mode', 'broadcast') 
    target_audience = request.data.get('target_audience', 'all') 
    recipient_ids = request.data.get('recipient_ids', []) 
    
    landlord = request.user

    if not title or not message:
        return Response({"error": "Title and message are required."}, status=status.HTTP_400_BAD_REQUEST)

    notifications_to_create = []
    fcm_tokens = []

    with transaction.atomic():
        if send_mode == 'broadcast':
            students = StudentProfile.objects.filter(landlord=landlord)
            attendants = AttendantProfile.objects.filter(landlord=landlord)

            if target_audience in ['all', 'students']:
                for s in students:
                    notifications_to_create.append(Notification(student=s, title=title, message=message, target_audience=target_audience))
            
            if target_audience in ['all', 'attendants', 'security', 'room_attendants', 'general_staff']:
                query = attendants
                if target_audience == 'security': query = query.filter(role='SECURITY')
                elif target_audience == 'room_attendants': query = query.filter(role='ATTENDANT')
                elif target_audience == 'general_staff': query = query.filter(role='GENERAL')
                
                for a in query:
                    notifications_to_create.append(Notification(attendant=a, title=title, message=message, target_audience=target_audience))

            fcm_payload = messaging.Message(
                notification=messaging.Notification(title=title, body=message),
                topic=target_audience,
            )
            messaging.send(fcm_payload)

        else:
            if not recipient_ids:
                return Response({"error": "No recipients selected."}, status=400)
            
            target_audience = 'personal'
            
            selected_students = StudentProfile.objects.filter(firebase_uid__in=recipient_ids, landlord=landlord)
            for s in selected_students:
                notifications_to_create.append(Notification(student=s, title=title, message=message, target_audience=target_audience))
                if s.fcm_token: fcm_tokens.append(s.fcm_token)
            
            selected_attendants = AttendantProfile.objects.filter(firebase_uid__in=recipient_ids, landlord=landlord)
            for a in selected_attendants:
                notifications_to_create.append(Notification(attendant=a, title=title, message=message, target_audience=target_audience))
                if a.fcm_token: fcm_tokens.append(a.fcm_token)

            if fcm_tokens:
                multicast_msg = messaging.MulticastMessage(
                    notification=messaging.Notification(title=title, body=message),
                    tokens=fcm_tokens,
                )
                messaging.send_multicast(multicast_msg)

        if not notifications_to_create:
            return Response({"error": "No recipients found."}, status=404)

        notifications_to_create.append(Notification(landlord=landlord, title=title, message=message, target_audience=target_audience, is_read=True))
        Notification.objects.bulk_create(notifications_to_create)

    return Response({"message": "Dispatched successfully."}, status=201)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
def update_fcm_token(request):
    token = request.data.get('fcm_token')
    user = request.user 
    
    if not token:
        return Response({"error": "Token required"}, status=400)
    
    user.fcm_token = token
    user.save()
    return Response({"message": "Token synced successfully."})

@api_view(['POST']) 
def create_seller_subaccount(request):
    uid = request.data.get('firebase_uid')
    business_name = request.data.get('business_name')
    bank_code = request.data.get('bank_code')
    account_number = request.data.get('account_number')
    contact_email = request.data.get('email')

    if not all([uid, business_name, bank_code, account_number, contact_email]):
         return Response({'error': 'Missing required fields'}, status=400)

    try: 
        user = LandlordProfile.objects.get(firebase_uid=uid)
    except LandlordProfile.DoesNotExist:
        return Response({'error': "User not found"}, status=404)
 
    payload = {
        "business_name": business_name,
        "settlement_bank": bank_code,
        "account_number": account_number,
        "percentage_charge": 9.0, 
        "primary_contact_email": contact_email,
    }
    
    headers = {"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}", "Content-Type": "application/json"}

    try:
        resp = requests.post(f"{settings.PAYSTACK_API_BASE}/subaccount", json=payload, headers=headers)
        data = resp.json()
        
        if resp.status_code in [200, 201] and data.get('status') is True:
            sub_code = data['data']['subaccount_code']
            user.seller_paystack_account = sub_code 
            user.save()
            return Response({'success': True, 'subaccount_code': sub_code})
        else:
            return Response({'error': data.get('message')}, status=400)
    except Exception as e:
        logger.error(f"Paystack Subaccount Error: {e}", exc_info=True)
        return Response({'error': "Failed to communicate with payment gateway."}, status=500)


@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
def create_payment_link(request):
    try:
        student = StudentProfile.objects.get(firebase_uid=request.user.firebase_uid)
        issue_id = request.data.get('issue_id')

        if not issue_id: return Response({'error': 'Issue ID is required'}, status=400)

        try:
            issue = Issue.objects.get(id=issue_id, student=student)
            charge = Charge.objects.get(issue=issue, is_paid=False)
        except (Issue.DoesNotExist, Charge.DoesNotExist):
            return Response({'error': 'Valid pending charge not found.'}, status=404)

        amount_cents = int(charge.amount * 100)
        order_ref = f"KEY_{issue.id}_{uuid.uuid4().hex[:8].upper()}"

        body = {
            "email": student.email,
            "amount": amount_cents,
            "currency": "ZAR",
            "reference": order_ref,
            "channels": ['card', 'eft', 'mobile_money']
        }

        headers = {"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}", "Content-Type": "application/json"}
        resp = requests.post("https://api.paystack.co/transaction/initialize", json=body, headers=headers)
        
        if resp.status_code != 200: return Response({'error': "Payment gateway initialization failed."}, status=400)

        data = resp.json()
        if not data.get('status'): return Response({'error': data.get('message')}, status=400)

        return Response({'paymentLink': data['data']['authorization_url'], 'reference': order_ref}, status=200)

    except StudentProfile.DoesNotExist:
        return Response({'error': 'Student profile not found'}, status=403)
    except Exception as e:
        logger.error(f"Payment Link Error: {e}", exc_info=True)
        return Response({'error': "Internal server error during payment initialization."}, status=500)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny]) 
def paystack_webhook(request):
    paystack_signature = request.headers.get('x-paystack-signature')
    if not paystack_signature: return Response({'status': 'missing signature'}, status=400)

    secret = settings.PAYSTACK_SECRET_KEY.encode('utf-8')
    body = request.body
    hash_calc = hmac.new(secret, body, hashlib.sha512).hexdigest()

    if hash_calc != paystack_signature: return Response({'status': 'invalid signature'}, status=400)

    try:
        event_data = json.loads(body)
        if event_data.get('event') == 'charge.success':
            reference = event_data['data']['reference']
            verified_amount = event_data['data']['amount'] 
            
            headers = {"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}", "Content-Type": "application/json"}
            verify_resp = requests.get(f"https://api.paystack.co/transaction/verify/{reference}", headers=headers)
            
            if verify_resp.status_code == 200:
                verify_data = verify_resp.json()
                if verify_data.get('status') and verify_data['data']['status'] == 'success':
                    api_verified_amount = verify_data['data']['amount']
                    
                    if reference.startswith("KEY_"):
                        parts = reference.split('_')
                        if len(parts) >= 2:
                            issue_id = parts[1]
                            try:
                                issue = Issue.objects.get(id=issue_id)
                                charge = Charge.objects.get(issue=issue, is_paid=False)
                                
                                expected_amount_cents = int(charge.amount * 100)
                                if api_verified_amount >= expected_amount_cents:
                                    issue.status = 'READY_FOR_COLLECTION'
                                    issue.save()
                                    charge.is_paid = True
                                    charge.save()
                                else:
                                    logger.error(f"Webhook Exploit Attempt: Paid {api_verified_amount} cents, expected {expected_amount_cents} cents for ref {reference}")
                                    return Response({'status': 'fraud_detected'}, status=400)
                                    
                            except (Issue.DoesNotExist, Charge.DoesNotExist) as e:
                                logger.error(f"Webhook error: Missing issue or charge for ref {reference}. Detail: {e}")
                                return Response({'status': 'error', 'detail': 'Resource not found'}, status=404)

        return Response({'status': 'success'}, status=200)

    except Exception as e:
        logger.error(f"Webhook Error: {e}", exc_info=True)
        return Response({'status': 'error'}, status=500)
    
    
@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated,IsAttendant]) 
def verify_gate_pass_qr(request):
    qr_reference = request.data.get('qr_reference')

    if not qr_reference:
        return Response({'error': 'No QR reference provided.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        gate_pass = GatePass.objects.get(id=qr_reference)
        student = gate_pass.student
        
        is_expired = timezone.now() > gate_pass.expires_at or not gate_pass.is_active
        
        response_data = {
            'id': str(gate_pass.id),
            'status': 'EXPIRED' if is_expired else 'ACTIVE',
            'student_name': f"{student.name} {student.surname}",
            'student_number': getattr(student, 'student_number', 'N/A'),
            'asset_name': gate_pass.asset_name,
            'asset_number': gate_pass.asset_number,
            'expires_at': gate_pass.expires_at.isoformat()
        }

        return Response(response_data, status=status.HTTP_200_OK)

    except GatePass.DoesNotExist:
        return Response({'error': 'INVALID OR FAKE QR CODE DETECTED.'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Gate Pass Verification Error: {e}", exc_info=True)
        return Response({'error': 'An internal server error occurred.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
     

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication]) 
@permission_classes([IsAuthenticated, IsLandlord]) 
@parser_classes([MultiPartParser, FormParser]) 
def add_student_by_landlord(request):
    student_number = str(request.data.get('student_number', '')).strip()
    id_number = request.data.get('id_number')
    name = request.data.get('name')
    surname = request.data.get('surname')
    phone = request.data.get('phone', '')
    room_id = request.data.get('room_id')
    face_image = request.FILES.get('face_image') 

    if not all([student_number, id_number, name, surname]):
        return Response({"error": "Required fields missing."}, status=400)

    if len(id_number) < 6:
        return Response({"error": "Invalid ID."}, status=400)

    if face_image and face_image.size > MAX_UPLOAD_SIZE:
        return Response({"error": "Face image exceeds 5MB limit."}, status=400)

    if len(student_number) == 9:
        email = f"{student_number}@edu.vut.ac.za"
    else:
        email = request.data.get('email')
        if not email:
            return Response({"error": "An email address is strictly required because the student number is not 9 digits long."}, status=400)

    password = id_number[:6] 
    landlord = request.user 

    try: 
        firebase_user = auth.create_user(email=email, password=password, display_name=f"{name} {surname}")
        
        try:
            with transaction.atomic():
                room = None
                if room_id:
                    try:
                        room = Room.objects.get(id=room_id)
                    except Room.DoesNotExist:
                        raise ValueError("Invalid Room ID provided. Room does not exist.") 

                face_url = None
                face_encoding_string = "" 
                
                if face_image:
                    file_bytes = face_image.read()
                    
                    temp_face = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
                    with open(temp_face, 'wb+') as f:
                        f.write(file_bytes)
                    
                    try:
                        import face_recognition
                        img_data = face_recognition.load_image_file(temp_face)
                        encodings = face_recognition.face_encodings(img_data)
                        if encodings:
                            face_encoding_string = json.dumps(encodings[0].tolist())
                    except Exception as e:
                        logger.error(f"Failed to generate face encoding: {e}")
                    finally:
                        os.remove(temp_face)

                    cipher_suite = Fernet(settings.FERNET_KEY)
                    encrypted_bytes = cipher_suite.encrypt(file_bytes)

                    ext = os.path.splitext(face_image.name)[1]
                    filename = f"secure_faces/{student_number}_{uuid.uuid4().hex}{ext}.enc"
                    
                    bucket = storage.bucket()
                    blob = bucket.blob(filename)
                    blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                    blob.make_public()

                    face_url = blob.public_url 

                student = StudentProfile.objects.create(
                    landlord=landlord, firebase_uid=firebase_user.uid, name=name, surname=surname,
                    email=email, student_number=student_number, id_number=id_number, phone=phone,
                    room=room, face_url=face_url, requires_password_change=True,
                    verification_status=False,
                    face_encoding_json=face_encoding_string     )

                return Response({"message": "Student successfully registered and face encrypted.", "student_id": student.id}, status=201)
                
        except ValueError as ve:
            auth.delete_user(firebase_user.uid)
            return Response({"error": str(ve)}, status=400)
        except Exception as e:
            auth.delete_user(firebase_user.uid)
            logger.error(f"Student Registration DB/Storage Error: {e}", exc_info=True)
            return Response({"error": "Failed to complete student registration."}, status=500)

    except auth.EmailAlreadyExistsError:
        return Response({"error": "Student exists."}, status=400)
    except Exception as e:
        logger.error(f"Firebase Creation Error: {e}", exc_info=True)
        return Response({"error": "Authentication provider error."}, status=500) 


@api_view(['POST'])
@permission_classes([AllowAny]) 
@parser_classes([MultiPartParser, FormParser]) 
def student_self_register(request):
    student_number = str(request.data.get('student_number', '')).strip()
    name = request.data.get('name')
    surname = request.data.get('surname')
    password = request.data.get('password')
    id_document = request.FILES.get('id_document') 
    proof_of_registration = request.FILES.get('proof_of_registration')

    if not all([student_number, name, surname, password]):
        return Response({"error": "Required text fields missing."}, status=400)

    if id_document and id_document.size > MAX_UPLOAD_SIZE:
        return Response({"error": "ID Document exceeds 5MB limit."}, status=400)
    if proof_of_registration and proof_of_registration.size > MAX_UPLOAD_SIZE:
        return Response({"error": "Proof of registration exceeds 5MB limit."}, status=400)

    if len(student_number) == 9:
        email = f"{student_number}@edu.vut.ac.za"
    else:
        email = request.data.get('email')
        if not email:
            return Response({"error": "An email address is strictly required because your student number is not 9 digits long."}, status=400)

    try: 
        firebase_user = auth.create_user(email=email, password=password, display_name=f"{name} {surname}")

        try:
            with transaction.atomic():
                id_doc_url = None
                proof_doc_url = None
                cipher_suite = Fernet(settings.FERNET_KEY)
                bucket = storage.bucket()

                if id_document:
                    file_bytes = id_document.read()
                    encrypted_bytes = cipher_suite.encrypt(file_bytes)
                    ext = os.path.splitext(id_document.name)[1]
                    filename = f"secure_docs/ID_{student_number}_{uuid.uuid4().hex}{ext}.enc"

                    blob = bucket.blob(filename)
                    blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                    blob.make_public()
                    
                    id_doc_url = blob.public_url 

                if proof_of_registration:
                    file_bytes = proof_of_registration.read()
                    encrypted_bytes = cipher_suite.encrypt(file_bytes)
                    ext = os.path.splitext(proof_of_registration.name)[1]
                    filename = f"secure_docs/PROOF_{student_number}_{uuid.uuid4().hex}{ext}.enc"

                    blob = bucket.blob(filename)
                    blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                    blob.make_public()
                    
                    proof_doc_url = blob.public_url 

                student = StudentProfile.objects.create(
                    firebase_uid=firebase_user.uid, 
                    name=name, 
                    surname=surname,
                    email=email, 
                    student_number=student_number, 
                    id_document_url=id_doc_url,
                    proof_of_registration_url=proof_doc_url,
                    requires_password_change=False,
                    verification_status=False 
                )

                return Response({"message": "Student successfully registered."}, status=201)
                
        except Exception as e:
            auth.delete_user(firebase_user.uid)
            logger.error(f"Student Self-Reg DB/Storage Error: {e}", exc_info=True)
            return Response({"error": "Registration failed during document security processing."}, status=500)

    except auth.EmailAlreadyExistsError:
        return Response({"error": "A student with this number/email already exists."}, status=400)
    except Exception as e:
        logger.error(f"Student Self-Reg Auth Error: {e}", exc_info=True)
        return Response({"error": "Authentication provider error."}, status=500)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@authentication_classes([FirebaseAuthentication])
@parser_classes([MultiPartParser, FormParser])
def verify_student_presence(request, student_id):
    live_file = request.FILES.get('live_face')

    if not live_file:
        return Response({'error': 'Missing live face image.'}, status=400)
        
    if live_file.size > MAX_UPLOAD_SIZE:
        return Response({'error': 'Face image exceeds 5MB limit.'}, status=400)

    try:
        student = StudentProfile.objects.get(id=student_id)
        
        if not student.face_url:
            return Response({'error': 'Student has no registered face.'}, status=400)

        temp_live = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
        with open(temp_live, 'wb+') as f:
            for chunk in live_file.chunks(): 
                f.write(chunk)
                
        try:
            result = perform_verification(
                live_path=temp_live, 
                ref_path=_extract_blob_path(student.face_url), 
                is_encrypted_ref=True
            )
            
            if result.get('error'): 
                return Response({'error': 'Verification engine processing error.'}, status=400)
                
            if result.get('matched'):
                student.verification_status = True
                student.save()
                return Response({'message': 'Biometric match successful. Student verified.', 'distance': result.get('score', 0.0)}, status=200)
            else:
                return Response({'error': 'Biometric mismatch. Verification failed.'}, status=403)
                
        finally:
            if os.path.exists(temp_live): 
                os.remove(temp_live)

    except StudentProfile.DoesNotExist:
        return Response({'error': 'Student not found.'}, status=404)
    except Exception as e:
        logger.error(f"Student Presence Verification Error: {e}", exc_info=True)
        return Response({'error': 'An internal server error occurred.'}, status=500)


class ApplyAccommodationView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        uid = getattr(request.user, 'firebase_uid', None) or getattr(request.user, 'username', None)
        try:
            student = StudentProfile.objects.get(firebase_uid=uid)
        except StudentProfile.DoesNotExist:
            return Response({"error": "Access denied."}, status=status.HTTP_403_FORBIDDEN)

        if not student.applied_accommodation:
            return Response([], status=status.HTTP_200_OK)

        application_data = {
            "id": str(student.applied_accommodation.id),
            "accommodation_name": student.applied_accommodation.name,
            "status": "Pending", 
            "created_at": student.updated_at.isoformat() 
        }

        return Response([application_data], status=status.HTTP_200_OK)

    def post(self, request):
        accommodation_id = request.data.get('accommodation_id')
        if not accommodation_id:
            return Response({"error": "Accommodation identification field is required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            accommodation = Accommodation.objects.get(id=accommodation_id)
        except Accommodation.DoesNotExist:
            return Response({"error": "Target accommodation entity could not be found."}, status=status.HTTP_404_NOT_FOUND)

        uid = getattr(request.user, 'firebase_uid', None) or getattr(request.user, 'username', None)
        try:
            student = StudentProfile.objects.get(firebase_uid=uid)
        except StudentProfile.DoesNotExist:
            return Response({"error": "Access denied."}, status=status.HTTP_403_FORBIDDEN)

        if not student.id_document_url or not student.proof_of_registration_url:
            return Response({"error": "Application rejected. Critical documentation is missing."}, status=status.HTTP_400_BAD_REQUEST)

        student.landlord = accommodation.landlord
        student.applied_accommodation = accommodation 
        student.save()

        Notification.objects.create(
            landlord=accommodation.landlord,
            title="New Application Received",
            message=f"Student {student.name} {student.surname} applied for enrollment at {accommodation.name}.",
            target_audience="personal"
        )

        return Response({"message": "Application processed successfully."}, status=status.HTTP_201_CREATED)
    
import urllib.parse
from django.http import HttpResponse

@api_view(['GET'])
@permission_classes([AllowAny]) # Token is verified manually in the code
def serve_decrypted_file_by_url(request):
    """
    Universally takes an encrypted Firebase URL, decrypts it on the fly, 
    and serves the raw image bytes.
    """
    token = request.query_params.get('token')
    file_url = request.query_params.get('file_url')
    
    if not token or not file_url:
        return HttpResponse("Unauthorized: Missing token or file_url", status=401)
        
    try:
        # 1. Verify the user is authenticated
        auth.verify_id_token(token)
        
        # 2. Decode the Firebase URL (since it has to be URL-encoded to pass as a parameter)
        decoded_file_url = urllib.parse.unquote(file_url)
            
        # 3. Fetch encrypted bytes from Firebase Storage
        resp = requests.get(decoded_file_url)
        if resp.status_code != 200:
            return HttpResponse("Encrypted file not found in storage.", status=404)
            
        # 4. Decrypt the bytes
        cipher_suite = Fernet(settings.FERNET_KEY)
        decrypted_data = cipher_suite.decrypt(resp.content)
        
        # 5. Serve the raw image bytes exactly like an image hosting server
        return HttpResponse(decrypted_data, content_type="image/jpeg")
        
    except auth.InvalidIdTokenError:
        return HttpResponse("Unauthorized: Invalid token", status=401)
    except Exception as e:
        logger.error(f"Universal Image Decryption Error: {e}", exc_info=True)
        return HttpResponse("Internal Server Error", status=500)
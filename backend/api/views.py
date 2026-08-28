import os
import threading
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

import urllib.parse
from django.http import HttpResponse

import firebase_admin
from firebase_admin import auth, storage
from cryptography.fernet import Fernet
from PIL import Image, ImageOps

# Custom Authentication
from .authentication import FirebaseAuthentication
from .face_utils import perform_verification, decrypt_to_base64

# Models
from .models import (
    AdminProfile, LandlordProfile, Block, Unit, Accommodation, Notification, Room, StudentProfile, 
    AttendantProfile, Issue, Charge, LeavePermit, RoomInspection, GatePass,
    CampusLocation, StudentMedicalProfile, EmergencyReport, EmergencyAccessLog, VisitorAuditLog, VisitorRegister,
    MedicalResponderProfile
)

# Serializers
from .serializers import (
    AdminProfileSerializer, EmergencyAccessLogSerializer, GatePassSerializer, LandlordProfileSerializer, BlockSerializer, UnitSerializer, AccommodationSerializer, 
    RoomSerializer, StudentProfileSerializer, AttendantProfileSerializer, IssueSerializer, 
    ChargeSerializer, LeavePermitSerializer, RoomInspectionSerializer, NotificationSerializer,
    CampusLocationSerializer, StudentMedicalProfileSerializer, EmergencyReportSerializer, VisitorRegisterSerializer,
    MedicalResponderProfileSerializer, VisitorAuditLogSerializer
)

logger = logging.getLogger(__name__)

MAX_UPLOAD_SIZE = 5 * 1024 * 1024  

# ----------------------------------------------------------------------
# STRICT ROLE ENFORCEMENT UTILITY
# ----------------------------------------------------------------------
def strict_role_check(request, allowed_roles):
    """
    Instantly drops requests if the user's role does not match the required roles for the endpoint.
    Triggers the frontend to redirect the user back to the login screen.
    """
    user_role = getattr(request, 'user_role', None)
    if user_role not in allowed_roles:
        return Response(
            {'error': "You're not permitted. Please log in with the correct role."}, 
            status=status.HTTP_403_FORBIDDEN
        )
    return None

# ----------------------------------------------------------------------
# BEAUTIFULLY DESIGNED EMAIL SENDER FUNCTION (ASYNC)
# ----------------------------------------------------------------------
def send_html_email_async(to_email, subject, message_content, logo_url=None):
    if not to_email: return

    default_logo = "https://firebasestorage.googleapis.com/v0/b/membersisstant.firebasestorage.app/o/FCMImages%2Fmemberssistant_icon.png?alt=media&token=01c986f2-5504-497b-bd75-e271edb4abf7"
    final_logo = logo_url if logo_url else default_logo

    def send_task():
        html_body = f"""
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; background-color: #f8fafc; padding: 10px; border-radius: 12px; border: 1px solid #e2e8f0;">
            <div style="background-color: #0f172a; padding: 20px; border-radius: 10px 10px 0 0; text-align: center;">
                <img src="{final_logo}" alt="Logo" style="max-height: 55px; margin-bottom: 8px; border-radius: 4px;">
                <h1 style="color: #ffffff; margin: 0; font-size: 22px; font-weight: 800; letter-spacing: 1px;">Memberssistant</h1>
                <p style="color: #94a3b8; margin: 2px 0 0 0; font-size: 13px;">Smart Residence Management</p>
            </div>
            <div style="background-color: #ffffff; padding: 20px; border-radius: 0 0 10px 10px; color: #334155; line-height: 1.5; font-size: 15px; border: 1px solid #e2e8f0; border-top: none;">
                {message_content}
            </div>
            <div style="text-align: center; margin-top: 15px; color: #64748b; font-size: 12px;">
                <p style="margin: 3px 0;">&copy; {timezone.now().year} MK TECHCLOUD (Pty) Ltd. All rights reserved.</p>
                <p style="margin: 3px 0;">This is an automated security message. Please do not reply directly to this email.</p>
            </div>
        </div>
        """
        try:
            url = 'https://api-w6yanm6o4q-uc.a.run.app/sendCustomEmail'
            payload = {"to": to_email, "subject": subject, "body": html_body, "attachmentUrl": ""}
            requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=10)
        except Exception as e:
            logger.error(f"Failed to send email to {to_email}: {e}")

    threading.Thread(target=send_task).start()

def _extract_blob_path(url):
    if not url: return url
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
    if err := strict_role_check(request, ['student', 'attendant']): return err

    try:
        uid = request.user.firebase_uid
        reporting_student = None
        reporting_attendant = None

        if getattr(request, 'user_role') == 'student':
            reporting_student = StudentProfile.objects.get(firebase_uid=uid)
        elif getattr(request, 'user_role') == 'attendant':
            reporting_attendant = AttendantProfile.objects.get(firebase_uid=uid)

        situation_image = request.FILES.get('situation_image')
        if not situation_image:
            return Response({"error": "Situation image required for patient identification."}, status=400)

        temp_img = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
        with open(temp_img, 'wb+') as f:
            for chunk in situation_image.chunks(): f.write(chunk)

        identified_patient_profile = None
        face_encoding_string = "" 
        
        try:
            pil_image = Image.open(temp_img)
            pil_image = ImageOps.exif_transpose(pil_image) 
            if pil_image.mode != 'RGB': pil_image = pil_image.convert('RGB') 
            
            live_image = np.array(pil_image) 
            live_encodings = face_recognition.face_encodings(live_image)

            if live_encodings:
                live_encoding = live_encodings[0]
                face_encoding_string = json.dumps(live_encoding.tolist()) 
                
                best_match_id = None
                min_distance = 0.60 
                
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
        except Exception as e:
            logger.error(f"AI Identification Process Failed: {e}", exc_info=True)

        cipher_suite = Fernet(settings.FERNET_KEY)
        encrypted_bytes = cipher_suite.encrypt(open(temp_img, 'rb').read())
        filename = f"secure_emergencies/req_{uuid.uuid4().hex}.jpg.enc"
        
        bucket = storage.bucket()
        blob = bucket.blob(filename)
        blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
        blob.make_public()
        image_url = blob.public_url

        if os.path.exists(temp_img): os.remove(temp_img)

        try:
            lat = float(request.data.get('latitude', 0.0))
            lng = float(request.data.get('longitude', 0.0))
        except (ValueError, TypeError):
            lat = 0.0; lng = 0.0

        emergency = EmergencyReport.objects.create(
            reporting_student=reporting_student,
            reporting_attendant=reporting_attendant, 
            identified_patient=identified_patient_profile,
            latitude=lat,
            longitude=lng,
            emergency_type=request.data.get('emergency_type', 'Other'),
            description=request.data.get('description', ''),
            situation_image_url=image_url,
            face_encoding_json=face_encoding_string 
        )

        patient_name = f"{identified_patient_profile.name} {identified_patient_profile.surname}" if identified_patient_profile else "Unidentified Patient"
        reporter_name = reporting_student.name if reporting_student else (reporting_attendant.name if reporting_attendant else "Unknown")
        
        clinic_responders = MedicalResponderProfile.objects.filter(is_active=True)
        clinic_emails = set(r.email for r in clinic_responders if r.email)
        clinic_tokens = list(set(r.fcm_token for r in clinic_responders if r.fcm_token))

        clinic_email_msg = f"""
        <h2 style="color: #b91c1c; font-weight: bold;">🚨 UNIVERSITY CLINIC DISPATCH: {emergency.emergency_type.upper()}</h2>
        <p>A medical emergency has been reported requiring immediate clinic attention.</p>
        <div style="background-color: #fef2f2; padding: 15px; border-left: 4px solid #b91c1c; margin: 15px 0;">
            <p style="margin: 0 0 5px 0;"><strong>Patient Identified:</strong> {patient_name}</p>
            <p style="margin: 0 0 5px 0;"><strong>Reported By:</strong> {reporter_name}</p>
            <p style="margin: 0;"><strong>Incident Description:</strong> {emergency.description}</p>
        </div>
        <p>Please log into the Medical Responder Dashboard immediately to access secure GPS coordinates and unlock the patient's strictly confidential medical history.</p>
        """

        for c_email in clinic_emails:
            send_html_email_async(c_email, f"CLINIC ALERT: {emergency.emergency_type.upper()}", clinic_email_msg)

        if clinic_tokens:
            msg = messaging.MulticastMessage(
                notification=messaging.Notification(title=f"CLINIC DISPATCH: {emergency.emergency_type.upper()}", body=f"Patient: {patient_name}. Tap to view location and secure medical file."),
                tokens=clinic_tokens,
                android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(sound='default')),
                apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(sound='default', badge=1)))
            )
            messaging.send_each_for_multicast(msg)

        notify_landlord = None
        if identified_patient_profile and identified_patient_profile.landlord:
            notify_landlord = identified_patient_profile.landlord
        elif reporting_student and reporting_student.landlord:
            notify_landlord = reporting_student.landlord
        elif reporting_attendant and reporting_attendant.landlord:
            notify_landlord = reporting_attendant.landlord

        if notify_landlord and notify_landlord.email:
            landlord_email_msg = f"""
            <h2 style="color: #b91c1c; font-weight: bold;">🚨 INCIDENT REPORT: {emergency.emergency_type.upper()}</h2>
            <p>An emergency incident has been logged at your property.</p>
            <p><strong>Patient Involved:</strong> {patient_name}</p>
            <p><strong>Reported By:</strong> {reporter_name}</p>
            <p><em>Please Note: The University Clinic has been automatically notified and dispatched. Detailed medical records remain strictly confidential and are only accessible by registered clinic personnel.</em></p>
            """
            send_html_email_async(notify_landlord.email, f"INCIDENT ALERT: {emergency.emergency_type.upper()}", landlord_email_msg)

        return Response({"message": "Alert Sent Successfully to University Clinic."}, status=201)

    except Exception as e:
        logger.error(f"Emergency Creation Error: {e}", exc_info=True)
        return Response({"error": "Failed to dispatch emergency."}, status=500)

class EmergencyAccessLogViewSet(BaseSecureViewSet):
    serializer_class = EmergencyAccessLogSerializer
    
    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role in ['responder', 'admin']:
            return EmergencyAccessLog.objects.select_related('student_accessed', 'report').all().order_by('-created_at')
        return EmergencyAccessLog.objects.none()

    def get_permissions(self):
        return super().get_permissions()

class MedicalResponderProfileViewSet(BaseSecureViewSet):
    serializer_class = MedicalResponderProfileSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['firebase_uid']

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role == 'admin':
            return MedicalResponderProfile.objects.all()
        elif user_role == 'responder':
            return MedicalResponderProfile.objects.filter(id=self.request.user.id)
        return MedicalResponderProfile.objects.none()

    def destroy(self, request, *args, **kwargs):
        if getattr(request, 'user_role', None) != 'admin':
            return Response({'error': "You're not permitted. Please log in with the correct role."}, status=status.HTTP_403_FORBIDDEN)
            
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
    if err := strict_role_check(request, ['admin']): return err

    id_number = request.data.get('id_number')
    name = request.data.get('name')
    email = request.data.get('email')
    surname = request.data.get('surname')
    phone = request.data.get('phone', '')
    face_image = request.FILES.get('face_image')  

    if not all([id_number, name, email, surname]):
        return Response({"error": "Missing required fields."}, status=status.HTTP_400_BAD_REQUEST)

    if face_image and face_image.size > MAX_UPLOAD_SIZE:
        return Response({"error": "Face image exceeds the 5MB size limit."}, status=status.HTTP_400_BAD_REQUEST)

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
                    firebase_uid=firebase_user.uid, name=name, surname=surname,
                    email=email, phone=phone, face_url=face_url
                )

                welcome_msg = f"""
                <h2 style="color: #0f172a;">Welcome to the Team, {name}!</h2>
                <p>You have been successfully registered as a Medical Responder on the Memberssistant Platform.</p>
                <div style="background-color: #f1f5f9; padding: 15px; border-radius: 8px; margin: 15px 0;">
                    <p style="margin: 0;"><strong>Email:</strong> {email}</p>
                    <p style="margin: 5px 0 0 0;"><strong>Temporary Password:</strong> {password}</p>
                </div>
                <p>Please log in to the mobile application to access the emergency dispatch dashboard and configure your biometric authentication.</p>
                """
                send_html_email_async(email, "Welcome to the Medical Responder Team", welcome_msg)

            return Response({"message": "Medical Responder successfully registered.", "responder_id": responder.id}, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            auth.delete_user(firebase_user.uid)
            logger.error(f"Responder DB/Storage Error: {e}", exc_info=True)
            return Response({"error": "Failed to encrypt biometrics or complete registration."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    except auth.EmailAlreadyExistsError:
        return Response({"error": "An account with this email already exists."}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Firebase Creation Error: {e}", exc_info=True)
        return Response({"error": "Authentication provider error."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def verify_responder_login(request):
    if err := strict_role_check(request, ['responder']): return err

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
            for chunk in live_file.chunks(): f.write(chunk)
                
        try:
            result = perform_verification(live_path=temp_live, ref_path=_extract_blob_path(responder.face_url), is_encrypted_ref=True)
            
            if result.get('error'): 
                return Response({'error': 'Verification engine processing error.'}, status=400)
                
            if result.get('matched'):
                return Response({'message': 'Biometric match successful. Dispatch access granted.'}, status=200)
            else:
                return Response({'error': 'Biometric mismatch. Unauthorized access attempt logged.'}, status=403)
                
        finally:
            if os.path.exists(temp_live): os.remove(temp_live)

    except MedicalResponderProfile.DoesNotExist:
        return Response({'error': 'Medical Responder profile not found in system.'}, status=404)
    except Exception as e:
        logger.error(f"Responder Login Verification Error: {e}", exc_info=True)
        return Response({'error': 'An internal server error occurred during biometric verification.'}, status=500)


@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
def unlock_medical_data(request):
    if err := strict_role_check(request, ['responder']): return err

    report_id = request.data.get('report_id')
    patient_id = request.data.get('patient_id') 

    if not report_id: return Response({'error': 'Missing report ID.'}, status=400)

    try:
        report = EmergencyReport.objects.get(id=report_id)
        staff_user = request.user 
        
        if patient_id:
            try:
                target_student = StudentProfile.objects.get(id=patient_id)
            except StudentProfile.DoesNotExist:
                return Response({'error': 'Patient not found in system.'}, status=404)
        else:
            target_student = report.identified_patient
            
        if not target_student:
            return Response({'error': 'No patient identified in this report.'}, status=404)

        with transaction.atomic():
            EmergencyAccessLog.objects.create(
                report=report, accessed_by_uid=staff_user.firebase_uid, student_accessed=target_student 
            )
            
            room_number = "Unassigned"
            block_name = "Unassigned Block"
            
            if target_student.room:
                room_number = target_student.room.room_number
                if hasattr(target_student.room, 'unit') and target_student.room.unit and target_student.room.unit.block:
                    block_name = target_student.room.unit.block.name
                elif target_student.room.block:
                    block_name = target_student.room.block.name
            
            try:
                medical_profile = StudentMedicalProfile.objects.get(student=target_student)
                return Response({
                    "student_name": f"{target_student.name} {target_student.surname}",
                    "student_number": target_student.student_number,
                    "face_url": target_student.face_url,
                    "room_number": room_number,
                    "block_name": block_name,
                    "blood_type": medical_profile.blood_type,
                    "allergies": medical_profile.allergies,
                    "medical_conditions": medical_profile.medical_conditions,
                    "emergency_contact_name": medical_profile.emergency_contact_name,
                    "emergency_contact_phone": medical_profile.emergency_contact_phone,
                    "emergency_contact_relation": medical_profile.emergency_contact_relation
                }, status=200)
                
            except StudentMedicalProfile.DoesNotExist:
                return Response({
                    "student_name": f"{target_student.name} {target_student.surname}",
                    "student_number": target_student.student_number,
                    "face_url": target_student.face_url,
                    "room_number": room_number,
                    "block_name": block_name,
                    "blood_type": "Unknown", "allergies": "No profile recorded", "medical_conditions": "No profile recorded",
                    "emergency_contact_name": "N/A", "emergency_contact_phone": "N/A", "emergency_contact_relation": "N/A"
                }, status=200)

    except EmergencyReport.DoesNotExist:
        return Response({'error': 'Emergency report not found.'}, status=404)
    except Exception as e:
        logger.error(f"Medical Access Error: {e}", exc_info=True)
        return Response({'error': 'An internal server error occurred.'}, status=500)     
        
class CampusLocationViewSet(BaseSecureViewSet):
    queryset = CampusLocation.objects.all()
    serializer_class = CampusLocationSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['location_type']

    def get_queryset(self):
        return CampusLocation.objects.all()

class StudentMedicalProfileViewSet(BaseSecureViewSet):
    serializer_class = StudentMedicalProfileSerializer

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role == 'student':
            return StudentMedicalProfile.objects.filter(student=self.request.user)
        elif user_role == 'responder':
            return StudentMedicalProfile.objects.all()
        return StudentMedicalProfile.objects.none()

    def perform_create(self, serializer):
        try:
            student = StudentProfile.objects.get(firebase_uid=self.request.user.firebase_uid)
            serializer.save(student=student)
        except StudentProfile.DoesNotExist:
            raise ValidationError({"error": "Only student profiles can update medical data."})
        
class EmergencyReportViewSet(BaseSecureViewSet):
    serializer_class = EmergencyReportSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['status']
    parser_classes = [MultiPartParser, FormParser, JSONParser] 

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role == 'responder' or user_role == 'admin': 
            return EmergencyReport.objects.all().order_by('-created_at')
        elif user_role == 'student': 
            return EmergencyReport.objects.filter(reporting_student=self.request.user).order_by('-created_at')
        elif user_role == 'attendant': 
            return EmergencyReport.objects.filter(reporting_attendant=self.request.user).order_by('-created_at')
        elif user_role == 'landlord':
            return EmergencyReport.objects.filter(
                Q(reporting_student__landlord=self.request.user) |
                Q(reporting_attendant__landlord=self.request.user)
            ).order_by('-created_at')
        return EmergencyReport.objects.none()

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def unlock_medical_data_dual(request):
    if err := strict_role_check(request, ['responder']): return err

    report_id = request.data.get('report_id')
    staff_face = request.FILES.get('staff_face')
    student_face = request.FILES.get('student_face')

    if not all([report_id, staff_face, student_face]): return Response({'error': 'Missing report ID or facial scans.'}, status=400)
    if staff_face.size > MAX_UPLOAD_SIZE or student_face.size > MAX_UPLOAD_SIZE: return Response({'error': 'Facial scan images exceed size limit.'}, status=400)

    try:
        report = EmergencyReport.objects.get(id=report_id)
        student = report.reporting_student
        staff_user = request.user 
        
        if not hasattr(staff_user, 'face_url') or not staff_user.face_url: return Response({'error': 'Authorized responder has no registered face.'}, status=403)
        if not student.face_url: return Response({'error': 'Student has no registered face.'}, status=400)

        temp_staff = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
        temp_student = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
        
        try:
            with open(temp_staff, 'wb+') as f:
                for chunk in staff_face.chunks(): f.write(chunk)
            with open(temp_student, 'wb+') as f:
                for chunk in student_face.chunks(): f.write(chunk)
                
            staff_result = perform_verification(live_path=temp_staff, ref_path=_extract_blob_path(staff_user.face_url), is_encrypted_ref=True)
            if not staff_result.get('matched'): return Response({'error': 'Responder biometric verification failed. Access Denied.'}, status=403)

            student_result = perform_verification(live_path=temp_student, ref_path=_extract_blob_path(student.face_url), is_encrypted_ref=True)
            if not student_result.get('matched'): return Response({'error': 'Student biometric verification failed. Ensure you are scanning the correct patient.'}, status=403)
            
            with transaction.atomic():
                EmergencyAccessLog.objects.create(report=report, accessed_by_uid=staff_user.firebase_uid, student_accessed=student)
                try:
                    medical_profile = StudentMedicalProfile.objects.get(student=student)
                    return Response({
                        "blood_type": medical_profile.blood_type, "allergies": medical_profile.allergies,
                        "medical_conditions": medical_profile.medical_conditions, "emergency_contact_name": medical_profile.emergency_contact_name,
                        "emergency_contact_phone": medical_profile.emergency_contact_phone, "emergency_contact_relation": medical_profile.emergency_contact_relation
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


@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser]) 
def verify_landlord_identity_app(request):
    if err := strict_role_check(request, ['landlord']): return err

    landlord = getattr(request.user, 'landlord_profile', None) or request.user
    if not landlord: return Response({'error': 'User profile is not registered as a landlord.'}, status=status.HTTP_400_BAD_REQUEST)

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
        face_blob.upload_from_string(cipher_suite.encrypt(live_face.read()), content_type='application/octet-stream')
        face_blob.make_public()
        landlord.face_url = face_blob.public_url

        id_document.seek(0)
        id_ext = os.path.splitext(id_document.name)[1].lower() or '.jpg'
        id_blob_name = f"secure_docs/landlord_{landlord.id}_id_{uuid.uuid4().hex}{id_ext}.enc"
        id_blob = bucket.blob(id_blob_name)
        id_blob.upload_from_string(cipher_suite.encrypt(id_document.read()), content_type='application/octet-stream')
        id_blob.make_public()
        landlord.id_document_url = id_blob.public_url

        contract_file.seek(0)
        contract_ext = os.path.splitext(contract_file.name)[1].lower() or '.pdf'
        contract_blob_name = f"secure_contracts/landlord_{landlord.id}_contract_{uuid.uuid4().hex}{contract_ext}.enc"
        contract_blob = bucket.blob(contract_blob_name)
        contract_blob.upload_from_string(cipher_suite.encrypt(contract_file.read()), content_type='application/octet-stream')
        contract_blob.make_public()
        landlord.contract_url = contract_blob.public_url

        landlord.is_identity_verified = False  
        landlord.save()

        msg = f"""
        <h2 style="color: #0f172a;">Identity Documents Received</h2>
        <p>Dear {landlord.name},</p>
        <p>We have successfully received your encrypted biometric and legal documents.</p>
        <p>Our verification team will review your submission shortly. You will receive an update once your landlord account is fully verified and activated.</p>
        """
        send_html_email_async(landlord.email, "Verification Documents Uploaded", msg)

        return Response({'message': 'Identity documents successfully uploaded and encrypted.', 'face_url': landlord.face_url, 'id_document_url': landlord.id_document_url, 'contract_url': landlord.contract_url}, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error during landlord verification asset upload: {e}", exc_info=True)
        return Response({'error': 'Internal server error processing security files.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
def request_manual_review(request):
    if err := strict_role_check(request, ['landlord']): return err

    try:
        landlord = LandlordProfile.objects.get(firebase_uid=request.user.firebase_uid)
        landlord.manual_verification_status = True
        landlord.save()

        msg = f"""
        <h2 style="color: #0f172a;">Manual Review Requested</h2>
        <p>Dear {landlord.name},</p>
        <p>Your account has been officially flagged for manual administrator review.</p>
        <p>Our compliance team will investigate your documentation and reach out if any further information is required.</p>
        """
        send_html_email_async(landlord.email, "Manual Review Request Confirmed", msg)

        return Response({'message': 'Account officially flagged for manual administrator review.'}, status=200)
    except LandlordProfile.DoesNotExist:
        return Response({'error': 'Landlord profile not found.'}, status=404)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated]) 
def verify_permit_qr(request):
    if err := strict_role_check(request, ['admin', 'attendant']): return err

    qr_reference = request.data.get('qr_reference')
    if not qr_reference: return Response({'error': 'No QR reference provided.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        permit = LeavePermit.objects.get(qr_reference=qr_reference)
        student = permit.student
        
        response_data = {
            'id': permit.id, 'status': permit.status, 'student_name': f"{student.name} {student.surname}",
            'student_number': getattr(student, 'student_number', 'N/A'), 'destination_province': permit.destination_province,
            'destination_address': permit.destination_address, 'departure_date': permit.departure_date.isoformat() if permit.departure_date else None,
            'reason': permit.reason, 'parent_cell_number': permit.parent_cell_number, 'face_url': None, 
        }
        
        if getattr(student, 'face_url', None):
            host = request.get_host(); scheme = request.scheme
            response_data['face_url'] = f"{scheme}://{host}/api/fetch-decrypted-face/{student.id}/"

        if permit.status != 'APPROVED': response_data['message'] = "This permit is not valid for exit."

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
    if err := strict_role_check(request, ['admin', 'attendant']): return err

    permit_id = request.data.get('permit_id')
    live_file = request.FILES.get('live_face')

    if not permit_id or not live_file: return Response({'error': 'Missing permit ID or live face image.'}, status=400)
    if live_file.size > MAX_UPLOAD_SIZE: return Response({'error': 'Face image exceeds the size limit.'}, status=400)

    try:
        permit = LeavePermit.objects.get(id=permit_id)
        student = permit.student
        if not student.face_url: return Response({'error': 'Student has no registered face.'}, status=400)

        temp_live = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
        with open(temp_live, 'wb+') as f:
            for chunk in live_file.chunks(): f.write(chunk)
                
        try:
            result = perform_verification(live_path=temp_live, ref_path=_extract_blob_path(student.face_url), is_encrypted_ref=True)
            if result.get('error'): return Response({'error': 'Verification engine error.'}, status=400)
            if result.get('matched'): return Response({'message': 'Biometric match successful.', 'distance': result.get('score', 0.0)}, status=200)
            else: return Response({'error': 'Biometric mismatch. Identity theft suspected.'}, status=403)
        finally:
            if os.path.exists(temp_live): os.remove(temp_live)

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
        if not student.face_url: return Response({'error': 'No face registered.'}, status=404)
        
        try:
            resp = requests.get(student.face_url)
            if resp.status_code != 200: return Response({'error': 'Encrypted file not found in storage.'}, status=404)
                
            cipher_suite = Fernet(settings.FERNET_KEY)
            decrypted_data = cipher_suite.decrypt(resp.content)
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
# FULLY ISOLATED ROLE-BASED VIEWSETS
# ----------------------------------------------------------------------

class AdminProfileViewSet(BaseSecureViewSet):
    serializer_class = AdminProfileSerializer
    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role == 'admin':
            return AdminProfile.objects.all()
        return AdminProfile.objects.none()
        
    @action(detail=False, methods=['get'], url_path='me')
    def get_current_profile(self, request):
        if err := strict_role_check(request, ['admin']): return err
        serializer = self.get_serializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)

class LandlordProfileViewSet(BaseSecureViewSet):
    serializer_class = LandlordProfileSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['firebase_uid']

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role == 'admin':
            return LandlordProfile.objects.all()
        elif user_role == 'landlord':
            return LandlordProfile.objects.filter(id=self.request.user.id)
        return LandlordProfile.objects.none()

    @action(detail=False, methods=['get'], url_path='me')
    def get_current_profile(self, request):
        if err := strict_role_check(request, ['landlord']): return err
        serializer = self.get_serializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['get'], url_path='decrypted-document')
    def get_decrypted_document(self, request, pk=None):
        if err := strict_role_check(request, ['landlord', 'admin']): return err

        doc_type = request.query_params.get('type')
        if doc_type not in ['contract', 'face', 'id_document']: return Response({'error': 'Invalid document type requested.'}, status=status.HTTP_400_BAD_REQUEST)

        landlord = self.get_object()
        file_url = landlord.contract_url if doc_type == 'contract' else landlord.face_url if doc_type == 'face' else landlord.id_document_url

        if not file_url: return Response({'error': 'Requested secure document path does not exist.'}, status=status.HTTP_404_NOT_FOUND)

        try:
            resp = requests.get(file_url)
            if resp.status_code != 200: return Response({'error': 'Failed to stream asset payload from storage cluster.'}, status=status.HTTP_404_NOT_FOUND)
            
            cipher_suite = Fernet(settings.FERNET_KEY)
            decrypted_data = cipher_suite.decrypt(resp.content)
            
            filename = file_url.split('?')[0].replace('.enc', '')
            mime_type, _ = mimetypes.guess_type(filename)
            if not mime_type: mime_type = 'image/jpeg' if doc_type == 'face' else 'application/pdf' if doc_type == 'contract' else 'application/octet-stream'

            doc_base64 = base64.b64encode(decrypted_data).decode('utf-8')
            return Response({'document_base64': doc_base64, 'mime_type': mime_type}, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"Landlord Secure Decryption Core Failure: {e}", exc_info=True)
            return Response({'error': 'Decryption pipeline aborted due to an internal execution error.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class BlockViewSet(BaseSecureViewSet):
    serializer_class = BlockSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['accommodation__id']

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role == 'admin': return Block.objects.all()
        elif user_role == 'landlord': return Block.objects.filter(accommodation__landlord=self.request.user)
        return Block.objects.none()

class UnitViewSet(BaseSecureViewSet):
    serializer_class = UnitSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['block__id', 'block__accommodation__id']

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role == 'admin': return Unit.objects.all()
        elif user_role == 'landlord': return Unit.objects.filter(block__accommodation__landlord=self.request.user)
        return Unit.objects.none()

class AccommodationViewSet(BaseSecureViewSet):
    serializer_class = AccommodationSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    # NOTE: The previous authentication bypass for GET requests has been removed.
    # Now all requests (including GET) require Firebase authentication.
    # Landlords will only see their own accommodations.

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role == 'admin': return Accommodation.objects.all()
        elif user_role == 'landlord': return Accommodation.objects.filter(landlord=self.request.user)
        return Accommodation.objects.filter(landlord__is_verified=True)

    def _handle_logo_upload(self, instance, request):
        logo_file = request.FILES.get('accommodation_logo')
        if logo_file:
            if logo_file.size > 5 * 1024 * 1024: raise ValidationError({"error": "Logo image exceeds the 5MB limit."})
            try:
                ext = os.path.splitext(logo_file.name)[1]
                filename = f"public_logos/acc_{instance.id}_{uuid.uuid4().hex}{ext}"
                bucket = storage.bucket(); blob = bucket.blob(filename)
                blob.upload_from_file(logo_file.file, content_type=logo_file.content_type)
                blob.make_public()
                instance.accommodation_logo_url = blob.public_url
                instance.save()
            except Exception as e:
                logger.error(f"Failed to upload accommodation logo: {e}", exc_info=True)

    def perform_create(self, serializer):
        if getattr(self.request, 'user_role', None) != 'landlord':
            raise ValidationError({"error": "You're not permitted. Please log in with the correct role."})

        landlord = self.request.user
        business_name = self.request.data.get('business_name')
        bank_code = self.request.data.get('bank_code')
        account_number = self.request.data.get('account_number')
        subaccount_code = None
        
        if bank_code and account_number:
            paystack_payload = {"business_name": business_name or f"{landlord.name} Properties", "settlement_bank": bank_code, "account_number": account_number, "percentage_charge": 0.0, "primary_contact_email": landlord.email}
            headers = {"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}", "Content-Type": "application/json"}
            try:
                paystack_resp = requests.post(getattr(settings, 'PAYSTACK_API_BASE', "https://api.paystack.co") + "/subaccount", json=paystack_payload, headers=headers)
                paystack_data = paystack_resp.json()
                if paystack_resp.status_code in [200, 201] and paystack_data.get('status'):
                    subaccount_code = paystack_data['data']['subaccount_code']
                else: raise ValidationError({"error": f"Payment setup failed: {paystack_data.get('message', 'Invalid bank details.')}"})
            except Exception as e:
                logger.error(f"Paystack Error during accommodation creation: {e}", exc_info=True)
                if isinstance(e, ValidationError): raise e
                raise ValidationError({"error": "Failed to connect to payment gateway."})

        instance = serializer.save(landlord=landlord, seller_paystack_account=subaccount_code)
        self._handle_logo_upload(instance, self.request)

    def perform_update(self, serializer):
        instance = serializer.save()
        self._handle_logo_upload(instance, self.request)
         
class RoomViewSet(BaseSecureViewSet):
    serializer_class = RoomSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['block__accommodation__id', 'room_number', 'block__id', 'unit__id'] 

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role == 'admin': return Room.objects.all()
        elif user_role == 'landlord':
            return Room.objects.filter(Q(block__accommodation__landlord=self.request.user) | Q(unit__block__accommodation__landlord=self.request.user)).distinct()
        return Room.objects.none()

class StudentProfileViewSet(BaseSecureViewSet):
    serializer_class = StudentProfileSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['firebase_uid', 'student_number', 'is_cleared_for_exit', 'landlord__id']

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        qs = StudentProfile.objects.select_related('room__unit__block__accommodation', 'room__block__accommodation', 'applied_accommodation').all()
        if user_role == 'admin': return qs
        elif user_role == 'landlord': return qs.filter(landlord=self.request.user)
        elif user_role == 'student': return qs.filter(id=self.request.user.id)
        return StudentProfile.objects.none()

    def destroy(self, request, *args, **kwargs):
        if getattr(request, 'user_role', None) not in ['admin', 'landlord']:
            return Response({'error': "You're not permitted. Please log in with the correct role."}, status=status.HTTP_403_FORBIDDEN)
        instance = self.get_object()
        try: auth.delete_user(instance.firebase_uid)
        except Exception as e: logger.warning(f"Firebase warning during deletion: {str(e)}")
        self.perform_destroy(instance)
        return Response({"message": "Student and Firebase account permanently deleted."}, status=status.HTTP_200_OK)
    
    @action(detail=False, methods=['get'], url_path='me')
    def get_current_profile(self, request):
        if err := strict_role_check(request, ['student']): return err
        serializer = self.get_serializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)
        
    def perform_update(self, serializer):
        instance = serializer.save()
        face_image = self.request.FILES.get('face_image')
        
        if face_image:
            if face_image.size > MAX_UPLOAD_SIZE: raise ValidationError({"error": "Face image exceeds the 5MB size limit."})
            try:
                file_bytes = face_image.read()
                temp_face = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
                with open(temp_face, 'wb+') as f: f.write(file_bytes)
                
                try:
                    import face_recognition
                    img_data = face_recognition.load_image_file(temp_face)
                    encodings = face_recognition.face_encodings(img_data)
                    if encodings: instance.face_encoding_json = json.dumps(encodings[0].tolist())
                except Exception as e: logger.error(f"Failed to generate face encoding during update: {e}")
                finally:
                    if os.path.exists(temp_face): os.remove(temp_face)

                cipher_suite = Fernet(settings.FERNET_KEY)
                encrypted_bytes = cipher_suite.encrypt(file_bytes)
                ext = os.path.splitext(face_image.name)[1]
                filename = f"secure_faces/{instance.student_number}_{uuid.uuid4().hex}{ext}.enc"
                
                bucket = storage.bucket(); blob = bucket.blob(filename)
                blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                blob.make_public() 
                
                instance.face_url = blob.public_url; instance.save()
            except Exception as e:
                logger.error(f"Firebase Facial Upload Error: {str(e)}", exc_info=True)
                raise ValidationError({"error": "Failed to process and secure the facial biometric data."})
                
    @action(detail=True, methods=['get'], url_path='decrypted-document')
    def get_decrypted_document(self, request, pk=None):
        if getattr(request, 'user_role', None) not in ['admin', 'landlord', 'student']:
            return Response({'error': "You're not permitted. Please log in with the correct role."}, status=status.HTTP_403_FORBIDDEN)

        doc_type = request.query_params.get('type')
        if doc_type not in ['id', 'proof']: return Response({'error': 'Invalid document type requested. Use ?type=id or ?type=proof'}, status=status.HTTP_400_BAD_REQUEST)

        student = self.get_object()
        file_url = student.id_document_url if doc_type == 'id' else student.proof_of_registration_url
        if not file_url: return Response({'error': 'Document does not exist for this applicant.'}, status=status.HTTP_404_NOT_FOUND)

        try:
            resp = requests.get(file_url)
            if resp.status_code != 200: return Response({'error': 'Failed to retrieve encrypted file from storage.'}, status=status.HTTP_404_NOT_FOUND)
            
            cipher_suite = Fernet(settings.FERNET_KEY)
            decrypted_data = cipher_suite.decrypt(resp.content)
            
            filename = file_url.split('?')[0].replace('.enc', '')
            mime_type, _ = mimetypes.guess_type(filename)
            if not mime_type: mime_type = 'application/octet-stream'

            doc_base64 = base64.b64encode(decrypted_data).decode('utf-8')
            return Response({'document_base64': doc_base64, 'mime_type': mime_type}, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"Document Decryption Error: {e}", exc_info=True)
            return Response({'error': 'Decryption failed due to an internal error.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=False, methods=['post'], url_path='update-documents', parser_classes=[MultiPartParser, FormParser])
    def update_documents(self, request):
        if err := strict_role_check(request, ['student']): return err

        student = request.user
        id_document = request.FILES.get('id_document')
        proof_of_registration = request.FILES.get('proof_of_registration')
        
        if id_document and id_document.size > MAX_UPLOAD_SIZE: return Response({"error": "ID Document exceeds 5MB limit."}, status=400)
        if proof_of_registration and proof_of_registration.size > MAX_UPLOAD_SIZE: return Response({"error": "Proof of registration exceeds 5MB limit."}, status=400)
        
        cipher_suite = Fernet(settings.FERNET_KEY)
        bucket = storage.bucket()

        try:
            if id_document:
                file_bytes = id_document.read(); encrypted_bytes = cipher_suite.encrypt(file_bytes)
                ext = os.path.splitext(id_document.name)[1]; filename = f"secure_docs/ID_{student.student_number}_{uuid.uuid4().hex}{ext}.enc"
                blob = bucket.blob(filename); blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                blob.make_public(); student.id_document_url = blob.public_url

            if proof_of_registration:
                file_bytes = proof_of_registration.read(); encrypted_bytes = cipher_suite.encrypt(file_bytes)
                ext = os.path.splitext(proof_of_registration.name)[1]; filename = f"secure_docs/PROOF_{student.student_number}_{uuid.uuid4().hex}{ext}.enc"
                blob = bucket.blob(filename); blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                blob.make_public(); student.proof_of_registration_url = blob.public_url

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
        user_role = getattr(self.request, 'user_role', None)
        qs = AttendantProfile.objects.annotate(average_rating=Avg('assigned_issues__attendant_rating'), resolved_issues_count=Count('assigned_issues', filter=Q(assigned_issues__status='RESOLVED')))
        if user_role == 'admin': return qs
        elif user_role == 'landlord': return qs.filter(landlord=self.request.user)
        elif user_role == 'attendant': return qs.filter(id=self.request.user.id)
        return AttendantProfile.objects.none()

    def destroy(self, request, *args, **kwargs):
        if getattr(request, 'user_role', None) not in ['admin', 'landlord']:
            return Response({'error': "You're not permitted. Please log in with the correct role."}, status=status.HTTP_403_FORBIDDEN)
        instance = self.get_object()
        try: auth.delete_user(instance.firebase_uid)
        except Exception as e: logger.warning(f"Firebase warning during attendant deletion: {str(e)}")
        self.perform_destroy(instance)
        return Response({"message": "Staff member and Firebase account permanently deleted."}, status=status.HTTP_200_OK)
    
class IssueViewSet(BaseSecureViewSet):
    serializer_class = IssueSerializer
    filter_backends = [DjangoFilterBackend] 
    filterset_fields = ['status', 'student__firebase_uid', 'assigned_attendant__firebase_uid', 'is_priority']
    
    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        qs = Issue.objects.select_related('student', 'room__block', 'room__unit', 'assigned_attendant').all()
        if user_role == 'admin': return qs
        elif user_role == 'landlord': return qs.filter(student__landlord=self.request.user)
        elif user_role == 'attendant': return qs.filter(assigned_attendant=self.request.user)
        elif user_role == 'student': return qs.filter(student=self.request.user)
        return Issue.objects.none()

    def perform_update(self, serializer):
        instance = serializer.save()
        if instance.status == 'ATTENDING' and not instance.assigned_attendant:
            if getattr(self.request, 'user_role', None) == 'attendant': 
                instance.assigned_attendant = self.request.user
                instance.save()
                
    def perform_create(self, serializer):
        if getattr(self.request, 'user_role', None) != 'student':
            raise ValidationError({"error": "You're not permitted. Please log in with the correct role."})

        student = self.request.user
        issue = serializer.save(student=student, room=student.room)
             
        if issue.custom_issue_title == "Lost Key":
            Charge.objects.create(student=student, issue=issue, amount=150.00, description="Payment required for: Lost Key", is_paid=False)

class ChargeViewSet(BaseSecureViewSet):
    serializer_class = ChargeSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['is_paid', 'student__firebase_uid']

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        qs = Charge.objects.select_related('student__room__block').all()
        if user_role == 'admin': return qs
        elif user_role == 'landlord': return qs.filter(student__landlord=self.request.user)
        elif user_role == 'student': return qs.filter(student=self.request.user)
        return Charge.objects.none()
 
class LeavePermitViewSet(BaseSecureViewSet):
    serializer_class = LeavePermitSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['status']

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role == 'admin': return LeavePermit.objects.all()
        elif user_role == 'student': return LeavePermit.objects.filter(student=self.request.user)
        elif user_role == 'attendant': return LeavePermit.objects.filter(Q(assigned_attendant=self.request.user) | Q(status='REQUESTED', assigned_attendant__isnull=True))
        elif user_role == 'landlord': return LeavePermit.objects.filter(student__landlord=self.request.user)
        return LeavePermit.objects.none()

    def perform_create(self, serializer):
        if getattr(self.request, 'user_role', None) != 'student':
            raise ValidationError({"error": "You're not permitted. Please log in with the correct role."})
        serializer.save(student=self.request.user)

class RoomInspectionViewSet(BaseSecureViewSet):
    serializer_class = RoomInspectionSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['is_damage_found', 'attendant__firebase_uid', 'permit__student__firebase_uid']

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        qs = RoomInspection.objects.all()
        if user_role == 'admin': return qs
        elif user_role == 'landlord': return qs.filter(permit__student__landlord=self.request.user)
        elif user_role == 'attendant': return qs.filter(attendant=self.request.user)
        elif user_role == 'student': return qs.filter(permit__student=self.request.user)
        return RoomInspection.objects.none()

class GatePassViewSet(BaseSecureViewSet):
    serializer_class = GatePassSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['is_active', 'student__firebase_uid', 'attendant__firebase_uid']

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        qs = GatePass.objects.all()
        if user_role == 'admin': return qs
        elif user_role == 'landlord': return qs.filter(student__landlord=self.request.user)
        elif user_role == 'attendant': return qs.filter(attendant=self.request.user)
        elif user_role == 'student': return qs.filter(student=self.request.user)
        return GatePass.objects.none()

    def perform_create(self, serializer):
        if getattr(self.request, 'user_role', None) != 'student':
            raise ValidationError({"error": "You're not permitted. Please log in with the correct role."})
        serializer.save(student=self.request.user)

class NotificationViewSet(BaseSecureViewSet):
    serializer_class = NotificationSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['is_read']

    def get_queryset(self):
        user = self.request.user
        if isinstance(user, StudentProfile): return Notification.objects.filter(student=user).order_by('-created_at')
        elif isinstance(user, AttendantProfile): return Notification.objects.filter(attendant=user).order_by('-created_at')
        elif isinstance(user, LandlordProfile): return Notification.objects.filter(landlord=user).order_by('-created_at')
        elif isinstance(user, AdminProfile): return Notification.objects.filter(admin=user).order_by('-created_at')
        elif isinstance(user, MedicalResponderProfile): return Notification.objects.filter(responder=user).order_by('-created_at')
        return Notification.objects.none()

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        notification = self.get_object()
        if not notification.is_read:
            notification.is_read = True; notification.save()
        return Response({'status': 'Notification marked as read'})

# ----------------------------------------------------------------------
# FUNCTION VIEWS & CUSTOM APIs
# ----------------------------------------------------------------------

class LandlordDashboardStatsView(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        if err := strict_role_check(request, ['landlord']): return err
        landlord = request.user
        accommodations_count = Accommodation.objects.filter(landlord=landlord).count()
        return Response({"total_accommodations": accommodations_count, "professional_name": f"{landlord.name} {landlord.surname}"})

class GlobalSearchView(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        if err := strict_role_check(request, ['landlord']): return err
        
        query = request.query_params.get('q', '').strip()
        landlord = request.user  
        if not query or len(query) < 2: return Response({"results": []})

        results = []
        students = StudentProfile.objects.filter(landlord=landlord).filter(Q(name__icontains=query) | Q(surname__icontains=query) | Q(student_number__icontains=query))[:5] 
        for s in students: results.append({"type": "student", "title": f"{s.name} {s.surname}", "subtitle": f"SN: {s.student_number}", "id": str(s.id), "link": f"/landlord/students/{s.id}"})

        rooms = Room.objects.filter(block__accommodation__landlord=landlord).filter(Q(room_number__icontains=query))[:5]
        for r in rooms: results.append({"type": "room", "title": f"Room {r.room_number}", "subtitle": r.block.accommodation.name if r.block else "Unassigned", "id": str(r.id), "link": f"/landlord/accommodations/rooms/{r.id}"})
        return Response({"results": results})

class RegisterLandlordView(APIView):
    permission_classes = [permissions.AllowAny]
    def post(self, request):
        firebase_uid = request.data.get('firebase_uid')
        email = request.data.get('email')
        name = request.data.get('name')
        surname = request.data.get('surname')
        phone = request.data.get('phone')
        
        bank_code = request.data.get('bank_code')
        account_number = request.data.get('account_number')
        business_name = request.data.get('business_name')

        if not all([firebase_uid, email, name, surname, bank_code, account_number, business_name]):
            try:
                if firebase_uid: auth.delete_user(firebase_uid)
            except Exception: pass
            return Response({"error": "Missing required profile or banking details. Firebase account purged to prevent a ghost user."}, status=status.HTTP_400_BAD_REQUEST)

        if LandlordProfile.objects.filter(firebase_uid=firebase_uid).exists():
            return Response({"error": "A landlord with this account already exists."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            with transaction.atomic(): 
                user, created = User.objects.get_or_create(username=firebase_uid, defaults={'email': email})
                
                paystack_payload = {"business_name": business_name, "settlement_bank": bank_code, "account_number": account_number, "percentage_charge": 0.0, "primary_contact_email": email}
                headers = {"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}", "Content-Type": "application/json"}
                
                paystack_url = getattr(settings, 'PAYSTACK_API_BASE', "https://api.paystack.co") + "/subaccount"
                paystack_resp = requests.post(paystack_url, json=paystack_payload, headers=headers)
                paystack_data = paystack_resp.json()
                
                if paystack_resp.status_code not in [200, 201] or not paystack_data.get('status'):
                    raise ValueError(f"Paystack account creation failed: {paystack_data.get('message', 'Invalid bank details.')}")
                    
                subaccount_code = paystack_data['data']['subaccount_code']

                landlord = LandlordProfile.objects.create(
                    firebase_uid=firebase_uid, email=email, name=name, surname=surname, phone=phone,
                    paystack_merchant_code=subaccount_code, seller_paystack_account=subaccount_code,
                    is_verified=False, digital_verification_status=False, manual_verification_status=False
                )
                
                msg = f"""
                <h2 style="color: #0f172a;">Landlord Account Created</h2>
                <p>Dear {name},</p>
                <p>Welcome to the platform! Your landlord account and Merchant payout account (<strong>{subaccount_code}</strong>) have been successfully generated.</p>
                <p>To complete your registration and activate your dashboard, please log into the mobile app and complete your biometric verification process.</p>
                """
                send_html_email_async(email, "Welcome! Registration & Payout Account Successful", msg)
                return Response({"message": "Landlord account created successfully.", "firebase_uid": landlord.firebase_uid, "subaccount_code": subaccount_code}, status=status.HTTP_201_CREATED)
                
        except Exception as e:
            try: auth.delete_user(firebase_uid)
            except Exception as fb_err: logger.error(f"Failed to cleanly delete ghost Firebase user {firebase_uid}: {fb_err}")
            logger.error(f"Landlord Registration Error: {e}", exc_info=True)
            error_message = str(e) if isinstance(e, ValueError) else "Database or Payment gateway error occurred during registration."
            return Response({"error": error_message}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([AllowAny]) 
def login_user(request):
    id_token = request.data.get('id_token')
    if not id_token: return Response({"error": "No id_token provided."}, status=400)
        
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
@permission_classes([IsAuthenticated]) 
def add_attendant_by_landlord(request):
    if err := strict_role_check(request, ['landlord']): return err

    id_number = request.data.get('id_number')
    name = request.data.get('name')
    email = request.data.get('email')
    surname = request.data.get('surname')
    phone = request.data.get('phone', '')
    face_url = request.data.get('face_url', '')  
    role = request.data.get('role', 'ATTENDANT') 

    if not all([id_number, name, email, surname]): return Response({"error": "Missing fields."}, status=400)

    password = id_number[:6]
    landlord = request.user  
    
    try: 
        firebase_user = auth.create_user(email=email, password=password, display_name=f"{name} {surname}")
        try:
            with transaction.atomic():
                attendant = AttendantProfile.objects.create(landlord=landlord, firebase_uid=firebase_user.uid, name=name, surname=surname, email=email, phone=phone, face_url=face_url, role=role)
                
            msg = f"""
            <h2 style="color: #0f172a;">Welcome to the Team, {name}!</h2>
            <p>You have been officially added to the system as a <strong>{role}</strong>.</p>
            <div style="background-color: #f1f5f9; padding: 15px; border-radius: 8px; margin: 15px 0;">
                <p style="margin: 0;"><strong>Email:</strong> {email}</p>
                <p style="margin: 5px 0 0 0;"><strong>Password:</strong> {password}</p>
            </div>
            <p>Please log in to the mobile application using these credentials.</p>
            """
            send_html_email_async(email, "You've been added to the Staff Portal", msg)
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
@permission_classes([IsAuthenticated])
def send_communication(request):
    if err := strict_role_check(request, ['landlord']): return err

    title = request.data.get('title')
    message = request.data.get('message')
    send_mode = request.data.get('send_mode', 'broadcast') 
    target_audience = request.data.get('target_audience', 'all') 
    recipient_ids = request.data.get('recipient_ids', []) 
    landlord = request.user

    if not title or not message: return Response({"error": "Title and message are required."}, status=status.HTTP_400_BAD_REQUEST)

    notifications_to_create = []; fcm_tokens = []; recipient_emails = set()

    with transaction.atomic():
        if send_mode == 'broadcast':
            students = StudentProfile.objects.filter(landlord=landlord)
            attendants = AttendantProfile.objects.filter(landlord=landlord)

            if target_audience in ['all', 'students']:
                for s in students:
                    notifications_to_create.append(Notification(student=s, title=title, message=message, target_audience=target_audience))
                    if s.email: recipient_emails.add(s.email)
            
            if target_audience in ['all', 'attendants', 'security', 'room_attendants', 'general_staff']:
                query = attendants
                if target_audience == 'security': query = query.filter(role='SECURITY')
                elif target_audience == 'room_attendants': query = query.filter(role='ATTENDANT')
                elif target_audience == 'general_staff': query = query.filter(role='GENERAL')
                for a in query:
                    notifications_to_create.append(Notification(attendant=a, title=title, message=message, target_audience=target_audience))
                    if a.email: recipient_emails.add(a.email)

            fcm_payload = messaging.Message(
                notification=messaging.Notification(title=title, body=message),
                topic=target_audience,
                android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(sound='default')),
                apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(sound='default', badge=1)))
            )
            response = messaging.send(fcm_payload)
            print(f"🔥 FIREBASE BROADCAST RESPONSE: Successfully dispatched message ID: {response}")

        else:
            if not recipient_ids: return Response({"error": "No recipients selected."}, status=400)
            target_audience = 'personal'
            
            selected_students = StudentProfile.objects.filter(firebase_uid__in=recipient_ids, landlord=landlord)
            for s in selected_students:
                notifications_to_create.append(Notification(student=s, title=title, message=message, target_audience=target_audience))
                if s.fcm_token: fcm_tokens.append(s.fcm_token)
                if s.email: recipient_emails.add(s.email)
            
            selected_attendants = AttendantProfile.objects.filter(firebase_uid__in=recipient_ids, landlord=landlord)
            for a in selected_attendants:
                notifications_to_create.append(Notification(attendant=a, title=title, message=message, target_audience=target_audience))
                if a.fcm_token: fcm_tokens.append(a.fcm_token)
                if a.email: recipient_emails.add(a.email)
            
            if fcm_tokens:
                multicast_msg = messaging.MulticastMessage(
                    notification=messaging.Notification(title=title, body=message), tokens=fcm_tokens,
                    android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(sound='default')),
                    apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(sound='default', badge=1)))
                )
                messaging.send_each_for_multicast(multicast_msg)

        if not notifications_to_create: return Response({"error": "No recipients found."}, status=404)
        notifications_to_create.append(Notification(landlord=landlord, title=title, message=message, target_audience=target_audience, is_read=True))
        Notification.objects.bulk_create(notifications_to_create)

    if recipient_emails:
        email_html_content = f"""
        <h2 style="color: #0f172a; border-bottom: 2px solid #e2e8f0; padding-bottom: 10px; margin-bottom: 20px;">{title}</h2>
        <p style="color: #475569; font-size: 16px;">You have received a new communication from your property management:</p>
        <div style="background-color: #f8fafc; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #3b82f6;">
            <p style="margin: 0; white-space: pre-wrap; color: #1e293b; font-size: 15px; line-height: 1.6;">{message}</p>
        </div>
        <p style="color: #64748b; font-size: 14px; margin-top: 20px;">Please log in to the Memberssistant application to review your dashboard or take any necessary action.</p>
        """
        for email in recipient_emails: send_html_email_async(email, title, email_html_content)

    return Response({"message": "Dispatched successfully."}, status=201)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
def update_fcm_token(request):
    token = request.data.get('fcm_token')
    if not token: return Response({"error": "Token required"}, status=400)

    uid = getattr(request.user, 'firebase_uid', None) or getattr(request.user, 'username', None)
    if not uid: return Response({"error": "User identification failed."}, status=400)

    profile_updated = False
    for Model in [StudentProfile, AttendantProfile, LandlordProfile, MedicalResponderProfile, AdminProfile]:
        profile = Model.objects.filter(firebase_uid=uid).first()
        if profile:
            profile.fcm_token = token; profile.save(update_fields=['fcm_token'])
            profile_updated = True; break

    if not profile_updated:
        try: user = request.user; user.fcm_token = token; user.save()
        except Exception: pass

    return Response({"message": "Token synced successfully."})

@api_view(['POST']) 
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
def create_seller_subaccount(request):
    if err := strict_role_check(request, ['landlord']): return err

    uid = request.user.firebase_uid 
    business_name = request.data.get('business_name')
    bank_code = request.data.get('bank_code')
    account_number = request.data.get('account_number')
    contact_email = request.data.get('email')

    if not all([business_name, bank_code, account_number, contact_email]): return Response({'error': 'Missing required fields'}, status=400)

    try: user = LandlordProfile.objects.get(firebase_uid=uid)
    except LandlordProfile.DoesNotExist: return Response({'error': "User not found"}, status=404)
 
    payload = {"business_name": business_name, "settlement_bank": bank_code, "account_number": account_number, "percentage_charge": 0.0, "primary_contact_email": contact_email}
    headers = {"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}", "Content-Type": "application/json"}

    try:
        resp = requests.post(f"{settings.PAYSTACK_API_BASE}/subaccount", json=payload, headers=headers)
        data = resp.json()
        
        if resp.status_code in [200, 201] and data.get('status') is True:
            sub_code = data['data']['subaccount_code']; user.seller_paystack_account = sub_code; user.save()
            msg = f"""
            <h2 style="color: #0f172a;">Merchant Account Verified</h2>
            <p>Your Paystack subaccount (<strong>{sub_code}</strong>) has been successfully generated and securely linked to your profile.</p>
            <p>You are now ready to receive payments from your residents through the Memberssistant app.</p>
            """
            send_html_email_async(contact_email, "Merchant Account Linked Successfully", msg)
            return Response({'success': True, 'subaccount_code': sub_code})
        else: return Response({'error': data.get('message')}, status=400)
    except Exception as e:
        logger.error(f"Paystack Subaccount Error: {e}", exc_info=True)
        return Response({'error': "Failed to communicate with payment gateway."}, status=500)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated])
def create_payment_link(request):
    if err := strict_role_check(request, ['student']): return err

    try:
        student = StudentProfile.objects.get(firebase_uid=request.user.firebase_uid)
        issue_id = request.data.get('issue_id')
        if not issue_id: return Response({'error': 'Issue ID is required'}, status=400)

        try:
            issue = Issue.objects.select_related('room__block__accommodation', 'room__unit__block__accommodation').get(id=issue_id, student=student)
            charge = Charge.objects.get(issue=issue, is_paid=False)
        except (Issue.DoesNotExist, Charge.DoesNotExist):
            return Response({'error': 'Valid pending charge not found.'}, status=404)

        accommodation = None
        if issue.room:
            if hasattr(issue.room, 'unit') and issue.room.unit and issue.room.unit.block: accommodation = issue.room.unit.block.accommodation
            elif issue.room.block: accommodation = issue.room.block.accommodation

        if not accommodation or not accommodation.seller_paystack_account: return Response({'error': 'Payment cannot be processed. Payout account for this specific accommodation is not configured.'}, status=400)

        amount_cents = int(charge.amount * 100); order_ref = f"KEY_{issue.id}_{uuid.uuid4().hex[:8].upper()}"
        body = {"email": student.email, "amount": amount_cents, "currency": "ZAR", "reference": order_ref, "channels": ['card', 'eft', 'mobile_money'], "subaccount": accommodation.seller_paystack_account, "bearer": "subaccount"}
        headers = {"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}", "Content-Type": "application/json"}
        resp = requests.post("https://api.paystack.co/transaction/initialize", json=body, headers=headers)
        
        if resp.status_code != 200: return Response({'error': "Payment gateway initialization failed."}, status=400)
        data = resp.json()
        if not data.get('status'): return Response({'error': data.get('message')}, status=400)
        return Response({'paymentLink': data['data']['authorization_url'], 'reference': order_ref}, status=200)

    except StudentProfile.DoesNotExist: return Response({'error': 'Student profile not found'}, status=403)
    except Exception as e:
        logger.error(f"Payment Link Error: {e}", exc_info=True)
        return Response({'error': "Internal server error during payment initialization."}, status=500)

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny]) 
def paystack_webhook(request):
    paystack_signature = request.headers.get('x-paystack-signature')
    if not paystack_signature: return Response({'status': 'missing signature'}, status=400)

    secret = settings.PAYSTACK_SECRET_KEY.encode('utf-8'); body = request.body
    hash_calc = hmac.new(secret, body, hashlib.sha512).hexdigest()

    if hash_calc != paystack_signature: return Response({'status': 'invalid signature'}, status=400)

    try:
        event_data = json.loads(body)
        if event_data.get('event') == 'charge.success':
            reference = event_data['data']['reference']; verified_amount = event_data['data']['amount'] 
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
                                    issue.status = 'READY_FOR_COLLECTION'; issue.save(); charge.is_paid = True; charge.save()
                                    receipt_msg = f"""
                                    <h2 style="color: #0f172a;">Payment Receipt</h2>
                                    <p>Dear {issue.student.name},</p>
                                    <p>Your payment has been successfully processed and verified.</p>
                                    <table style="width: 100%; border-collapse: collapse; margin-top: 15px;">
                                        <tr style="border-bottom: 1px solid #e2e8f0;"><td style="padding: 10px 0;"><strong>Issue ID:</strong></td><td style="padding: 10px 0; text-align: right;">#{issue.id}</td></tr>
                                        <tr style="border-bottom: 1px solid #e2e8f0;"><td style="padding: 10px 0;"><strong>Description:</strong></td><td style="padding: 10px 0; text-align: right;">{issue.custom_issue_title}</td></tr>
                                        <tr><td style="padding: 10px 0;"><strong>Amount Paid:</strong></td><td style="padding: 10px 0; text-align: right;">R{charge.amount}</td></tr>
                                    </table>
                                    <p style="margin-top: 20px;">Reference: <code>{reference}</code></p>
                                    <p>Thank you for using the Memberssistant platform.</p>
                                    """
                                    send_html_email_async(issue.student.email, "Payment Successfully Processed", receipt_msg)
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
@permission_classes([IsAuthenticated]) 
def verify_gate_pass_qr(request):
    if err := strict_role_check(request, ['attendant', 'admin']): return err

    qr_reference = request.data.get('qr_reference')
    if not qr_reference: return Response({'error': 'No QR reference provided.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        gate_pass = GatePass.objects.get(id=qr_reference)
        student = gate_pass.student
        is_expired = timezone.now() > gate_pass.expires_at or not gate_pass.is_active
        
        response_data = {
            'id': str(gate_pass.id), 'status': 'EXPIRED' if is_expired else 'ACTIVE',
            'student_name': f"{student.name} {student.surname}", 'student_number': getattr(student, 'student_number', 'N/A'),
            'asset_name': gate_pass.asset_name, 'asset_number': gate_pass.asset_number, 'expires_at': gate_pass.expires_at.isoformat()
        }
        return Response(response_data, status=status.HTTP_200_OK)

    except GatePass.DoesNotExist:
        return Response({'error': 'INVALID OR FAKE QR CODE DETECTED.'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Gate Pass Verification Error: {e}", exc_info=True)
        return Response({'error': 'An internal server error occurred.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
     

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication]) 
@permission_classes([IsAuthenticated]) 
@parser_classes([MultiPartParser, FormParser]) 
def add_student_by_landlord(request):
    if err := strict_role_check(request, ['landlord']): return err

    student_number = str(request.data.get('student_number', '')).strip()
    id_number = request.data.get('id_number')
    name = request.data.get('name')
    surname = request.data.get('surname')
    phone = request.data.get('phone', '')
    room_id = request.data.get('room_id')
    face_image = request.FILES.get('face_image') 

    if not all([student_number, id_number, name, surname]): return Response({"error": "Required fields missing."}, status=400)
    if len(id_number) < 6: return Response({"error": "Invalid ID."}, status=400)
    if face_image and face_image.size > MAX_UPLOAD_SIZE: return Response({"error": "Face image exceeds 5MB limit."}, status=400)

    if len(student_number) == 9: email = f"{student_number}@edu.vut.ac.za"
    else:
        email = request.data.get('email')
        if not email: return Response({"error": "An email address is strictly required because the student number is not 9 digits long."}, status=400)

    password = id_number[:6] 
    landlord = request.user 

    try: 
        firebase_user = auth.create_user(email=email, password=password, display_name=f"{name} {surname}")
        
        try:
            with transaction.atomic():
                room = None
                if room_id:
                    try: room = Room.objects.get(id=room_id)
                    except Room.DoesNotExist: raise ValueError("Invalid Room ID provided. Room does not exist.") 

                face_url = None; face_encoding_string = "" 
                
                if face_image:
                    file_bytes = face_image.read()
                    temp_face = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
                    with open(temp_face, 'wb+') as f: f.write(file_bytes)
                    
                    try:
                        import face_recognition
                        img_data = face_recognition.load_image_file(temp_face)
                        encodings = face_recognition.face_encodings(img_data)
                        if encodings: face_encoding_string = json.dumps(encodings[0].tolist())
                    except Exception as e: logger.error(f"Failed to generate face encoding: {e}")
                    finally: os.remove(temp_face)

                    cipher_suite = Fernet(settings.FERNET_KEY)
                    encrypted_bytes = cipher_suite.encrypt(file_bytes)

                    ext = os.path.splitext(face_image.name)[1]
                    filename = f"secure_faces/{student_number}_{uuid.uuid4().hex}{ext}.enc"
                    
                    bucket = storage.bucket(); blob = bucket.blob(filename)
                    blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                    blob.make_public(); face_url = blob.public_url 

                student = StudentProfile.objects.create(
                    landlord=landlord, firebase_uid=firebase_user.uid, name=name, surname=surname,
                    email=email, student_number=student_number, id_number=id_number, phone=phone,
                    room=room, face_url=face_url, requires_password_change=True, verification_status=False, face_encoding_json=face_encoding_string
                )

                msg = f"""
                <h2 style="color: #0f172a;">Welcome to the Platform, {name}!</h2>
                <p>You have been successfully registered to your accommodation profile by your landlord.</p>
                <div style="background-color: #f1f5f9; padding: 15px; border-radius: 8px; margin: 15px 0;">
                    <p style="margin: 0;"><strong>Email / Student Email:</strong> {email}</p>
                    <p style="margin: 5px 0 0 0;"><strong>Temporary Password:</strong> {password}</p>
                </div>
                <p>Please log in to the mobile application. You will be required to securely update your password and verify your biometrics upon your first login.</p>
                """
                send_html_email_async(email, "Welcome to your New Accommodation", msg)
                return Response({"message": "Student successfully registered and face encrypted.", "student_id": student.id}, status=201)
                
        except ValueError as ve:
            auth.delete_user(firebase_user.uid)
            return Response({"error": str(ve)}, status=400)
        except Exception as e:
            auth.delete_user(firebase_user.uid)
            logger.error(f"Student Registration DB/Storage Error: {e}", exc_info=True)
            return Response({"error": "Failed to complete student registration."}, status=500)

    except auth.EmailAlreadyExistsError: return Response({"error": "Student exists."}, status=400)
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

    if not all([student_number, name, surname, password]): return Response({"error": "Required text fields missing."}, status=400)
    if id_document and id_document.size > MAX_UPLOAD_SIZE: return Response({"error": "ID Document exceeds 5MB limit."}, status=400)
    if proof_of_registration and proof_of_registration.size > MAX_UPLOAD_SIZE: return Response({"error": "Proof of registration exceeds 5MB limit."}, status=400)

    if len(student_number) == 9: email = f"{student_number}@edu.vut.ac.za"
    else:
        email = request.data.get('email')
        if not email: return Response({"error": "An email address is strictly required because your student number is not 9 digits long."}, status=400)

    try: 
        firebase_user = auth.create_user(email=email, password=password, display_name=f"{name} {surname}")
        try:
            with transaction.atomic():
                id_doc_url = None; proof_doc_url = None
                cipher_suite = Fernet(settings.FERNET_KEY)
                bucket = storage.bucket()

                if id_document:
                    file_bytes = id_document.read(); encrypted_bytes = cipher_suite.encrypt(file_bytes)
                    ext = os.path.splitext(id_document.name)[1]
                    filename = f"secure_docs/ID_{student_number}_{uuid.uuid4().hex}{ext}.enc"
                    blob = bucket.blob(filename); blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                    blob.make_public(); id_doc_url = blob.public_url 

                if proof_of_registration:
                    file_bytes = proof_of_registration.read(); encrypted_bytes = cipher_suite.encrypt(file_bytes)
                    ext = os.path.splitext(proof_of_registration.name)[1]
                    filename = f"secure_docs/PROOF_{student_number}_{uuid.uuid4().hex}{ext}.enc"
                    blob = bucket.blob(filename); blob.upload_from_string(encrypted_bytes, content_type='application/octet-stream')
                    blob.make_public(); proof_doc_url = blob.public_url 

                student = StudentProfile.objects.create(
                    firebase_uid=firebase_user.uid, name=name, surname=surname, email=email, student_number=student_number, 
                    id_document_url=id_doc_url, proof_of_registration_url=proof_doc_url, requires_password_change=False, verification_status=False 
                )

                msg = f"""
                <h2 style="color: #0f172a;">Registration Successful</h2>
                <p>Dear {name},</p>
                <p>Welcome to the Memberssistant Platform! Your student profile has been successfully created.</p>
                <p>Your identity documents and proof of registration have been securely uploaded to our encrypted vault. You may now log in to the app to apply for accommodation and manage your residence profile.</p>
                """
                send_html_email_async(email, "Welcome to the Memberssistant Platform", msg)
                return Response({"message": "Student successfully registered."}, status=201)
                
        except Exception as e:
            auth.delete_user(firebase_user.uid)
            logger.error(f"Student Self-Reg DB/Storage Error: {e}", exc_info=True)
            return Response({"error": "Registration failed during document security processing."}, status=500)

    except auth.EmailAlreadyExistsError: return Response({"error": "A student with this number/email already exists."}, status=400)
    except Exception as e:
        logger.error(f"Student Self-Reg Auth Error: {e}", exc_info=True)
        return Response({"error": "Authentication provider error."}, status=500)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@authentication_classes([FirebaseAuthentication])
@parser_classes([MultiPartParser, FormParser])
def verify_student_presence(request, student_id):
    if err := strict_role_check(request, ['attendant', 'admin']): return err

    live_file = request.FILES.get('live_face')
    if not live_file: return Response({'error': 'Missing live face image.'}, status=400)
    if live_file.size > MAX_UPLOAD_SIZE: return Response({'error': 'Face image exceeds 5MB limit.'}, status=400)

    try:
        student = StudentProfile.objects.get(id=student_id)
        if not student.face_url: return Response({'error': 'Student has no registered face.'}, status=400)

        temp_live = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg").name
        with open(temp_live, 'wb+') as f:
            for chunk in live_file.chunks(): f.write(chunk)
                
        try:
            result = perform_verification(live_path=temp_live, ref_path=_extract_blob_path(student.face_url), is_encrypted_ref=True)
            if result.get('error'): return Response({'error': 'Verification engine processing error.'}, status=400)
            if result.get('matched'):
                student.verification_status = True; student.save()
                return Response({'message': 'Biometric match successful. Student verified.', 'distance': result.get('score', 0.0)}, status=200)
            else: return Response({'error': 'Biometric mismatch. Verification failed.'}, status=403)
        finally:
            if os.path.exists(temp_live): os.remove(temp_live)

    except StudentProfile.DoesNotExist: return Response({'error': 'Student not found.'}, status=404)
    except Exception as e:
        logger.error(f"Student Presence Verification Error: {e}", exc_info=True)
        return Response({'error': 'An internal server error occurred.'}, status=500)


class ApplyAccommodationView(APIView):
    authentication_classes = [FirebaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if err := strict_role_check(request, ['student']): return err
        try: student = StudentProfile.objects.get(firebase_uid=request.user.firebase_uid)
        except StudentProfile.DoesNotExist: return Response({"error": "Access denied."}, status=status.HTTP_403_FORBIDDEN)

        if not student.applied_accommodation: return Response([], status=status.HTTP_200_OK)

        application_data = {"id": str(student.applied_accommodation.id), "accommodation_name": student.applied_accommodation.name, "status": "Pending", "created_at": student.updated_at.isoformat()}
        return Response([application_data], status=status.HTTP_200_OK)

    def post(self, request):
        if err := strict_role_check(request, ['student']): return err

        accommodation_id = request.data.get('accommodation_id')
        if not accommodation_id: return Response({"error": "Accommodation identification field is required."}, status=status.HTTP_400_BAD_REQUEST)

        try: accommodation = Accommodation.objects.get(id=accommodation_id)
        except Accommodation.DoesNotExist: return Response({"error": "Target accommodation entity could not be found."}, status=status.HTTP_404_NOT_FOUND)

        try: student = StudentProfile.objects.get(firebase_uid=request.user.firebase_uid)
        except StudentProfile.DoesNotExist: return Response({"error": "Access denied."}, status=status.HTTP_403_FORBIDDEN)

        if not student.id_document_url or not student.proof_of_registration_url:
            return Response({"error": "Application rejected. Critical documentation is missing."}, status=status.HTTP_400_BAD_REQUEST)

        student.landlord = accommodation.landlord; student.applied_accommodation = accommodation; student.save()
        Notification.objects.create(landlord=accommodation.landlord, title="New Application Received", message=f"Student {student.name} {student.surname} applied for enrollment at {accommodation.name}.", target_audience="personal")

        msg_student = f"""
        <h2 style="color: #0f172a;">Application Submitted</h2>
        <p>Dear {student.name},</p>
        <p>Your application for <strong>{accommodation.name}</strong> has been successfully submitted to the property management.</p>
        <p>You will be notified once your application is reviewed and approved.</p>
        """
        send_html_email_async(student.email, "Accommodation Application Submitted", msg_student)
        
        if accommodation.landlord and accommodation.landlord.email:
            msg_landlord = f"""
            <h2 style="color: #0f172a;">New Student Application</h2>
            <p>Dear {accommodation.landlord.name},</p>
            <p>You have received a new accommodation application from <strong>{student.name} {student.surname}</strong> (Student No: {student.student_number}).</p>
            <p>Please log in to your dashboard to securely review their documents and manage the application.</p>
            """
            send_html_email_async(accommodation.landlord.email, "New Accommodation Application Received", msg_landlord)

        return Response({"message": "Application processed successfully."}, status=status.HTTP_201_CREATED)
    
@api_view(['GET'])
@permission_classes([AllowAny]) 
def serve_decrypted_file_by_url(request):
    token = request.query_params.get('token')
    file_url = request.query_params.get('file_url')
    
    if not token or not file_url: return HttpResponse("Unauthorized: Missing token or file_url", status=401)
        
    try:
        auth.verify_id_token(token)
        decoded_file_url = urllib.parse.unquote(file_url)
        resp = requests.get(decoded_file_url)
        if resp.status_code != 200: return HttpResponse("Encrypted file not found in storage.", status=404)
            
        cipher_suite = Fernet(settings.FERNET_KEY)
        decrypted_data = cipher_suite.decrypt(resp.content)
        return HttpResponse(decrypted_data, content_type="image/jpeg")
        
    except auth.InvalidIdTokenError: return HttpResponse("Unauthorized: Invalid token", status=401)
    except Exception as e:
        logger.error(f"Universal Image Decryption Error: {e}", exc_info=True)
        return HttpResponse("Internal Server Error", status=500)


class VisitorRegisterViewSet(BaseSecureViewSet):
    serializer_class = VisitorRegisterSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['status']

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role == 'admin': return VisitorRegister.objects.all().order_by('-created_at')
        elif user_role == 'attendant': return VisitorRegister.objects.filter(student__landlord=self.request.user.landlord).order_by('-created_at')
        elif user_role == 'landlord': return VisitorRegister.objects.filter(student__landlord=self.request.user).order_by('-created_at')
        elif user_role == 'student': return VisitorRegister.objects.filter(student=self.request.user).order_by('-created_at')
        return VisitorRegister.objects.none()

    def perform_create(self, serializer):
        if getattr(self.request, 'user_role', None) != 'student':
            raise ValidationError({"error": "You're not permitted. Please log in with the correct role."})

        student = self.request.user
        has_active_visitor = VisitorRegister.objects.filter(student=student, status__in=['PENDING', 'SIGNED_IN']).exists()
        if has_active_visitor: raise ValidationError({"error": "You currently have an active visitor. They must sign out before you can register another."})
            
        serializer.save(student=student)

@api_view(['POST'])
@authentication_classes([FirebaseAuthentication])
@permission_classes([IsAuthenticated]) 
def scan_visitor_qr(request):
    if err := strict_role_check(request, ['attendant', 'admin']): return err

    qr_reference = request.data.get('qr_reference')
    action = request.data.get('action')

    if not qr_reference or not action: return Response({'error': 'QR reference and specific action are strictly required.'}, status=400)

    try:
        visitor = VisitorRegister.objects.select_related('student__room__block').get(qr_reference=qr_reference)
        current_time = timezone.now()
        
        try: security_officer = AttendantProfile.objects.get(firebase_uid=request.user.firebase_uid)
        except AttendantProfile.DoesNotExist: return Response({'error': 'Unauthorized. Only security personnel can perform this action.'}, status=403)

        if action == 'SIGN_IN':
            if visitor.status != 'PENDING': return Response({'error': f'Cannot sign in. Visitor is currently: {visitor.status}'}, status=400)
            visitor.time_in = current_time; visitor.status = 'SIGNED_IN'
            message = "Sign In Successful. Retain ID Card."
            VisitorAuditLog.objects.create(visitor_record=visitor, security_officer=security_officer, student=visitor.student, action_taken='SIGNED_IN')

        elif action == 'SIGN_OUT':
            if visitor.status == 'PENDING': return Response({'error': 'Cannot sign out. Visitor has never signed in.'}, status=400)
            if visitor.status == 'SIGNED_OUT': return Response({'error': 'Visitor has already been signed out.'}, status=400)
            visitor.time_out = current_time; visitor.status = 'SIGNED_OUT'
            message = "Sign Out Successful. Return ID Card."
            VisitorAuditLog.objects.create(visitor_record=visitor, security_officer=security_officer, student=visitor.student, action_taken='SIGNED_OUT')
            
        elif action == 'VERIFY': message = "Visitor Details Verified."
        else: return Response({'error': 'Invalid action requested.'}, status=400)

        visitor.save()
        serializer = VisitorRegisterSerializer(visitor)
        return Response({'message': message, 'visitor': serializer.data}, status=200)

    except VisitorRegister.DoesNotExist: return Response({'error': 'INVALID OR UNRECOGNIZED QR CODE.'}, status=404)
    except Exception as e:
        logger.error(f"Visitor Scan Error: {e}", exc_info=True)
        return Response({'error': 'An internal server error occurred.'}, status=500)


class VisitorAuditLogViewSet(BaseSecureViewSet):
    serializer_class = VisitorAuditLogSerializer

    def get_queryset(self):
        user_role = getattr(self.request, 'user_role', None)
        if user_role == 'admin': return VisitorAuditLog.objects.all().order_by('-created_at')
        elif user_role == 'landlord': return VisitorAuditLog.objects.filter(student__landlord=self.request.user).order_by('-created_at')
        elif user_role == 'attendant': return VisitorAuditLog.objects.filter(security_officer=self.request.user).order_by('-created_at')
        return VisitorAuditLog.objects.none()
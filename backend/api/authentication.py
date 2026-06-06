from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from firebase_admin import auth
from django.core.cache import cache
from .models import StudentProfile, AttendantProfile, LandlordProfile, AdminProfile, MedicalResponderProfile

class FirebaseAuthentication(BaseAuthentication):
    def authenticate(self, request):
        auth_header = request.META.get('HTTP_AUTHORIZATION')
        if not auth_header or not auth_header.startswith('Bearer '):
            return None 

        id_token = auth_header.split(' ').pop()

        try:
            decoded_token = auth.verify_id_token(id_token)
            uid = decoded_token.get('uid')
        except Exception:
            raise AuthenticationFailed('Invalid or expired Firebase token.')

        cache_key = f"auth_user_{uid}"
        cached_user_data = cache.get(cache_key)

        if cached_user_data:
            role = cached_user_data['role']
            user_id = cached_user_data['id']
            request.user_role = role
            
            if role == 'admin':
                return (AdminProfile.objects.get(id=user_id), decoded_token)
            elif role == 'landlord':
                return (LandlordProfile.objects.get(id=user_id), decoded_token)
            elif role == 'student':
                return (StudentProfile.objects.get(id=user_id), decoded_token)
            elif role == 'attendant':
                return (AttendantProfile.objects.get(id=user_id), decoded_token)
            elif role == 'responder':
                return (MedicalResponderProfile.objects.get(id=user_id), decoded_token)

        # 1. Admin
        admin_user = AdminProfile.objects.filter(firebase_uid=uid).first()
        if admin_user:
            request.user_role = 'admin'
            cache.set(cache_key, {'role': 'admin', 'id': admin_user.id}, timeout=900)
            return (admin_user, decoded_token)
        
        # 2. Landlord
        landlord = LandlordProfile.objects.filter(firebase_uid=uid).first()
        if landlord:
            request.user_role = 'landlord'
            cache.set(cache_key, {'role': 'landlord', 'id': landlord.id}, timeout=900)
            return (landlord, decoded_token)

        # 3. Student
        student = StudentProfile.objects.filter(firebase_uid=uid).first()
        if student:
            request.user_role = 'student'
            cache.set(cache_key, {'role': 'student', 'id': student.id}, timeout=900)
            return (student, decoded_token)

        # 4. Medical Responder (NEW)
        responder = MedicalResponderProfile.objects.filter(firebase_uid=uid).first()
        if responder:
            request.user_role = 'responder'
            cache.set(cache_key, {'role': 'responder', 'id': responder.id}, timeout=900)
            return (responder, decoded_token)

        # 5. Attendant
        attendant = AttendantProfile.objects.filter(firebase_uid=uid).first()
        if attendant:
            request.user_role = 'attendant'
            cache.set(cache_key, {'role': 'attendant', 'id': attendant.id}, timeout=900)
            return (attendant, decoded_token)

        raise AuthenticationFailed('Account verified by Firebase, but no local profile exists.')
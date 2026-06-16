from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    LandlordProfileViewSet,
    BlockViewSet,
    MedicalResponderProfileViewSet,
    UnitViewSet, 
    AccommodationViewSet, 
    RoomViewSet, 
    StudentProfileViewSet, 
    AttendantProfileViewSet,  
    IssueViewSet, 
    ChargeViewSet, 
    LeavePermitViewSet, 
    RoomInspectionViewSet,
    RegisterLandlordView,
    NotificationViewSet,
    create_emergency_report,
    login_user,
    ApplyAccommodationView,
    add_student_by_landlord,
    student_self_register, 
    add_attendant_by_landlord,
    send_communication,
    create_payment_link,
    verify_permit_qr,
    verify_landlord_identity_app,
    CampusLocationViewSet,
    StudentMedicalProfileViewSet,
    EmergencyReportViewSet,EmergencyAccessLogViewSet,
    unlock_medical_data,MedicalResponderProfileViewSet, add_medical_responder,
    verify_responder_login
)
from . import views 

router = DefaultRouter() 

router.register(r'emergency-access-logs', EmergencyAccessLogViewSet, basename='emergencyaccesslog')
router.register(r'landlords', LandlordProfileViewSet)
router.register(r'blocks', BlockViewSet)
router.register(r'units', UnitViewSet) 
router.register(r'accommodations', AccommodationViewSet,basename='accommodation')
router.register(r'rooms', RoomViewSet)
router.register(r'students', StudentProfileViewSet)
router.register(r'attendants', AttendantProfileViewSet,basename='attendant') 
router.register(r'issues', IssueViewSet)
router.register(r'charges', ChargeViewSet)
router.register(r'leave-permits', LeavePermitViewSet, basename='leavepermit')
router.register(r'room-inspections', RoomInspectionViewSet)
router.register(r'notifications', NotificationViewSet, basename='notification')
router.register(r'gate-passes', views.GatePassViewSet, basename='gatepass')
router.register(r'campus-locations', CampusLocationViewSet, basename='campuslocation')
router.register(r'medical-profiles', StudentMedicalProfileViewSet, basename='medicalprofile')
router.register(r'emergencies', EmergencyReportViewSet, basename='emergency')

router.register(r'medical-responders', MedicalResponderProfileViewSet)
urlpatterns = [ 
    # 1. Custom endpoints go FIRST
    path('emergencies/create/', create_emergency_report, name='create_emergency'),
    path('emergencies/unlock-medical-data/', unlock_medical_data, name='unlock_medical_data'),
    
    path('register-landlord/', RegisterLandlordView.as_view(), name='register_landlord'),
    path('student-self-register/', student_self_register, name='student_self_register'), 
    path('login/', login_user, name='login_user'),
    path('add-student/', add_student_by_landlord, name='add_student'),
    path('add-attendant/', add_attendant_by_landlord, name='add_attendant'),
    path('send-communication/', send_communication, name='send_communication'),
    path('create-seller-subaccount/', views.create_seller_subaccount, name='create_seller_account'),
    path('create-payment-link/', create_payment_link, name='create_payment_link'),
    path('verify-permit-qr/', verify_permit_qr, name='verify_permit_qr'), 
    path('permits/verify-face/', views.verify_face_match, name='verify_face_at_gate'),
    path('verify-gate-pass-qr/', views.verify_gate_pass_qr, name='verify_gate_pass_qr'),
    path('verify-student-presence/<str:student_id>/', views.verify_student_presence, name='verify_student_presence'),
    path('update-fcm-token/', views.update_fcm_token, name='update_fcm_token'), 
    path('students/<uuid:student_id>/decrypted-face/', views.fetch_decrypted_face, name='fetch_decrypted_face'),
    path('apply-accommodation/', ApplyAccommodationView.as_view(), name='apply-accommodation'),
    path('verify-landlord-identity-app/', verify_landlord_identity_app, name='verify_landlord_identity_app'),
    path('add-medical-responder/', add_medical_responder, name='add_medical_responder'),
    path('verify-responder-login/', verify_responder_login, name='verify_responder_login'),
    path('request-manual-review/', views.request_manual_review, name='request_manual_review'), 
    path('serve-decrypted-file/', views.serve_decrypted_file_by_url, name='serve_decrypted_file_by_url'),

    # 2. Generic router goes LAST so it doesn't swallow custom paths
    path('', include(router.urls)), 
]
import uuid
from django.db import models
from django.utils import timezone
from datetime import timedelta
from django_cryptography.fields import encrypt 
from django.core.exceptions import ValidationError

class BaseModel(models.Model):
    """Abstract base model to provide UUID and timestamp fields."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True

class AdminProfile(BaseModel):
    ROLE_CHOICES = [
        ('SUPERADMIN', 'Super Administrator'),
        ('MODERATOR', 'System Moderator'),
        ('SUPPORT', 'Support Agent'),
    ]
    
    firebase_uid = models.CharField(max_length=128, unique=True)
    fcm_token = models.TextField(blank=True, null=True)
    name = models.CharField(max_length=100)
    surname = models.CharField(max_length=100)
    email = encrypt(models.EmailField())
    phone = encrypt(models.CharField(max_length=15, blank=True, null=True))
    face_url = encrypt(models.URLField(blank=True, null=True, max_length=500))
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='SUPERADMIN')
    is_active = models.BooleanField(default=True)

    @property
    def is_authenticated(self):
        return True

    def __str__(self):
        return f"{self.name} {self.surname} ({self.role})"

class LandlordProfile(BaseModel): 
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    firebase_uid = models.CharField(max_length=128, unique=True)
    fcm_token = models.TextField(blank=True, null=True)
    name = models.CharField(max_length=100, blank=True, null=True)
    surname = models.CharField(max_length=100, blank=True, null=True)
    email = encrypt(models.EmailField())
    phone = encrypt(models.CharField(max_length=15, blank=True, null=True))
    
    # Dual Verification System
    is_verified = models.BooleanField(default=False) 
    digital_verification_status = models.BooleanField(default=False)
    manual_verification_status = models.BooleanField(default=False)
    
    # Device and Contract Tracking
    device_id = models.CharField(max_length=255, blank=True, null=True)
    contract_signed = models.BooleanField(default=False)
    contract_url = models.CharField(max_length=500, blank=True, null=True)
    
    # Encrypted File URLs for secure storage in Firebase
    face_url = models.CharField(max_length=500, blank=True, null=True)
    id_document_url = models.CharField(max_length=500, blank=True, null=True)
    
    paystack_merchant_code = models.CharField(max_length=100, blank=True, null=True)
    seller_paystack_account = models.CharField(max_length=100, blank=True, null=True)
    
    @property
    def is_authenticated(self):
        return True
    def __str__(self):
        return f"{self.name or 'New'} {self.surname or 'Landlord'} ({self.email})"

class Accommodation(BaseModel):
    GENDER_CHOICES = [
        ('MALE', 'Male Only'),
        ('FEMALE', 'Female Only'),
        ('MIXED', 'Mixed / Co-ed'),
    ]
    landlord = models.ForeignKey(LandlordProfile, on_delete=models.CASCADE, related_name='accommodations', null=True, blank=True)
    name = models.CharField(max_length=255)
    address = models.TextField()
    key_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    gender_target = models.CharField(max_length=10, choices=GENDER_CHOICES, default='MIXED')
    accommodation_type = models.CharField(max_length=100, blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    accommodation_logo_url = models.URLField(blank=True, null=True)
    contact_info = models.CharField(max_length=255, blank=True, null=True)

    @property
    def is_authenticated(self): return True
    def __str__(self): return self.name

class Block(BaseModel):
    accommodation = models.ForeignKey(Accommodation, on_delete=models.CASCADE, related_name='blocks')
    name = models.CharField(max_length=100) 
    gender_target = models.CharField(max_length=10, choices=Accommodation.GENDER_CHOICES, default='MIXED')
    
    @property
    def is_authenticated(self): return True
    def __str__(self): return f"{self.accommodation.name} - {self.name}"
    
class Unit(BaseModel):
    block = models.ForeignKey(Block, on_delete=models.CASCADE, related_name='Units')
    name = models.CharField(max_length=100) 
    gender_target = models.CharField(max_length=10, choices=Accommodation.GENDER_CHOICES, default='MIXED')
    
    @property
    def is_authenticated(self): return True
    def __str__(self): return f"{self.block.name} - {self.name}"

class Room(BaseModel):
    block = models.ForeignKey(Block, on_delete=models.CASCADE, related_name='rooms', null=True, blank=True) 
    unit = models.ForeignKey(Unit, on_delete=models.CASCADE, related_name='rooms', null=True, blank=True) 
    room_number = models.CharField(max_length=50)
    
    def __str__(self):
        if self.unit:
            return f"{self.unit.block.accommodation.name} | {self.unit.block.name} | {self.unit.name} - Room {self.room_number}"
        elif self.block:
            return f"{self.block.accommodation.name} | {self.block.name} - Room {self.room_number}"
        return f"Room {self.room_number} (No Block Assigned)"
    
class StudentProfile(BaseModel):  
    GENDER_CHOICES = [('MALE', 'Male'), ('FEMALE', 'Female')]
    
    gender = models.CharField(max_length=10, choices=GENDER_CHOICES, default='MALE')
    verification_status= models.BooleanField(default=False)
    face_encoding_json = models.TextField(blank=True, null=True)
    landlord = models.ForeignKey(LandlordProfile, on_delete=models.CASCADE, related_name='students', null=True, blank=True)
    fcm_token = models.TextField(blank=True, null=True)
    firebase_uid = models.CharField(max_length=128, unique=True)
    name = models.CharField(max_length=100)
    surname = models.CharField(max_length=100)
    email = encrypt(models.EmailField()) 
    room = models.ForeignKey(Room, on_delete=models.SET_NULL, null=True, blank=True, related_name='students')
    student_number = models.CharField(max_length=20, unique=True)
    id_number = encrypt(models.CharField(max_length=13, null=True, blank=True)) 
    phone = encrypt(models.CharField(max_length=15, null=True, blank=True))
    applied_accommodation = models.ForeignKey('Accommodation', on_delete=models.SET_NULL, null=True, blank=True, related_name='applicants')
    face_url = models.URLField(blank=True, null=True)

    id_document_url = models.CharField(max_length=500, blank=True, null=True)
    proof_of_registration_url = models.CharField(max_length=500, blank=True, null=True)
    
    is_cleared_for_exit = models.BooleanField(default=True)
    requires_password_change = models.BooleanField(default=True)

    def clean(self):
        if self.room:
            target = 'MIXED'
            if self.room.unit:
                target = self.room.unit.gender_target
            elif self.room.block:
                target = self.room.block.gender_target
            
            if target != 'MIXED' and target != self.gender:
                raise ValidationError(f"Gender Mismatch: Cannot assign a {self.gender} student to a {target} area.")

    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)

    @property
    def accommodation_logo_url(self):
        if self.room and hasattr(self.room, 'unit') and self.room.unit and self.room.unit.block and self.room.unit.block.accommodation:
            return self.room.unit.block.accommodation.accommodation_logo_url
        elif self.room and self.room.block and self.room.block.accommodation:
            return self.room.block.accommodation.accommodation_logo_url
        return None

    @property
    def is_authenticated(self):
        return True

    def __str__(self):
        return f"{self.name} {self.surname} ({self.student_number})"

class AttendantProfile(BaseModel):
    ROLE_CHOICES = [
        ('SECURITY', 'Security Officer'),
        ('ATTENDANT', 'Room Attendant'),
        ('GENERAL', 'General Staff'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False) 
    landlord = models.ForeignKey(LandlordProfile, on_delete=models.CASCADE, related_name='attendants', null=True, blank=True)
    firebase_uid = models.CharField(max_length=128)
    name = models.CharField(max_length=100)
    surname = models.CharField(max_length=100)
    fcm_token = models.TextField(blank=True, null=True)
    email = encrypt(models.EmailField())
    phone = encrypt(models.CharField(max_length=15))
    face_url = encrypt(models.URLField(blank=True, null=True, max_length=500))
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='ATTENDANT')

    @property
    def is_authenticated(self):
        return True

    def __str__(self):
        return f"{self.name} {self.surname} ({self.role})"
 
class Issue(BaseModel):
    STATUS_CHOICES = [
        ('AWAITING_PAYMENT', 'Awaiting Payment'),
        ('PENDING', 'Pending'),       
        ('ATTENDING', 'Attending'),
        ('RESOLVED', 'Resolved'),
    ]
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name='issues')
    room = models.ForeignKey(Room, on_delete=models.CASCADE, related_name='reported_issues')
    attendant_rating = models.IntegerField(null=True, blank=True) 
    assigned_attendant = models.ForeignKey(AttendantProfile, on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_issues')
    custom_issue_title = models.CharField(max_length=255) 
    description = models.TextField() 
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING') 
    available_from = models.DateTimeField()
    available_to = models.DateTimeField()
    is_priority = models.BooleanField(default=False)

    def save(self, *args, **kwargs):
        if not self.pk: 
            if self.custom_issue_title == "Lost Key":
                self.status = 'AWAITING_PAYMENT'
            else:
                self.status = 'PENDING'
                
            time_difference = self.available_from - timezone.now()
            self.is_priority = time_difference <= timedelta(hours=5)
                
            if self.room and not self.is_priority:
                if hasattr(self.room, 'unit') and self.room.unit:
                    similar_issues = Issue.objects.filter(
                        room__unit=self.room.unit, 
                        status__in=['PENDING', 'ATTENDING']
                    ).exclude(student=self.student).count()
                elif self.room.block:
                    similar_issues = Issue.objects.filter(
                        room__block=self.room.block, 
                        status__in=['PENDING', 'ATTENDING']
                    ).exclude(student=self.student).count()
                else:
                    similar_issues = 0
                    
                if similar_issues >= 1:
                    self.is_priority = True
                
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.custom_issue_title} - {self.room.room_number} ({self.status})"

class Charge(BaseModel):
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name='charges')
    issue = models.ForeignKey(Issue, on_delete=models.SET_NULL, null=True, blank=True, related_name='associated_charge')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    description = models.CharField(max_length=255) 
    is_paid = models.BooleanField(default=False)
    paystack_reference = models.CharField(max_length=100, blank=True, null=True)
    due_date = models.DateField(blank=True, null=True)

    def __str__(self):
        return f"{self.student.name} - {self.amount} (Paid: {self.is_paid})" 

class LeavePermit(BaseModel):
    STATUS_CHOICES = [
        ('REQUESTED', 'Requested'),
        ('INSPECTING', 'Inspecting'),
        ('APPROVED', 'Approved'),
        ('DENIED', 'Denied')
    ]
    
    PROVINCE_CHOICES = [
        ('Gauteng', 'Gauteng'),
        ('KwaZulu-Natal', 'KwaZulu-Natal'),
        ('Western Cape', 'Western Cape'),
        ('Eastern Cape', 'Eastern Cape'),
        ('Free State', 'Free State'),
        ('Mpumalanga', 'Mpumalanga'),
        ('Limpopo', 'Limpopo'),
        ('North West', 'North West'),
        ('Northern Cape', 'Northern Cape'),
        ('Outside SA', 'Outside South Africa'),
    ]

    student = models.ForeignKey('StudentProfile', on_delete=models.CASCADE, related_name='permits')
    assigned_attendant = models.ForeignKey('AttendantProfile', on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_inspections')
    departure_date = models.DateTimeField(blank=True, null=True)
    parent_cell_number = models.CharField(max_length=20, blank=True, null=True)
    destination_province = models.CharField(max_length=50, choices=PROVINCE_CHOICES , null=True, blank=True)
    destination_address = models.TextField(null=True, blank=True)
    reason = models.TextField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='REQUESTED')
    qr_reference = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    
    def __str__(self):
        return f"Permit: {self.student.user.username if hasattr(self.student, 'user') else self.student.id} - {self.status}"

class RoomInspection(BaseModel):
    permit = models.OneToOneField(LeavePermit, on_delete=models.CASCADE, related_name='inspection')
    attendant = models.ForeignKey('AttendantProfile', on_delete=models.SET_NULL, null=True, related_name='conducted_inspections')
    inspection_date = models.DateTimeField(auto_now_add=True)
    is_damage_found = models.BooleanField(default=False)
    damage_notes = models.TextField(blank=True, null=True)
    
    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        if self.is_damage_found:
            self.permit.status = 'DENIED'
        else:
            self.permit.status = 'APPROVED'
        self.permit.save()

    def __str__(self):
        return f"Inspection for Permit #{self.permit.id}"

class GatePass(BaseModel):
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name='gate_passes')
    attendant = models.ForeignKey(AttendantProfile, on_delete=models.SET_NULL, null=True, related_name='issued_gate_passes')
    asset_name = models.CharField(max_length=255, blank=True, null=True)
    asset_number = models.CharField(max_length=100, blank=True, null=True)
    issued_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_active = models.BooleanField(default=True)

    def save(self, *args, **kwargs):
        if not self.expires_at:
            self.expires_at = timezone.now() + timedelta(days=90)
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Gate Pass for {self.student.name} {self.student.surname} (Active: {self.is_active})"

# --- NEW EXTENSIONS FOR EMERGENCY AND MAPS ---

class CampusLocation(BaseModel):
    """Provides coordinates for the mobile app map navigation."""
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    latitude = models.FloatField()
    longitude = models.FloatField()
    location_type = models.CharField(max_length=100, default='VENUE')

    def __str__(self):
        return f"{self.name} ({self.location_type})"

class StudentMedicalProfile(BaseModel):
    """Strictly encrypted medical data for emergency access only."""
    student = models.OneToOneField(StudentProfile, on_delete=models.CASCADE, related_name='medical_profile')
    blood_type = encrypt(models.CharField(max_length=10, blank=True, null=True))
    allergies = encrypt(models.TextField(blank=True, null=True))
    medical_conditions = encrypt(models.TextField(blank=True, null=True))
    emergency_contact_name = encrypt(models.CharField(max_length=100))
    emergency_contact_phone = encrypt(models.CharField(max_length=20))
    emergency_contact_relation = encrypt(models.CharField(max_length=50))

    def __str__(self):
        return f"Medical Profile: {self.student.student_number}"

class MedicalResponderProfile(BaseModel):
    """Dedicated secure table strictly for Medical and Emergency Response Personnel."""
    firebase_uid = models.CharField(max_length=128, unique=True)
    fcm_token = models.TextField(blank=True, null=True)
    name = models.CharField(max_length=100)
    surname = models.CharField(max_length=100)
    email = encrypt(models.EmailField())
    phone = encrypt(models.CharField(max_length=15))
    face_url = encrypt(models.URLField(blank=True, null=True, max_length=500))
    is_active = models.BooleanField(default=True) 
    role = models.CharField(max_length=20, default='responder')

    @property
    def is_authenticated(self):
        return True

    def __str__(self):
        return f"{self.name} {self.surname} (Medical Team)"

# Add this inside your models.py
class EmergencyReport(BaseModel):
    STATUS_CHOICES = [
        ('PENDING', 'Pending / Unassigned'),
        ('RESPONDING', 'Staff Responding'),
        ('RESOLVED', 'Resolved / Closed')
    ]
    # The student who pressed the panic button
    reporting_student = models.ForeignKey('StudentProfile', on_delete=models.CASCADE, related_name='reported_emergencies')
    
    # NEW: The student identified by the AI from the photo
    identified_patient = models.ForeignKey('StudentProfile', on_delete=models.SET_NULL, null=True, blank=True, related_name='medical_emergencies')  
    latitude = models.FloatField()
    longitude = models.FloatField()
    face_encoding_json = models.TextField(blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    emergency_type = models.CharField(max_length=100, default='Other')
    situation_image_url = models.CharField(max_length=500, blank=True, null=True) 
    description = models.TextField(blank=True, null=True)
    resolved_by = models.ForeignKey(MedicalResponderProfile, on_delete=models.SET_NULL, null=True, blank=True)
    def __str__(self):
        return f"{self.emergency_type} Emergency by {self.reporting_student.student_number} at {self.created_at}"
class EmergencyAccessLog(BaseModel):
    report = models.ForeignKey(EmergencyReport, on_delete=models.CASCADE, related_name='access_logs')
    accessed_by_uid = models.CharField(max_length=128) 
    student_accessed = models.ForeignKey('StudentProfile', on_delete=models.CASCADE)
    
    def __str__(self):
        return f"Access Log: {self.accessed_by_uid} accessed {self.student_accessed.student_number}"

class Notification(BaseModel):
    student = models.ForeignKey('StudentProfile', on_delete=models.CASCADE, related_name='notifications', null=True, blank=True)
    attendant = models.ForeignKey('AttendantProfile', on_delete=models.CASCADE, related_name='notifications', null=True, blank=True)
    landlord = models.ForeignKey('LandlordProfile', on_delete=models.CASCADE, related_name='notifications', null=True, blank=True)
    admin = models.ForeignKey('AdminProfile', on_delete=models.CASCADE, related_name='notifications', null=True, blank=True)
    
    # NEW: Link notifications to medical responders for emergency alerts
    responder = models.ForeignKey(MedicalResponderProfile, on_delete=models.CASCADE, related_name='notifications', null=True, blank=True)
    
    title = models.CharField(max_length=255)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    target_audience = models.CharField(max_length=50, default='all')

    def __str__(self):
        return f"{self.title} ({self.target_audience})"

# UPDATE the existing VisitorRegister model to add the signature
class VisitorRegister(BaseModel):
    STATUS_CHOICES = [
        ('PENDING', 'Pending Arrival'),
        ('SIGNED_IN', 'Signed In'),
        ('SIGNED_OUT', 'Signed Out'),
    ]
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name='visitors')
    visitor_name = models.CharField(max_length=255)
    visitor_contact = encrypt(models.CharField(max_length=20)) 
    visitor_id_number = encrypt(models.CharField(max_length=50))
    
    # NEW: Store signature as a base64 string or URL
    visitor_signature = models.TextField(blank=True, null=True) 
    
    qr_reference = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    time_in = models.DateTimeField(null=True, blank=True)
    time_out = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')

    def __str__(self):
        return f"Visitor: {self.visitor_name} visiting {self.student.student_number}"

# NEW: Audit Log Model
class VisitorAuditLog(BaseModel):
    visitor_record = models.ForeignKey(VisitorRegister, on_delete=models.CASCADE, related_name='audit_logs')
    # The security officer who scanned the QR
    security_officer = models.ForeignKey('AttendantProfile', on_delete=models.SET_NULL, null=True)
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE)
    action_taken = models.CharField(max_length=50) # 'SIGNED_IN', 'SIGNED_OUT'
    
    def __str__(self):
        return f"{self.action_taken} by {self.security_officer.name if self.security_officer else 'Unknown'} for {self.visitor_record.visitor_name}"
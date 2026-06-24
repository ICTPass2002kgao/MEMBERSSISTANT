from rest_framework import serializers
from .models import (
    AdminProfile,
    Room,
    Unit,
    Block,
    Issue, 
    Charge, 
    GatePass, 
    LeavePermit,
    Notification,
    Accommodation, 
    StudentProfile,
    RoomInspection, 
    LandlordProfile, 
    AttendantProfile,
    CampusLocation,
    StudentMedicalProfile,
    EmergencyReport,
    EmergencyAccessLog,
    VisitorAuditLog,
    VisitorRegister
) 

class AdminProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = AdminProfile
        fields = '__all__'
        read_only_fields = ['id', 'created_at', 'updated_at']

class LandlordProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = LandlordProfile
        fields = '__all__'
        read_only_fields = ['id', 'created_at', 'updated_at']
        
class BlockSerializer(serializers.ModelSerializer):
    class Meta:
        model = Block
        fields = '__all__'

class UnitSerializer(serializers.ModelSerializer):
    class Meta:
        model = Unit
        fields = '__all__'

class AccommodationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Accommodation
        fields = '__all__'

class RoomSerializer(serializers.ModelSerializer):
    class Meta:
        model = Room
        fields = '__all__'

class StudentProfileSerializer(serializers.ModelSerializer): 
    room_name = serializers.SerializerMethodField(read_only=True) 
    accommodation_name = serializers.SerializerMethodField(read_only=True)
    block_name = serializers.SerializerMethodField(read_only=True)
    unit_name = serializers.SerializerMethodField(read_only=True) 
    room_number_only = serializers.SerializerMethodField(read_only=True) 
    key_price = serializers.SerializerMethodField(read_only=True)
    applied_accommodation_name = serializers.CharField(source='applied_accommodation.name', read_only=True)
    
    class Meta:
        model = StudentProfile
        fields = '__all__'
        extra_kwargs = {
            'id_number': {'write_only': True},
        }

    def get_room_name(self, obj):
        if obj.room:
            return str(obj.room)
        return None

    def get_accommodation_name(self, obj):
        if obj.room:
            if hasattr(obj.room, 'unit') and obj.room.unit and obj.room.unit.block:
                return obj.room.unit.block.accommodation.name
            elif obj.room.block:
                return obj.room.block.accommodation.name
        return "Unassigned Accommodation"
    
    def get_block_name(self, obj):
        if obj.room:
            if hasattr(obj.room, 'unit') and obj.room.unit:
                return obj.room.unit.block.name
            elif obj.room.block:
                return obj.room.block.name
        return "Unassigned Block"
 
    def get_unit_name(self, obj):
        if obj.room and hasattr(obj.room, 'unit') and obj.room.unit:
            return obj.room.unit.name
        return "Unassigned Unit"

    def get_room_number_only(self, obj):
        if obj.room:
            return obj.room.room_number
        return "Unassigned Room"
    
    def get_key_price(self, obj):
        if not obj.room:
            return None
        room = obj.room
        if hasattr(room, 'unit') and room.unit and room.unit.block:
            return room.unit.block.accommodation.key_price
        if room.block:
            return room.block.accommodation.key_price
        return None
    
class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = '__all__'

class AttendantProfileSerializer(serializers.ModelSerializer):
    average_rating = serializers.FloatField(read_only=True)
    resolved_issues_count = serializers.IntegerField(read_only=True)
    class Meta:
        model = AttendantProfile
        fields = '__all__'
 
class IssueSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student.name', read_only=True)
    student_surname = serializers.CharField(source='student.surname', read_only=True)
    room_number = serializers.CharField(source='room.room_number', read_only=True)
    block_name = serializers.CharField(source='room.block.name', read_only=True)
    unit_name = serializers.CharField(source='room.unit.name', read_only=True, allow_null=True)
    
    assigned_attendant_name = serializers.SerializerMethodField()
    assigned_attendant_uid = serializers.CharField(source='assigned_attendant.firebase_uid', read_only=True)

    class Meta:
        model = Issue
        fields = '__all__' 
        read_only_fields = ('is_priority', 'student', 'room', 'assigned_attendant')

    def get_assigned_attendant_name(self, obj):
        if obj.assigned_attendant:
            return f"{obj.assigned_attendant.name} {obj.assigned_attendant.surname}"
        return None

class ChargeSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student.name', read_only=True)
    student_surname = serializers.CharField(source='student.surname', read_only=True)
    student_number = serializers.CharField(source='student.student_number', read_only=True)
    room_number = serializers.CharField(source='student.room.room_number', read_only=True, default="N/A")
    block_name = serializers.CharField(source='student.room.block.name', read_only=True, default="N/A")

    class Meta:
        model = Charge
        fields = '__all__'

class LeavePermitSerializer(serializers.ModelSerializer): 
    student_details = StudentProfileSerializer(source='student', read_only=True)

    class Meta:
        model = LeavePermit
        fields = '__all__' 
        read_only_fields = ['student', 'status', 'qr_reference', 'student_details']
        
class RoomInspectionSerializer(serializers.ModelSerializer):
    class Meta:
        model = RoomInspection
        fields = '__all__'
        
class GatePassSerializer(serializers.ModelSerializer):
    class Meta:
        model = GatePass
        fields = '__all__'
        read_only_fields = ['student', 'attendant', 'issued_at', 'expires_at']

# --- NEW SERIALIZERS ---

class CampusLocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = CampusLocation
        fields = '__all__'

class StudentMedicalProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = StudentMedicalProfile
        fields = '__all__'
        read_only_fields = ['student']
# Update inside serializers.py
    
class EmergencyReportSerializer(serializers.ModelSerializer):
    reporter_name = serializers.SerializerMethodField()
    reporter_role = serializers.SerializerMethodField()
    
    # We pull all details from the IDENTIFIED PATIENT
    patient_name = serializers.SerializerMethodField()
    patient_room = serializers.SerializerMethodField()
    patient_id = serializers.CharField(source='identified_patient.id', read_only=True)
    
    class Meta:
        model = EmergencyReport
        fields = '__all__'
        read_only_fields = ['reporting_student', 'reporting_attendant', 'status', 'resolved_by', 'identified_patient']

    def get_reporter_name(self, obj):
        # Autonomously checks who the backend linked to the report
        if obj.reporting_student:
            return f"{obj.reporting_student.name} {obj.reporting_student.surname}"
        elif obj.reporting_attendant:
            return f"{obj.reporting_attendant.name} {obj.reporting_attendant.surname}"
        return "System / Anonymous"

    def get_reporter_role(self, obj):
        # Exposes the exact role to the frontend
        if obj.reporting_student:
            return "STUDENT"
        elif obj.reporting_attendant:
            return obj.reporting_attendant.role # Returns 'SECURITY', 'ATTENDANT', or 'GENERAL'
        return "SYSTEM"

    def get_patient_name(self, obj):
        if obj.identified_patient:
            return f"{obj.identified_patient.name} {obj.identified_patient.surname}"
        return "Unidentified Patient"

    def get_patient_room(self, obj):
        if obj.identified_patient and obj.identified_patient.room:
            return obj.identified_patient.room.room_number
        return "Unknown Room"
class EmergencyAccessLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyAccessLog
        fields = '__all__'
        
from .models import MedicalResponderProfile

class MedicalResponderProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = MedicalResponderProfile
        fields = '__all__'
        
from .models import EmergencyAccessLog

class EmergencyAccessLogSerializer(serializers.ModelSerializer):
    student_name = serializers.SerializerMethodField()
    student_number = serializers.CharField(source='student_accessed.student_number', read_only=True)
    latitude = serializers.FloatField(source='report.latitude', read_only=True)
    longitude = serializers.FloatField(source='report.longitude', read_only=True)

    class Meta:
        model = EmergencyAccessLog
        fields = ['id', 'accessed_by_uid', 'created_at', 'student_name', 'student_number', 'latitude', 'longitude']

    def get_student_name(self, obj):
        return f"{obj.student_accessed.name} {obj.student_accessed.surname}"
    
class VisitorRegisterSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student.name', read_only=True)
    student_surname = serializers.CharField(source='student.surname', read_only=True)
    room_number = serializers.CharField(source='student.room.room_number', read_only=True, default="Unassigned")
    block_name = serializers.CharField(source='student.room.block.name', read_only=True, default="Unassigned")

    class Meta:
        model = VisitorRegister
        fields = '__all__'
        read_only_fields = ['student', 'qr_reference', 'time_in', 'time_out', 'status']
          

class VisitorAuditLogSerializer(serializers.ModelSerializer):
    security_officer = serializers.SerializerMethodField()
    visitor_record = serializers.SerializerMethodField()
    student = serializers.SerializerMethodField()
    
    # NEW: Pull Room and Block directly into the audit log
    room_number = serializers.CharField(source='student.room.room_number', read_only=True, default="N/A")
    block_name = serializers.CharField(source='student.room.block.name', read_only=True, default="N/A")

    class Meta:
        model = VisitorAuditLog
        fields = '__all__'

    def get_security_officer(self, obj):
        if obj.security_officer:
            return {"name": obj.security_officer.name, "surname": obj.security_officer.surname}
        return None

    def get_visitor_record(self, obj):
        if obj.visitor_record:
            return {"id": str(obj.visitor_record.id), "visitor_name": obj.visitor_record.visitor_name}
        return None

    def get_student(self, obj):
        if obj.student:
            return {"name": obj.student.name, "surname": obj.student.surname}
        return None
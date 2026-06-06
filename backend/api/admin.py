from django.contrib import admin
from .models import (
    AdminProfile,
    Accommodation, 
    Block, 
    Unit,
    Room, 
    StudentProfile, 
    AttendantProfile, 
    Issue, 
    Charge, 
    LeavePermit, 
    RoomInspection,
    LandlordProfile,
    Notification,
    GatePass
)

@admin.register(AdminProfile)
class AdminProfileAdmin(admin.ModelAdmin):
    list_display = ('name', 'surname', 'role', 'is_active')
    search_fields = ('name', 'surname', 'email', 'firebase_uid')
    list_filter = ('role', 'is_active')

@admin.register(LandlordProfile)
class LandlordProfileAdmin(admin.ModelAdmin):
    list_display = ('name', 'surname', 'email', 'phone', 'is_verified')
    search_fields = ('name', 'surname', 'email', 'id')
    list_filter = ('is_verified', 'digital_verification_status', 'manual_verification_status')

@admin.register(Accommodation)
class AccommodationAdmin(admin.ModelAdmin):
    list_display = ('name', 'landlord', 'accommodation_type', 'gender_target', 'created_at')
    search_fields = ('name', 'address', 'landlord__name')
    list_filter = ('accommodation_type', 'gender_target')

@admin.register(Block)
class BlockAdmin(admin.ModelAdmin):
    list_display = ('name', 'accommodation', 'gender_target')
    search_fields = ('name', 'accommodation__name')
    list_filter = ('gender_target', 'accommodation')

@admin.register(Unit)
class UnitAdmin(admin.ModelAdmin):
    list_display = ('name', 'block', 'gender_target')
    search_fields = ('name', 'block__name', 'block__accommodation__name')
    list_filter = ('gender_target', 'block__accommodation')

@admin.register(Room)
class RoomAdmin(admin.ModelAdmin):
    list_display = ('room_number', 'get_accommodation_name', 'block', 'unit', 'created_at')
    search_fields = ('room_number', 'block__name', 'unit__name', 'block__accommodation__name')
    list_filter = ('block__accommodation', 'block')

    def get_accommodation_name(self, obj):
        if obj.unit and obj.unit.block:
            return obj.unit.block.accommodation.name
        elif obj.block:
            return obj.block.accommodation.name
        return "Unassigned"
    get_accommodation_name.short_description = 'Accommodation'

@admin.register(StudentProfile)
class StudentProfileAdmin(admin.ModelAdmin):
    list_display = ('name', 'surname', 'student_number', 'room', 'verification_status', 'is_cleared_for_exit')
    search_fields = ('name', 'surname', 'student_number', 'firebase_uid', 'id_number')
    list_filter = ('verification_status', 'is_cleared_for_exit', 'requires_password_change', 'gender')

@admin.register(AttendantProfile)
class AttendantProfileAdmin(admin.ModelAdmin):
    list_display = ('name', 'surname', 'role', 'landlord')
    search_fields = ('name', 'surname', 'firebase_uid', 'email')
    list_filter = ('role',)

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('title', 'target_audience', 'is_read', 'created_at')
    search_fields = ('title', 'message', 'student__student_number', 'attendant__name', 'landlord__name', 'admin__name')
    list_filter = ('is_read', 'target_audience')

@admin.register(Issue)
class IssueAdmin(admin.ModelAdmin):
    list_display = ('custom_issue_title', 'room', 'status', 'is_priority', 'assigned_attendant')
    search_fields = ('custom_issue_title', 'room__room_number', 'student__student_number')
    list_filter = ('status', 'is_priority')

@admin.register(Charge)
class ChargeAdmin(admin.ModelAdmin):
    list_display = ('student', 'amount', 'is_paid', 'due_date')
    search_fields = ('student__student_number', 'paystack_reference')
    list_filter = ('is_paid',)

@admin.register(LeavePermit)
class LeavePermitAdmin(admin.ModelAdmin):
    list_display = ('student', 'status', 'departure_date', 'destination_province')
    search_fields = ('student__student_number', 'qr_reference')
    list_filter = ('status', 'destination_province')

@admin.register(RoomInspection)
class RoomInspectionAdmin(admin.ModelAdmin):
    list_display = ('permit', 'attendant', 'is_damage_found', 'inspection_date')
    list_filter = ('is_damage_found',)
    search_fields = ('permit__student__student_number', 'attendant__name')

@admin.register(GatePass)
class GatePassAdmin(admin.ModelAdmin):
    list_display = ('student', 'asset_name', 'is_active', 'expires_at')
    search_fields = ('student__student_number', 'asset_name', 'asset_number')
    list_filter = ('is_active',)
from rest_framework.permissions import BasePermission

class IsLandlord(BasePermission):
    """
    Allows access only to users identified as Landlords.
    """
    def has_permission(self, request, view):
        # The 'user_role' is set in your FirebaseAuthentication class
        return bool(
            request.user and 
            getattr(request, 'user_role', None) == 'landlord'
        )

class IsStudent(BasePermission):
    """
    Allows access only to users identified as Students.
    """
    def has_permission(self, request, view):
        return bool(
            request.user and 
            getattr(request, 'user_role', None) == 'student'
        )

class IsAttendant(BasePermission):
    """
    Allows access only to users identified as Attendants (Staff).
    """
    def has_permission(self, request, view):
        return bool(
            request.user and 
            getattr(request, 'user_role', None) == 'attendant'
        )
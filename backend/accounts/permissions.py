from rest_framework.permissions import BasePermission

from .models import UserProfile


class IsDoctor(BasePermission):
    message = 'Doctor account required.'

    def has_permission(self, request, view):
        user = request.user

        if not user or not user.is_authenticated:
            return False

        try:
            profile = user.profile
        except UserProfile.DoesNotExist:
            return False

        return profile.role == UserProfile.ROLE_DOCTOR

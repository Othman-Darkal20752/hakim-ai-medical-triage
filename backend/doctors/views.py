from django.shortcuts import get_object_or_404
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.authentication import JWTAuthentication

from accounts.permissions import IsDoctor

from .models import DoctorProfile, Specialty
from .serializers import (
    DoctorSelfProfileSerializer,
    SpecialtySerializer,
)


class DoctorMeView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated, IsDoctor]

    def get_object(self):
        return get_object_or_404(
            DoctorProfile.objects.select_related('specialty'),
            user=self.request.user,
        )

    def get(self, request):
        doctor_profile = self.get_object()
        serializer = DoctorSelfProfileSerializer(doctor_profile)

        return Response(serializer.data)

    def patch(self, request):
        doctor_profile = self.get_object()
        serializer = DoctorSelfProfileSerializer(
            doctor_profile,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(serializer.data)


class SpecialtyListView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated, IsDoctor]

    def get(self, request):
        specialties = Specialty.objects.filter(is_active=True)
        serializer = SpecialtySerializer(specialties, many=True)

        return Response(serializer.data)

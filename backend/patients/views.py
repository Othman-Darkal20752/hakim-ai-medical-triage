from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.authentication import JWTAuthentication

from accounts.permissions import IsPatient

from .models import PatientHealthProfile
from .serializers import PatientHealthProfileSerializer


class PatientHealthProfileView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated, IsPatient]

    def get_object(self):
        patient_profile, _ = PatientHealthProfile.objects.get_or_create(
            user=self.request.user,
        )

        return patient_profile

    def get(self, request):
        patient_profile = self.get_object()
        serializer = PatientHealthProfileSerializer(patient_profile)

        return Response(serializer.data)

    def patch(self, request):
        patient_profile = self.get_object()
        serializer = PatientHealthProfileSerializer(
            patient_profile,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(serializer.data)

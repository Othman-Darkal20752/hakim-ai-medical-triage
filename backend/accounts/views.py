from django.conf import settings
from django.contrib.auth.models import User
from django.db import transaction
from django.utils.text import slugify
from google.auth.exceptions import GoogleAuthError
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import ExternalIdentity, UserProfile
from .serializers import (
    GoogleLoginSerializer,
    MeSerializer,
    RegisterSerializer,
)


def _build_unique_google_username(email, subject):
    local_part = email.split('@', maxsplit=1)[0]
    base = slugify(local_part)[:110] or 'google-user'
    suffix = subject[-12:]
    candidate = f'{base}-{suffix}'[:150]

    counter = 1
    while User.objects.filter(username=candidate).exists():
        counter_suffix = f'-{counter}'
        candidate = f'{base[:150 - len(counter_suffix)]}{counter_suffix}'
        counter += 1

    return candidate


def _is_verified_email(value):
    if value is True:
        return True
    return str(value).lower() == 'true'


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = serializer.save()
        refresh = RefreshToken.for_user(user)

        return Response(
            {
                'user': MeSerializer(user).data,
                'access': str(refresh.access_token),
                'refresh': str(refresh),
            },
            status=status.HTTP_201_CREATED,
        )


class GoogleLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = GoogleLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        if not settings.GOOGLE_CLIENT_ID:
            return Response(
                {'detail': 'Google login is not configured on the server.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        token = serializer.validated_data['id_token']

        try:
            token_info = google_id_token.verify_oauth2_token(
                token,
                google_requests.Request(),
                settings.GOOGLE_CLIENT_ID,
            )
        except (ValueError, GoogleAuthError):
            return Response(
                {'detail': 'Invalid Google ID token.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        issuer = token_info.get('iss')
        if issuer not in ('accounts.google.com', 'https://accounts.google.com'):
            return Response(
                {'detail': 'Invalid Google token issuer.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        subject = str(token_info.get('sub') or '').strip()
        email = str(token_info.get('email') or '').strip().lower()

        if not subject:
            return Response(
                {'detail': 'Google account identifier is missing.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not email or not _is_verified_email(token_info.get('email_verified')):
            return Response(
                {'detail': 'A verified Google email is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        given_name = str(token_info.get('given_name') or '')[:150]
        family_name = str(token_info.get('family_name') or '')[:150]

        with transaction.atomic():
            identity = (
                ExternalIdentity.objects
                .select_related('user')
                .filter(
                    provider=ExternalIdentity.PROVIDER_GOOGLE,
                    subject=subject,
                )
                .first()
            )

            created = identity is None

            if identity is not None:
                user = identity.user
                changed_fields = []

                if user.email != email:
                    user.email = email
                    changed_fields.append('email')

                if given_name and user.first_name != given_name:
                    user.first_name = given_name
                    changed_fields.append('first_name')

                if family_name and user.last_name != family_name:
                    user.last_name = family_name
                    changed_fields.append('last_name')

                if changed_fields:
                    user.save(update_fields=changed_fields)

                if identity.email != email:
                    identity.email = email
                    identity.save(update_fields=['email', 'updated_at'])
            else:
                user = User(
                    username=_build_unique_google_username(email, subject),
                    email=email,
                    first_name=given_name,
                    last_name=family_name,
                )
                user.set_unusable_password()
                user.save()

                ExternalIdentity.objects.create(
                    user=user,
                    provider=ExternalIdentity.PROVIDER_GOOGLE,
                    subject=subject,
                    email=email,
                )

            UserProfile.objects.get_or_create(
                user=user,
                defaults={'role': UserProfile.ROLE_PATIENT},
            )

        if not user.is_active:
            return Response(
                {'detail': 'This account is disabled.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        refresh = RefreshToken.for_user(user)

        return Response(
            {
                'user': MeSerializer(user).data,
                'access': str(refresh.access_token),
                'refresh': str(refresh),
            },
            status=(
                status.HTTP_201_CREATED
                if created
                else status.HTTP_200_OK
            ),
        )


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(MeSerializer(request.user).data)

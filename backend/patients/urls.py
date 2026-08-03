from django.urls import path

from .views import PatientHealthProfileView


urlpatterns = [
    path(
        'health-profile/',
        PatientHealthProfileView.as_view(),
        name='patient-health-profile',
    ),
]

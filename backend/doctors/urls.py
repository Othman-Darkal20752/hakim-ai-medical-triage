from django.urls import path

from .views import DoctorMeView, SpecialtyListView


urlpatterns = [
    path('me/', DoctorMeView.as_view(), name='doctor-me'),
    path(
        'specialties/',
        SpecialtyListView.as_view(),
        name='doctor-specialty-list',
    ),
]

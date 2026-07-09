from django.urls import path

from .views import send_chat_message

urlpatterns = [
    path("messages/", send_chat_message, name="send_chat_message"),
]
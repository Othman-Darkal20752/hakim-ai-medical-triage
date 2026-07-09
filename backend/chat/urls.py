from django.urls import path

from .views import chat_messages, chat_session_detail, chat_sessions

urlpatterns = [
    path("messages/", chat_messages, name="chat-messages"),
    path("sessions/", chat_sessions, name="chat-sessions"),
    path(
        "sessions/<uuid:session_id>/",
        chat_session_detail,
        name="chat-session-detail",
    ),
]

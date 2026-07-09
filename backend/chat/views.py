import json

from django.core.exceptions import ValidationError
from django.http import JsonResponse
from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication

from .models import ChatSession, ChatMessage


def build_hakim_reply(user_message: str) -> str:
    """
    Temporary reply logic.
    Later we will replace this with:
    - safety triage checks
    - emergency red flags
    - AI model/API call
    - specialty recommendation
    """
    return "رد تجريبي من Django"


def get_or_create_chat_session(session_id, user):
    """
    Session ownership rules:
    - New session: attach to user if authenticated.
    - Existing anonymous session: allow it, and attach it to user if authenticated.
    - Existing user-owned session: only the same user can continue it.
    """

    if not session_id:
        return ChatSession.objects.create(
            user=user if user.is_authenticated else None
        ), None

    try:
        session = ChatSession.objects.get(id=session_id)
    except (ChatSession.DoesNotExist, ValidationError, ValueError):
        return None, JsonResponse(
            {"error": "Invalid or unknown session_id"},
            status=400,
        )

    if session.user is not None:
        if not user.is_authenticated:
            return None, JsonResponse(
                {"error": "Authentication is required for this session"},
                status=403,
            )

        if session.user_id != user.id:
            return None, JsonResponse(
                {"error": "You do not have permission to access this session"},
                status=403,
            )

    if session.user is None and user.is_authenticated:
        session.user = user
        session.save(update_fields=["user", "updated_at"])

    return session, None


@api_view(["POST"])
@authentication_classes([JWTAuthentication])
@permission_classes([AllowAny])
def chat_messages(request):
    try:
        payload = json.loads(request.body.decode("utf-8"))
    except json.JSONDecodeError:
        return JsonResponse(
            {"error": "Invalid JSON body"},
            status=400,
        )

    user_text = str(payload.get("message", "")).strip()
    session_id = payload.get("session_id")

    if not user_text:
        return JsonResponse(
            {"error": "Message is required"},
            status=400,
        )

    session, error_response = get_or_create_chat_session(
        session_id=session_id,
        user=request.user,
    )

    if error_response is not None:
        return error_response

    user_message = ChatMessage.objects.create(
        session=session,
        sender=ChatMessage.Sender.USER,
        content=user_text,
    )

    if not session.title:
        session.title = user_text[:60]
        session.save(update_fields=["title", "updated_at"])

    assistant_reply = build_hakim_reply(user_text)

    assistant_message = ChatMessage.objects.create(
        session=session,
        sender=ChatMessage.Sender.ASSISTANT,
        content=assistant_reply,
    )

    session.save(update_fields=["updated_at"])

    return JsonResponse(
        {
            "session_id": str(session.id),
            "reply": assistant_reply,
            "user_message_id": user_message.id,
            "assistant_message_id": assistant_message.id,
        },
        status=201,
    )


@api_view(["GET"])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def chat_sessions(request):
    sessions = ChatSession.objects.filter(user=request.user).order_by("-updated_at")

    data = []
    for session in sessions:
        last_message = session.messages.order_by("-created_at").first()

        data.append(
            {
                "id": str(session.id),
                "title": session.title or "محادثة بدون عنوان",
                "created_at": session.created_at.isoformat(),
                "updated_at": session.updated_at.isoformat(),
                "last_message": last_message.content if last_message else "",
                "messages_count": session.messages.count(),
            }
        )

    return JsonResponse({"sessions": data}, status=200)


@api_view(["GET"])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def chat_session_detail(request, session_id):
    session = get_object_or_404(
        ChatSession,
        id=session_id,
        user=request.user,
    )

    messages = [
        {
            "id": message.id,
            "sender": message.sender,
            "content": message.content,
            "created_at": message.created_at.isoformat(),
        }
        for message in session.messages.all()
    ]

    return JsonResponse(
        {
            "session": {
                "id": str(session.id),
                "title": session.title or "محادثة بدون عنوان",
                "created_at": session.created_at.isoformat(),
                "updated_at": session.updated_at.isoformat(),
            },
            "messages": messages,
        },
        status=200,
    )

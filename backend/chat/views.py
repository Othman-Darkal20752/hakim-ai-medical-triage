import json

from django.core.exceptions import ValidationError
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

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


@csrf_exempt
@require_POST
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

    if session_id:
        try:
            session = ChatSession.objects.get(id=session_id)
        except (ChatSession.DoesNotExist, ValidationError, ValueError):
            return JsonResponse(
                {"error": "Invalid or unknown session_id"},
                status=400,
            )
    else:
        session = ChatSession.objects.create()

    user_message = ChatMessage.objects.create(
        session=session,
        sender=ChatMessage.Sender.USER,
        content=user_text,
    )

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
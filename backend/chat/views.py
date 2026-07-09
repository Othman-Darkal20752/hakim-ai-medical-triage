from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status


@api_view(["POST"])
def send_chat_message(request):
    message = request.data.get("message", "").strip()
    session_id = request.data.get("session_id")

    if not message:
        return Response(
            {"detail": "message is required"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    normalized_message = normalize_arabic(message)

    emergency_keywords = [
        "الم صدر",
        "ضغط بالصدر",
        "ضيق نفس",
        "صعوبه تنفس",
        "اغماء",
        "فقدان الوعي",
        "نزيف شديد",
        "تشنج",
        "شلل",
        "ضعف مفاجئ",
        "صعوبه بالكلام",
        "اضطراب بالكلام",
        "الم شديد جدا",
    ]

    has_emergency_flag = any(
        keyword in normalized_message for keyword in emergency_keywords
    )

    if has_emergency_flag:
        reply = (
            "تنبيه مهم: بعض الأعراض التي ذكرتها قد تحتاج إلى رعاية عاجلة، "
            "خاصة إذا كانت شديدة أو ظهرت بشكل مفاجئ. يرجى مراجعة الطوارئ "
            "أو الاتصال بالإسعاف فوراً. حكيم يساعد في التوجيه الأولي فقط "
            "ولا يقدم تشخيصاً نهائياً."
        )
    else:
        reply = (
            "رد تجريبي من Django: فهمت عليك. حتى أقدر أوجهك بشكل أفضل، "
            "أحتاج منك بعض التفاصيل:\n\n"
            "1. منذ متى بدأت الأعراض؟\n"
            "2. ما شدة الألم أو التعب من 1 إلى 10؟\n"
            "3. هل يوجد حرارة، دوخة، ضيق تنفس، أو ألم صدر؟\n"
            "4. هل لديك أمراض مزمنة، أدوية دائمة، أو حساسية؟"
        )

    return Response(
        {
            "reply": reply,
            "session_id": session_id,
            "source": "django_mock",
        }
    )


def normalize_arabic(value):
    return (
        value.lower()
        .replace("أ", "ا")
        .replace("إ", "ا")
        .replace("آ", "ا")
        .replace("ة", "ه")
        .replace("ى", "ي")
    )
import uuid

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator
from django.db import models


class ChatSession(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='chat_sessions',
        null=True,
        blank=True,
    )
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
    )
    title = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]

    def __str__(self):
        return self.title or f"Chat session {self.id}"


class ChatMessage(models.Model):
    class Sender(models.TextChoices):
        USER = "user", "User"
        ASSISTANT = "assistant", "Assistant"
        SYSTEM = "system", "System"

    session = models.ForeignKey(
        ChatSession,
        on_delete=models.CASCADE,
        related_name="messages",
    )
    sender = models.CharField(
        max_length=20,
        choices=Sender.choices,
    )
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["session", "created_at"]),
        ]

    def __str__(self):
        return f"{self.sender}: {self.content[:40]}"


class ConversationClinicalState(models.Model):
    """
    Current structured clinical snapshot for one conversation.

    structured_state must contain only validated provider-independent
    triage data and sanitized backend safety metadata.

    Raw AI provider JSON, raw red-flag evidence, matched patient text,
    and text character offsets must never be persisted here.
    """

    class Urgency(models.TextChoices):
        ROUTINE = "routine", "Routine"
        SOON = "soon", "Soon"
        URGENT = "urgent", "Urgent"
        EMERGENCY = "emergency", "Emergency"

    class SafetyDecision(models.TextChoices):
        CONTINUE = "continue", "Continue"
        URGENT = "urgent", "Urgent"
        EMERGENCY = "emergency", "Emergency"

    class ExecutionPath(models.TextChoices):
        BACKEND_SAFETY_RESPONSE = (
            "backend_safety_response",
            "Backend safety response",
        )
        AI_PROVIDER = "ai_provider", "AI provider"

    session = models.OneToOneField(
        ChatSession,
        on_delete=models.CASCADE,
        related_name="clinical_state",
    )
    last_processed_message = models.ForeignKey(
        ChatMessage,
        on_delete=models.SET_NULL,
        related_name="+",
        null=True,
        blank=True,
    )

    schema_version = models.PositiveSmallIntegerField(
        default=1,
        validators=[MinValueValidator(1)],
    )
    structured_state = models.JSONField(
        default=dict,
    )

    urgency = models.CharField(
        max_length=20,
        choices=Urgency.choices,
        db_index=True,
    )
    safety_decision = models.CharField(
        max_length=20,
        choices=SafetyDecision.choices,
        db_index=True,
    )
    execution_path = models.CharField(
        max_length=40,
        choices=ExecutionPath.choices,
    )

    suggested_specialty = models.ForeignKey(
        "doctors.Specialty",
        on_delete=models.SET_NULL,
        related_name="conversation_clinical_states",
        null=True,
        blank=True,
    )
    suggested_specialty_code = models.CharField(
        max_length=50,
        blank=True,
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]
        verbose_name = "Conversation clinical state"
        verbose_name_plural = "Conversation clinical states"
        constraints = [
            models.CheckConstraint(
                condition=models.Q(schema_version__gte=1),
                name="clinical_schema_version_gte_1",
            ),
            models.CheckConstraint(
                condition=(
                    (
                        models.Q(
                            execution_path="backend_safety_response"
                        )
                        & models.Q(safety_decision="emergency")
                        & models.Q(urgency="emergency")
                    )
                    | (
                        models.Q(execution_path="ai_provider")
                        & models.Q(
                            safety_decision__in=[
                                "continue",
                                "urgent",
                            ]
                        )
                    )
                ),
                name="clinical_execution_path_valid",
            ),
            models.CheckConstraint(
                condition=(
                    ~models.Q(safety_decision="urgent")
                    | models.Q(
                        urgency__in=[
                            "urgent",
                            "emergency",
                        ]
                    )
                ),
                name="clinical_urgent_floor_valid",
            ),
        ]

    def clean(self):
        super().clean()

        if not isinstance(self.structured_state, dict):
            raise ValidationError(
                {
                    "structured_state": (
                        "Structured clinical state must be a JSON object."
                    ),
                }
            )

        if (
            self.session_id is not None
            and self.last_processed_message_id is not None
            and self.last_processed_message.session_id
            != self.session_id
        ):
            raise ValidationError(
                {
                    "last_processed_message": (
                        "The processed message must belong to the same "
                        "chat session."
                    ),
                }
            )

    def __str__(self):
        return f"Clinical state - {self.session_id}"

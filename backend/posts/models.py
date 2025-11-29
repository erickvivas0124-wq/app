from django.db import models
import uuid
from django.utils import timezone

class Card(models.Model):
    RISK_CHOICES = [
        ('I', 'I'),
        ('IIA', 'IIA'),
        ('IIB', 'IIB'),
        ('III', 'III'),
    ]
    name = models.CharField(max_length=100)
    image = models.ImageField(upload_to='cards/', blank=True, null=True)
    brand = models.CharField(max_length=100, blank=True, null=True)
    model = models.CharField(max_length=100, blank=True, null=True)
    series = models.CharField(max_length=100, blank=True, null=True)
    risk = models.CharField(max_length=10, choices=RISK_CHOICES, blank=True, null=True)
    location = models.CharField(max_length=100, blank=True, null=True)
    status = models.CharField(max_length=50, blank=True, null=True)
    is_deleted = models.BooleanField(default=False)
    access_token = models.UUIDField(default=uuid.uuid4, unique=False, editable=False)

    def save(self, *args, **kwargs):
        if not self.access_token:
            self.access_token = uuid.uuid4()
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name

class Document(models.Model):
    card = models.ForeignKey(Card, on_delete=models.CASCADE, related_name='documents')
    title = models.CharField(max_length=255)
    file = models.FileField(upload_to='documents/')
    uploaded_at = models.DateTimeField(auto_now_add=True)  # Fecha de carga
    is_deleted = models.BooleanField(default=False)

    def __str__(self):
        return self.title

class Cronograma(models.Model):
    card = models.ForeignKey(Card, on_delete=models.CASCADE, related_name="cronograma")
    date = models.DateField()
    title = models.CharField(max_length=255)
    completed = models.BooleanField(default=False)

class RegistroIntervencion(models.Model):
    card = models.ForeignKey(Card, on_delete=models.CASCADE, related_name="intervenciones")
    action_type = models.CharField(max_length=50, choices=[("correctiva", "Correctiva"), ("preventiva", "Preventiva"), ("calibracion", "Calibración")])
    date = models.DateField()
    description = models.TextField()
    responsible = models.CharField(max_length=255)

class EventHistory(models.Model):
    EVENT_TYPES = [
        ('document_added', 'Documento agregado'),
        ('document_removed', 'Documento eliminado'),
        ('activity_completed', 'Actividad completada'),
        ('activity_pending', 'Actividad pendiente'),
        ('intervention_created', 'Intervención creada'),
        ('status_changed', 'Cambio de estado'),
        ('card_created', 'Tarjeta Creada'),
        ('card_updated', 'Tarjeta Actualizada'),
        ('card_deleted', 'Tarjeta Eliminada'),      
        ('card_restored', 'Tarjeta Restaurada'),    
    ]

    card = models.ForeignKey(Card, on_delete=models.CASCADE, related_name='event_history')
    event_type = models.CharField(max_length=50, choices=EVENT_TYPES)
    description = models.TextField()
    timestamp = models.DateTimeField(default=timezone.now)
    document_file = models.FileField(upload_to='deleted_documents/', null=True, blank=True)

    def __str__(self):
        return f"{self.get_event_type_display()} - {self.card.name} - {self.timestamp}"

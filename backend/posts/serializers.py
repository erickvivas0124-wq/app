from rest_framework import serializers
from .models import Card, Document, Cronograma, RegistroIntervencion, EventHistory

class CardSerializer(serializers.ModelSerializer):
    class Meta:
        model = Card
        fields = ['id', 'name', 'brand', 'model', 'series', 'risk', 'location', 'status', 'image', 'is_deleted']

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        for field, value in ret.items():
            field_instance = self.fields.get(field)
            if value is None and isinstance(field_instance, (serializers.CharField, serializers.ChoiceField)):
                ret[field] = ''
        return ret

class DocumentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Document
        fields = ['id', 'title', 'file', 'uploaded_at']

class CronogramaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Cronograma
        fields = ['id', 'date', 'title', 'card_id', 'completed']

class RegistroIntervencionSerializer(serializers.ModelSerializer):
    action_type = serializers.ChoiceField(choices=RegistroIntervencion._meta.get_field('action_type').choices)

    class Meta:
        model = RegistroIntervencion
        fields = ['id', 'action_type', 'date', 'description', 'responsible', 'card_id']

class EventHistorySerializer(serializers.ModelSerializer):
    event_type_display = serializers.CharField(source='get_event_type_display', read_only=True)
    document_file = serializers.SerializerMethodField()  # Cambiar nombre aquí

    class Meta:
        model = EventHistory
        fields = ['id', 'event_type', 'event_type_display', 'description', 'timestamp', 'card_id', 'document_file']

    def get_document_file(self, obj):
        """
        Retorna la URL del documento según el tipo de evento
        """
        request = self.context.get('request')
        
        if obj.event_type in ['document_added', 'document_removed']:
            if obj.document_file:
                file_path = str(obj.document_file)
                if not file_path.startswith('http'):
                    if not file_path.startswith('/media/'):
                        if file_path.startswith('media/'):
                            file_path = f'/{file_path}'
                        else:
                            file_path = f'/media/{file_path}'
                    
                    if request is not None:
                        return request.build_absolute_uri(file_path)
                    else:
                        return file_path
                else:
                    return file_path
            
            if obj.event_type == 'document_removed':
                description = obj.description
                if 'Documento eliminado:' in description:
                    title = description.replace('Documento eliminado:', '').strip()
                    try:
                        document = Document.objects.filter(
                            card=obj.card, 
                            title=title
                        ).first()
                        if document and document.file:
                            file_path = document.file.url
                            if request is not None:
                                return request.build_absolute_uri(file_path)
                            return file_path
                    except:
                        pass
        
        return None
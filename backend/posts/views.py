from django.shortcuts import render, redirect, get_object_or_404
from .models import Card, Document, RegistroIntervencion, Cronograma, EventHistory
from django.http import JsonResponse, HttpResponse
from django.contrib import messages
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.csrf import ensure_csrf_cookie
from io import BytesIO
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .serializers import CardSerializer, EventHistorySerializer
from rest_framework.decorators import api_view
from rest_framework import viewsets
from rest_framework.decorators import action
import qrcode
import pandas as pd
import logging
import unicodedata

def search_cards(request):
    query = request.GET.get('q', '')  
    filtered_cards = Card.objects.filter(name__icontains=query)  
    cards_data = list(filtered_cards.values('id', 'name', 'brand', 'model', 'status', 'image'))  
    return JsonResponse(cards_data, safe=False)

import logging
from rest_framework.exceptions import APIException

logger = logging.getLogger(__name__)

class CardViewSet(viewsets.ModelViewSet):
    serializer_class = CardSerializer
    queryset = Card.objects.filter(is_deleted=False)

    def get_queryset(self):
        return Card.objects.filter(is_deleted=False)

    def get_object(self):
        if self.action == 'restore':
            return Card.objects.get(pk=self.kwargs['pk'])
        return super().get_object()

    def list(self, request, *args, **kwargs):
        try:
            return super().list(request, *args, **kwargs)
        except Exception as e:
            logger.error(f"Error in CardViewSet list: {e}", exc_info=True)
            raise APIException(f"Failed to load cards: {str(e)}")

    @action(detail=False, methods=['get'])
    def deleted(self, request):
        """List deleted cards"""
        deleted_cards = Card.objects.filter(is_deleted=True)
        serializer = self.get_serializer(deleted_cards, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def soft_delete(self, request, pk=None):
        """Soft delete a card"""
        card = self.get_object()
        card.is_deleted = True
        card.save()
        return Response({'status': 'card soft deleted'})

    @action(detail=True, methods=['post'])
    def restore(self, request, pk=None):
        """Restore a soft deleted card"""
        card = self.get_object()
        card.is_deleted = False
        card.save()
        return Response({'status': 'card restored'})

@api_view(['GET'])
@ensure_csrf_cookie
def get_csrf_token(request):
    return JsonResponse({"detail": "CSRF cookie set"})

from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .serializers import DocumentSerializer, CronogramaSerializer, RegistroIntervencionSerializer

@api_view(['GET'])
def all_cronograma_activities_api(request):
    cronogramas = Cronograma.objects.select_related('card').all()
    serializer = CronogramaSerializer(cronogramas, many=True)
    return Response(serializer.data)

@api_view(['POST'])
def cronograma_create_api(request):
    serializer = CronogramaSerializer(data=request.data)
    if serializer.is_valid():
        card_id = request.data.get('card_id')
        if not card_id:
            return Response({'card_id': 'This field is required.'}, status=status.HTTP_400_BAD_REQUEST)
        serializer.save(card_id=card_id)
        # Log event
        card = Card.objects.get(id=card_id)
        title = serializer.data.get('title', '')
        EventHistory.objects.create(
            card=card,
            event_type='activity_pending',
            description=f'Actividad "{title}" creada para el cronograma.',
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['PUT', 'POST'])
def cronograma_update_api(request, cronograma_id):
    try:
        cronograma = Cronograma.objects.get(id=cronograma_id)
    except Cronograma.DoesNotExist:
        return Response({'detail': 'Cronograma not found.'}, status=status.HTTP_404_NOT_FOUND)

    old_completed = cronograma.completed

    serializer = CronogramaSerializer(cronograma, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        new_completed = serializer.data.get('completed', old_completed)
        if new_completed != old_completed:
            card = cronograma.card
            status_str = 'completada' if new_completed else 'pendiente'
            EventHistory.objects.create(
                card=card,
                event_type='activity_completed' if new_completed else 'activity_pending',
                description=f'Actividad "{cronograma.title}" marcada como {status_str}.',
            )
        return Response(serializer.data, status=status.HTTP_200_OK)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
def intervencion_create_api(request):
    serializer = RegistroIntervencionSerializer(data=request.data)
    if serializer.is_valid():
        card_id = request.data.get('card_id')
        if not card_id:
            return Response({'card_id': 'This field is required.'}, status=status.HTTP_400_BAD_REQUEST)
        serializer.save(card_id=card_id)
        # Log event
        card = Card.objects.get(id=card_id)
        EventHistory.objects.create(
            card=card,
            event_type='intervention_created',
            description=f'Intervención creada: {serializer.data.get("description", "")}',
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET', 'POST'])
def home_api(request):
    if request.method == 'POST':
        serializer = CardSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    cards = Card.objects.all()
    serializer = CardSerializer(cards, many=True)
    return Response(serializer.data)

@api_view(['GET'])
def card_detail_api(request, card_id):
    access_token = request.GET.get('access_token')
    try:
        card = Card.objects.get(id=card_id)
    except Card.DoesNotExist:
        return Response(status=status.HTTP_404_NOT_FOUND)

    if not access_token or str(card.access_token) != access_token:
        return Response({'detail': 'Unauthorized'}, status=status.HTTP_401_UNAUTHORIZED)

    serializer = CardSerializer(card)
    return Response(serializer.data)

@api_view(['GET', 'POST'])
def card_documents_api(request, card_id):
    try:
        card = Card.objects.get(id=card_id)
    except Card.DoesNotExist:
        return Response(status=status.HTTP_404_NOT_FOUND)

    if request.method == 'POST':
        serializer = DocumentSerializer(data=request.data)
        if serializer.is_valid():
            document = serializer.save(card=card)
            EventHistory.objects.create(
                card=card,
                event_type='document_added',
                description=f'Documento agregado: {document.title}',
                document_file=document.file.url if document.file else None,  # Guardar URL completa
            )
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    documents = card.documents.filter(is_deleted=False)
    serializer = DocumentSerializer(documents, many=True)
    return Response(serializer.data)

@api_view(['GET'])
def card_maintenance_api(request, card_id):
    try:
        card = Card.objects.get(id=card_id)
    except Card.DoesNotExist:
        return Response(status=status.HTTP_404_NOT_FOUND)

    cronogramas = card.cronograma.all()
    intervenciones = card.intervenciones.all()

    cronograma_serializer = CronogramaSerializer(cronogramas, many=True)
    intervencion_serializer = RegistroIntervencionSerializer(intervenciones, many=True)

    return Response({
        'cronogramas': cronograma_serializer.data,
        'intervenciones': intervencion_serializer.data,
    })

def card_detail(request, card_id):
    card = get_object_or_404(Card, id=card_id)
    return render(request, 'posts/card_detail.html', {
        'card': card,
        'page_title': 'Detalles del equipo',  
    })

def card_documents(request, card_id):
    card = get_object_or_404(Card, id=card_id)
    return render(request, 'posts/card_documents.html', {
        'card': card,
        'page_title': 'Documentos',})

def card_history(request, card_id):
    card = get_object_or_404(Card, id=card_id)
    return render(request, 'posts/card_history.html', {'card': card, 'page_title': 'Historia',})

@api_view(['GET'])
def card_history_api(request, card_id):
    card = get_object_or_404(Card, id=card_id)
    events = EventHistory.objects.filter(card=card).order_by('-timestamp')
    serializer = EventHistorySerializer(events, many=True, context={'request': request})  # Agregar contexto
    return Response(serializer.data)

def card_maintenance(request, card_id):
    card = get_object_or_404(Card, id=card_id)

    if request.method == "POST":
        form_type = request.POST.get("type")

        if form_type == "cronograma":
            date = request.POST.get("date")
            title = request.POST.get("title")
            if date and title:
                Cronograma.objects.create(card=card, date=date, title=title)

        elif form_type == "intervenciones":
            action_type = request.POST.get("action_type")
            date = request.POST.get("date")
            description = request.POST.get("description")
            responsible = request.POST.get("responsible")
            if action_type and date and description and responsible:
                RegistroIntervencion.objects.create(
                    card=card, 
                    action_type=action_type, 
                    date=date, 
                    description=description, 
                    responsible=responsible
                )

        return redirect("card_maintenance", card_id=card.id)

    cronogramas = card.cronograma.all()
    intervenciones = card.intervenciones.all()

    location_value = card.location if card.location else ""

    return render(request, "posts/card_maintenance.html", {
        "card": card,
        "cronogramas": cronogramas,
        "intervenciones": intervenciones,
        "location_value": location_value,
        "page_title": "Mantenimiento",
    })


def card_documents(request, card_id):
    card = get_object_or_404(Card, id=card_id)
    documents = card.documents.all() 

    if request.method == 'POST' and 'title' in request.POST:
        title = request.POST.get('title')
        file = request.FILES.get('file')
        if title and file:
            Document.objects.create(card=card, title=title, file=file)
            return redirect('card_documents', card_id=card.id)

    return render(request, 'posts/card_documents.html', {'card': card, 'documents': documents, 'page_title': 'Documentos',})

from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def delete_document(request, document_id):
    document = get_object_or_404(Document, id=document_id)
    card_id = document.card.id
    if request.method == 'POST':
        EventHistory.objects.create(
            card=document.card,
            event_type='document_removed',
            description=f'Documento eliminado: {document.title}',
            document_file=document.file.url if document.file else None,  
        )
        document.is_deleted = True
        document.save()
        return redirect('card_documents', card_id=card_id)
    return redirect('card_documents', card_id=card_id)

def usuario(request):
    return render(request, 'posts/usuario.html', {'page_title': 'Usuario'})

def guardar_usuario(request):
    if request.method == 'POST':
        first_name = request.POST.get('first_name')
        last_name = request.POST.get('last_name')
        role = request.POST.get('role')
        email = request.POST.get('email')


        messages.success(request, "Usuario guardado exitosamente.")
        return redirect('usuario') 

    return render(request, 'usuario.html', {'page_title': 'Usuario'})

def cronograma(request):
    return render(request, 'posts/cronograma.html', {'page_title': 'Cronograma'})

def generate_qr(request, card_id):
    card = get_object_or_404(Card, id=card_id)
    card_url = request.build_absolute_uri(f"/card_detail/{card.id}/?access_token={card.access_token}")

    qr = qrcode.make(card_url)
    buffer = BytesIO()
    qr.save(buffer, format="PNG")
    buffer.seek(0)

    return HttpResponse(buffer, content_type="image/png")

def some_view(request, card_id):
    card = get_object_or_404(Card, id=card_id)
    return render(request, 'card_detail.html', {'card': card})

from django.views.decorators.csrf import csrf_exempt

import logging
logger = logging.getLogger(__name__)

from rest_framework.decorators import api_view
from rest_framework.response import Response

@csrf_exempt
@api_view(['POST'])
def toggle_status(request, card_id):
    """ Alterna el estado de la tarjeta entre 'Activo' y 'Fuera de servicio' """
    try:
        card = get_object_or_404(Card, id=card_id)
        old_status = card.status
        card.status = "Activo" if card.status == "Fuera de servicio" else "Fuera de servicio"
        card.save()
        # Log event
        EventHistory.objects.create(
            card=card,
            event_type='status_changed',
            description=f'Estado cambiado de "{old_status}" a "{card.status}"',
        )
        return Response({'status': card.status}, status=200)
    except Exception as e:
        logger.error(f"Error toggling card status: {e}", exc_info=True)
        return Response({'error': str(e)}, status=500)

def edit_card(request, card_id):
    """ Vista para editar una tarjeta """
    card = get_object_or_404(Card, id=card_id)
    if request.method == "POST":
        card.name = request.POST['name']
        card.brand = request.POST['brand']
        card.model = request.POST['model']
        card.series = request.POST['series']
        card.status = request.POST['status']
        card.save()
        messages.success(request, "Tarjeta actualizada correctamente.")
        return redirect('card_detail', card_id=card.id)
    return render(request, 'posts/edit_card.html', {'card': card, 'page_title': 'Editar Tarjeta'}) 

def delete_card(request, card_id):
    """ Elimina una tarjeta después de confirmación """
    card = get_object_or_404(Card, id=card_id)
    card.delete()
    messages.success(request, "Tarjeta eliminada correctamente.")
    return redirect('home')  

def card_maintenance(request, card_id):
    card = get_object_or_404(Card, id=card_id)

    if request.method == "POST":
        form_type = request.POST.get("type")

        if form_type == "cronograma":
            date = request.POST.get("date")
            title = request.POST.get("title")
            if date and title:
                Cronograma.objects.create(card=card, date=date, title=title)
                EventHistory.objects.create(
                    card=card,
                    event_type='activity_pending',
                    description=f'Actividad "{title}" creada para el cronograma.',
                )

        elif form_type == "intervenciones":
            action_type = request.POST.get("action_type")
            date = request.POST.get("date")
            description = request.POST.get("description")
            responsible = request.POST.get("responsible")
            if action_type and date and description and responsible:
                RegistroIntervencion.objects.create(
                    card=card, 
                    action_type=action_type, 
                    date=date, 
                    description=description, 
                    responsible=responsible
                )
                # Log event
                EventHistory.objects.create(
                    card=card,
                    event_type='intervention_created',
                    description=f'Intervención "{action_type}" creada: {description}',
                )

        return redirect("card_maintenance", card_id=card.id)

    cronogramas = Cronograma.objects.filter(card=card)
    intervenciones = RegistroIntervencion.objects.filter(card=card)

    return render(request, "posts/card_maintenance.html", {
        "card": card,
        "cronogramas": cronogramas,
        "intervenciones": intervenciones,
        "page_title": "Mantenimiento",
    })

def normalize_column(col):
    col = unicodedata.normalize('NFD', str(col)).encode('ascii', 'ignore').decode('ascii')
    return col.lower().strip()

@csrf_exempt
@api_view(['POST'])
def import_cards_from_excel(request):
    """
    API endpoint to import cards from an uploaded Excel file.
    Expects an Excel file with columns:
    'equipo biomedico', 'marca', 'modelo', 'serie', 'clasificacion por riesgo', 'ubicacion'
    Extra columns are ignored.
    If any required column is missing, returns an error.
    """
    required_columns = ['Equipo biomedico', 'Marca', 'Modelo', 'Serie', 'Clasificacion por riesgo', 'Ubicacion']

    logger.info(f"Request method: {request.method}")
    logger.info(f"Request FILES: {request.FILES}")
    if 'file' not in request.FILES:
        logger.error("No file uploaded.")
        return Response({'error': 'No file uploaded.'}, status=status.HTTP_400_BAD_REQUEST)

    excel_file = request.FILES['file']
    logger.info(f"Excel file: {excel_file.name}, size: {excel_file.size}")

    try:
        df_temp = pd.read_excel(excel_file, header=None)
        logger.info(f"Raw DataFrame shape: {df_temp.shape}")
        logger.info(f"Raw DataFrame preview:\n{df_temp.head(10)}")

        header_row = None
        required_lower = [normalize_column(col) for col in required_columns]

        for idx in range(min(30, len(df_temp))):  # Check first 30 rows
            row = df_temp.iloc[idx]
            row_values = [normalize_column(str(val)) for val in row.values if pd.notna(val)]
            logger.info(f"Row {idx} values normalized: {row_values}")
            if all(req in row_values for req in required_lower):
                header_row = idx
                logger.info(f"Found header row at index: {header_row}")
                break

        if header_row is None:
            logger.error("Could not find header row containing required columns")
            return Response({'error': 'Could not find header row containing required columns in the Excel file. Please ensure the header row has the columns: ' + ', '.join(required_columns)}, status=status.HTTP_400_BAD_REQUEST)

        df = pd.read_excel(excel_file, header=header_row)
        logger.info(f"DataFrame shape after header detection: {df.shape}")
        logger.info(f"DataFrame columns: {list(df.columns)}")
    except Exception as e:
        logger.error(f"Error reading Excel file: {str(e)}")
        return Response({'error': f'Error reading Excel file: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)

    required_columns = ['Equipo biomedico', 'Marca', 'Modelo', 'Serie', 'Clasificacion por riesgo', 'Ubicacion']
    df_columns_normalized = [str(col).lower().strip() for col in df.columns]

    missing_columns = [col for col in required_columns if col.lower().strip() not in df_columns_normalized]

    if missing_columns:
        logger.error(f"Missing required columns detected: {missing_columns}")
        logger.error(f"DataFrame columns: {list(df.columns)}")
        return Response({'error': f'Missing required columns: {", ".join(missing_columns)}'}, status=status.HTTP_400_BAD_REQUEST)

    column_map = {normalize_column(col): col for col in df.columns}

    created_cards = []
    skipped_cards = []
    errors = []

    for index, row in df.iterrows():
        try:
            name_val = str(row[column_map.get('equipo biomedico', '')]).strip()
            model_val = str(row[column_map.get('modelo', '')]).strip()
            series_val = str(row[column_map.get('serie', '')]).strip()

            existing_card = Card.objects.filter(
                name__iexact=name_val,
                model__iexact=model_val,
                series__iexact=series_val
            ).first()

            if existing_card:
                skipped_cards.append({
                    'row': index + 2,
                    'name': name_val,
                    'reason': 'Duplicate card (same name, model, and series already exists)'
                })
                continue

            risk_col_key = None
            for key in column_map.keys():
                if key == 'clasificacion por riesgo':
                    risk_col_key = key
                    break

            risk_value = row[column_map[risk_col_key]] if risk_col_key else None

            card = Card(
                name=row[column_map.get('equipo biomedico', '')],
                brand=row[column_map.get('marca', '')],
                model=row[column_map.get('modelo', '')],
                series=row[column_map.get('serie', '')],
                risk=risk_value,
                location=row[column_map.get('ubicacion', '')],
                status='Activo'  
            )
            card.save()
            created_cards.append(card.id)
            EventHistory.objects.create(
                card=card,
                event_type='card_created',
                description=f'Tarjeta creada desde importación Excel: {card.name}',
            )
        except Exception as e:
            errors.append({'row': index + 2, 'error': str(e)})  

    response_data = {
        'created_cards_count': len(created_cards),
        'created_card_ids': created_cards,
        'skipped_cards_count': len(skipped_cards),
        'skipped_cards': skipped_cards,
        'errors': errors,
    }

    return Response(response_data, status=status.HTTP_201_CREATED)

@api_view(['GET'])
def export_cards_to_excel(request):
    """
    API endpoint to export all cards to an Excel file.
    Returns an Excel file with columns: 'Equipo biomedico', 'Marca', 'Modelo', 'Serie', 'Clasificacion por riesgo', 'Ubicacion'
    """
    try:
        cards = Card.objects.all()

        data = []
        for card in cards:
            data.append({
                'Equipo biomedico': card.name,
                'Marca': card.brand,
                'Modelo': card.model,
                'Serie': card.series,
                'Clasificacion por riesgo': card.risk,
                'Ubicacion': card.location
            })

        df = pd.DataFrame(data)

        from io import BytesIO
        buffer = BytesIO()
        with pd.ExcelWriter(buffer, engine='openpyxl') as writer:
            df.to_excel(writer, sheet_name='Cards', index=False)

        buffer.seek(0)

        response = HttpResponse(
            buffer.getvalue(),
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        )
        response['Content-Disposition'] = 'attachment; filename=cards_export.xlsx'

        return response

    except Exception as e:
        logger.error(f"Error exporting cards to Excel: {str(e)}", exc_info=True)
        return Response({'error': f'Error exporting cards: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

def maintenance_info(request, item_id):
    cronograma = Cronograma.objects.filter(id=item_id).first()
    intervencion = RegistroIntervencion.objects.filter(id=item_id).first()

    contexto = {
        'item': cronograma if cronograma else intervencion,
        'page_title': 'Detalles de Mantenimiento'
    }

    return render(request, 'posts/maintenance_info.html', contexto)



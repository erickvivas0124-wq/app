from django.urls import path, include
from . import views
from .views import toggle_status, edit_card, delete_card, CardViewSet, get_csrf_token, import_cards_from_excel, export_cards_to_excel
from rest_framework.routers import DefaultRouter
from rest_framework.decorators import action

router = DefaultRouter()
router.register(r'cards', CardViewSet)

urlpatterns = [
    path('', views.home_api, name='home_api'),
    path('card/<int:card_id>/', views.card_detail_api, name='card_detail_api'),
    path('card/<int:card_id>/documents/', views.card_documents_api, name='card_documents_api'),
    path('card/<int:card_id>/maintenance/', views.card_maintenance_api, name='card_maintenance_api'),

    path('search/', views.search_cards, name='search_cards'),
    path('card/<int:card_id>/history/', views.card_history, name='card_history'),
    path('card/<int:card_id>/history/api/', views.card_history_api, name='card_history_api'),
    path('document/<int:document_id>/delete/', views.delete_document, name='delete_document'),
    path('usuario/', views.usuario, name='usuario'),
    path('usuario/guardar/', views.guardar_usuario, name='guardar_usuario'),
    path('cronograma/', views.cronograma, name='cronograma'),
    path('generate_qr/<int:card_id>/', views.generate_qr, name='generate_qr'),
    path('toggle_status/<int:card_id>/', toggle_status, name='toggle_status'),
    path('edit_card/<int:card_id>/', edit_card, name='edit_card'),
    path('delete_card/<int:card_id>/', delete_card, name='delete_card'),
    path('maintenance/<int:item_id>/', views.maintenance_info, name='maintenance_info'),
    path('api/cronograma/create/', views.cronograma_create_api, name='cronograma-create'),
    path('api/intervencion/create/', views.intervencion_create_api, name='intervencion-create'),
    path('api/cronograma/<int:cronograma_id>/update/', views.cronograma_update_api, name='cronograma-update'),
    path('api/cronograma/all/', views.all_cronograma_activities_api, name='all-cronograma-activities'),
    
    # API routes for Flutter frontend
    path('', include(router.urls)),
    path('get-csrf-token/', get_csrf_token, name='get-csrf-token'),
    path('import_cards_from_excel/', import_cards_from_excel, name='import-cards-from-excel'),
    path('export_cards_to_excel/', export_cards_to_excel, name='export-cards-to-excel'),
]

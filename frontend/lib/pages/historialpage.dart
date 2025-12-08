 import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/custom_detail_bottom_bar.dart';
import '../widgets/custom_app_bar.dart';
import '../main.dart';

class EventHistory {
  final int id;
  final String eventType;
  final String eventTypeDisplay;
  final String description;
  final DateTime timestamp;
  final int cardId;
  final String? documentFile;  

  EventHistory({
    required this.id,
    required this.eventType,
    required this.eventTypeDisplay,
    required this.description,
    required this.timestamp,
    required this.cardId,
    this.documentFile,
  });

  factory EventHistory.fromJson(Map<String, dynamic> json) {
    return EventHistory(
      id: json['id'],
      eventType: json['event_type'],
      eventTypeDisplay: json['event_type_display'],
      description: json['description'],
      timestamp: DateTime.parse(json['timestamp']).toLocal(),
      cardId: json['card_id'],
      documentFile: json['document_file'],  
    );
  }
}

class Card {
  final int id;
  final String name;
  final String brand;
  final String model;
  final String series;
  final String status;
  final String? image;

  Card({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.series,
    required this.status,
    this.image,
  });

  factory Card.fromJson(Map<String, dynamic> json) {
    return Card(
      id: json['id'],
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      series: json['series'] ?? '',
      status: json['status'] ?? '',
      image: json['image'],
    );
  }
}

class ApiService {
  static const String baseUrl = 'http://192.168.1.4:8000'; 

  static Future<List<EventHistory>> getCardHistory(int cardId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/card/$cardId/history/api/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => EventHistory.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar el historial: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<Card> getCard(int cardId) async {
    try {

      return Card(
        id: cardId,
        name: 'Historial',
        brand: '',
        model: '',
        series: '',
        status: '',
        image: null,
      );
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}

class CardHistoryPage extends StatefulWidget {
  final int cardId;

  const CardHistoryPage({Key? key, required this.cardId}) : super(key: key);

  @override
  State<CardHistoryPage> createState() => _CardHistoryPageState();
}

class _CardHistoryPageState extends State<CardHistoryPage> {
  List<EventHistory> events = [];
  List<EventHistory> filteredEvents = [];
  Card? card;
  bool isLoading = true;
  String? error;
  
  final TextEditingController _searchController = TextEditingController();
  String? selectedEventType;
  List<String> availableEventTypes = [];

  @override
  void initState() {
    super.initState();
    loadData();
    _searchController.addListener(_filterEvents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final cardData = await ApiService.getCard(widget.cardId);
      final historyData = await ApiService.getCardHistory(widget.cardId);
      
      final eventTypes = historyData.map((e) => e.eventTypeDisplay).toSet().toList();
      eventTypes.sort();
      
      setState(() {
        card = cardData;
        events = historyData;
        filteredEvents = historyData;
        availableEventTypes = eventTypes;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _filterEvents() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      filteredEvents = events.where((event) {
        final matchesSearch = query.isEmpty ||
            event.description.toLowerCase().contains(query) ||
            event.eventTypeDisplay.toLowerCase().contains(query);
        
        final matchesType = selectedEventType == null ||
            event.eventTypeDisplay == selectedEventType;
        
        return matchesSearch && matchesType;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      selectedEventType = null;
      filteredEvents = events;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        pageTitle: card?.name ?? 'Historial de Eventos',
        showBackButton: true,
        onBackPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CardDetailPage(cardId: widget.cardId),
            ),
          );
        },
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          
          Expanded(
            child: _buildEventsList(),
          ),
        ],
      ),
      bottomNavigationBar: CustomDetailBottomBar(
        cardId: card?.id ?? 0,
        currentPage: '/card_history/${card?.id ?? 0}',
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: loadData,
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.refresh, color: Colors.white),
        tooltip: 'Actualizar historial',
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar en el historial...',
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue[700]!),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedEventType,
                      hint: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Filtrar por tipo'),
                      ),
                      icon: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Todos los tipos'),
                          ),
                        ),
                        ...availableEventTypes.map((type) => DropdownMenuItem<String>(
                          value: type,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _getEventColorByDisplay(type),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(type),
                              ],
                            ),
                          ),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedEventType = value;
                        });
                        _filterEvents();
                      },
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: IconButton(
                  onPressed: _clearFilters,
                  icon: Icon(Icons.clear_all, color: Colors.grey[700]),
                  tooltip: 'Limpiar filtros',
                ),
              ),
            ],
          ),
          
          if (!isLoading && error == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filteredEvents.length} de ${events.length} eventos',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando historial...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error al cargar el historial',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loadData,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay eventos registrados',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Los eventos aparecerán aquí cuando se realicen cambios en la tarjeta',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (filteredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No se encontraron eventos',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta ajustar los filtros de búsqueda',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearFilters,
              child: const Text('Limpiar filtros'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredEvents.length,
        itemBuilder: (context, index) {
          final event = filteredEvents[index];
          return _buildEventItem(event, index == 0);
        },
      ),
    );
  }

 Widget _buildEventItem(EventHistory event, bool isFirst) {
  return GestureDetector(
    onTap: () {
      _showEventDetailsDialog(event);
    },
    child: Container(
      margin: EdgeInsets.only(bottom: isFirst ? 16 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getEventColor(event.eventType),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              if (!isFirst)
                Container(
                  width: 2,
                  height: 60,
                  color: Colors.grey[300],
                ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getEventColor(event.eventType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      event.eventTypeDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getEventColor(event.eventType),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  _buildEventDescription(event),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(event.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
Widget _buildEventDescription(EventHistory event) {
  if (event.eventType == 'document_added') {
    return TextButton(
      onPressed: () => _handleDocumentAction(event, isRemoved: false),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(Icons.description, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              event.description,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  } else if (event.eventType == 'document_removed') {
    return Row(
      children: [
        Icon(Icons.delete_outline, size: 16, color: Colors.red[400]),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.description,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  'Oprima para ver el documento',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  } else {
    return Text(
      event.description,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
Future<void> _handleDocumentAction(EventHistory event, {required bool isRemoved}) async {
  if (isRemoved) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Documento eliminado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Este documento fue eliminado y ya no está disponible.'),
            const SizedBox(height: 12),
            Text(
              'Detalles del documento:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('• ${event.description}'),
            Text('• Eliminado: ${_formatDateTime(event.timestamp)}'),
            if (event.documentFile != null) 
              Text('• Ruta original: ${event.documentFile}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
    return;
  }

  final url = event.documentFile;
  if (url == null || url.isEmpty) {
    _showErrorSnackBar('No se encontró la URL del documento');
    return;
  }

  try {
    String fullUrl = url;
    if (!url.startsWith('http')) {
      if (!url.startsWith('/media')) {
        fullUrl = '${ApiService.baseUrl}/media/$url';
      } else {
        fullUrl = '${ApiService.baseUrl}$url';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Abriendo documento...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final launched = await launchUrl(
      Uri.parse(fullUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      _showErrorSnackBar('No se pudo abrir el documento');
    }
  } catch (e) {
    print('Error al abrir documento: $e');
    _showErrorSnackBar('Error al abrir el documento: ${e.toString()}');
  }
}
void _showErrorSnackBar(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.red[600],
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    ),
  );
}
  void _showEventDetailsDialog(EventHistory event) {
    showDialog(
      context: context,
      builder: (context) {
        String dialogTitle = event.eventTypeDisplay;
        if (event.eventType == 'intervention_created') {
         dialogTitle = 'Intervencion creada'; 
        }
        return AlertDialog(
        title: Text(dialogTitle), 
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.eventType == 'activity_completed' || event.eventType == 'activity_pending' || event.eventType == 'intervention_created') ...[
                Text('Hora: ${DateFormat('HH:mm').format(event.timestamp)}'),
                SizedBox(height: 8),
 
                Text('Fecha: ${DateFormat('dd/MM/yyyy').format(event.timestamp)}'),
              ] else if (event.eventType == 'document_added' || event.eventType == 'document_removed') ...[
                Text(event.description),
                if (event.documentFile != null)
                  TextButton(
                    onPressed: () {
                      final url = event.documentFile;
                      if (url != null && url.isNotEmpty) {
                        launchUrl(Uri.parse(url));
                      }
                    },
                    child: Text('Ver documento'),
                  ),
              ] else ...[
                Text(event.description),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'document_added':
      case 'document_removed':
        return Colors.blue;
      case 'activity_completed':
      case 'activity_pending':
        return Colors.orange;
      case 'intervention_created':
        return Colors.green;
      case 'status_changed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getEventColorByDisplay(String eventTypeDisplay) {
    final event = events.firstWhere(
      (e) => e.eventTypeDisplay == eventTypeDisplay,
      orElse: () => EventHistory(
        id: 0,
        eventType: 'unknown',
        eventTypeDisplay: eventTypeDisplay,
        description: '',
        timestamp: DateTime.now(),
        cardId: 0,
      ),
    );
    return _getEventColor(event.eventType);
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Hace un momento';
        }
        return 'Hace ${difference.inMinutes} min';
      }
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Ayer ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }
}
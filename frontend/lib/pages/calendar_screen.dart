import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_app_bar.dart';

class CalendarApiConfig {
  static const String baseUrl = 'http://192.168.1.4:8000';
  static const String allCronogramaEndpoint = '/api/cronograma/all/';
}

class CronogramaEventoWithCard {
  final int id;
  final String title;
  final DateTime date;
  final int cardId;
  final bool completed;
  final String? cardName;
  final String? cardLocation; 

  CronogramaEventoWithCard({
    required this.id,
    required this.title,
    required this.date,
    required this.cardId,
    this.completed = false,
    this.cardName,
    this.cardLocation,
  });

  factory CronogramaEventoWithCard.fromJson(Map<String, dynamic> json) {
    return CronogramaEventoWithCard(
      id: json['id'],
      title: json['title'],
      date: DateTime.parse(json['date']),
      cardId: json['card_id'],
      completed: json['completed'] ?? false,
      cardName: json['card_name'] ?? json['card']?['name'],
      cardLocation: json['card_location'] ?? json['card']?['location'],
    );
  }

  bool get isOverdue => !completed && date.isBefore(DateTime.now());
  bool get isPending => !completed && !date.isBefore(DateTime.now());
  bool get isToday => DateUtils.isSameDay(date, DateTime.now());
}

class CalendarApiService {
  static Future<List<CronogramaEventoWithCard>> getAllCronogramaActivities() async {
    try {
      final response = await http.get(
        Uri.parse('${CalendarApiConfig.baseUrl}${CalendarApiConfig.allCronogramaEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((item) => CronogramaEventoWithCard.fromJson(item)).toList();
      } else {
        throw Exception('Error al cargar actividades: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  List<CronogramaEventoWithCard> _allActivities = [];
  Map<DateTime, List<CronogramaEventoWithCard>> _eventsMap = {};
  List<CronogramaEventoWithCard> _selectedEvents = [];
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadAllActivities();
  }

  Future<void> _loadAllActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final activities = await CalendarApiService.getAllCronogramaActivities();
      
      setState(() {
        _allActivities = activities;
        _eventsMap = _groupEventsByDate(activities);
        _selectedEvents = _getEventsForDay(_selectedDay ?? DateTime.now());
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<DateTime, List<CronogramaEventoWithCard>> _groupEventsByDate(
      List<CronogramaEventoWithCard> activities) {
    Map<DateTime, List<CronogramaEventoWithCard>> eventsMap = {};
    
    for (var activity in activities) {
      final date = DateTime(activity.date.year, activity.date.month, activity.date.day);
      if (eventsMap[date] == null) {
        eventsMap[date] = [];
      }
      eventsMap[date]!.add(activity);
    }
    
    return eventsMap;
  }

  List<CronogramaEventoWithCard> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _eventsMap[date] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        pageTitle: 'Calendario',
        showBackButton: true,
        onBackPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        },
      ),
      body: Column(
        children: [
          if (!_isLoading && _errorMessage == null) _buildQuickStats(),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _buildCalendarContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadAllActivities,
        tooltip: 'Actualizar calendario',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildQuickStats() {
    final today = DateTime.now();
    final todayActivities = _getEventsForDay(today);
    final overdueCount = _allActivities.where((a) => a.isOverdue).length;
    final completedCount = _allActivities.where((a) => a.completed).length;
    final pendingCount = _allActivities.where((a) => a.isPending).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Text(
            'Resumen de Actividades',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Hoy', todayActivities.length.toString(), Colors.blue),
              _buildStatItem('Vencidas', overdueCount.toString(), Colors.red),
              _buildStatItem('Pendientes', pendingCount.toString(), Colors.orange),
              _buildStatItem('Completadas', completedCount.toString(), Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
              color: Colors.grey[600],
          ),
        ),
      ],
    );
  }


  Widget _buildCalendarContent() {
    return RefreshIndicator(
      onRefresh: _loadAllActivities,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TableCalendar<CronogramaEventoWithCard>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                eventLoader: _getEventsForDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(color: Colors.red[600]),
                  holidayTextStyle: TextStyle(color: Colors.red[600]),
                  todayDecoration: BoxDecoration(
                    color: Colors.deepOrange[400],
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Colors.blue[300],
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 3,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                ),
                onDaySelected: _onDaySelected,
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    if (events.isNotEmpty) {
                      return _buildEventMarkers(events.cast<CronogramaEventoWithCard>());
                    }
                    return null;
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            _buildSelectedDayEvents(),
          ],
        ),
      ),
    );
  }

  Widget _buildEventMarkers(List<CronogramaEventoWithCard> events) {
    if (events.isEmpty) return const SizedBox();
    
    final hasOverdue = events.any((e) => e.isOverdue);
    final hasCompleted = events.any((e) => e.completed);
    final hasPending = events.any((e) => e.isPending);
    
    Color markerColor;
    if (hasOverdue) {
      markerColor = Colors.red;
    } else if (hasPending) {
      markerColor = Colors.orange;
    } else if (hasCompleted) {
      markerColor = Colors.green;
    } else {
      markerColor = Colors.blue;
    }
    
    return Positioned(
      right: 1,
      bottom: 1,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: markerColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${events.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDayEvents() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _selectedDay != null
                  ? 'Actividades para ${DateFormat('dd MMMM yyyy', 'es_ES').format(_selectedDay!)}'
                  : 'Selecciona un día',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          if (_selectedEvents.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              child: const Center(
                child: Text(
                  'No hay actividades programadas para este día',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedEvents.length,
              itemBuilder: (context, index) {
                return _buildActivityCard(_selectedEvents[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(CronogramaEventoWithCard activity) {
    Color cardColor;
    Color textColor;
    IconData statusIcon;
    
    if (activity.completed) {
      cardColor = Colors.green[50]!;
      textColor = Colors.green[800]!;
      statusIcon = Icons.check_circle;
    } else if (activity.isOverdue) {
      cardColor = Colors.red[50]!;
      textColor = Colors.red[800]!;
      statusIcon = Icons.warning;
    } else {
      cardColor = Colors.white;
      textColor = Colors.black87;
      statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              statusIcon,
              color: textColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      decoration: activity.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  if (activity.cardName != null)
                    Row(
                      children: [
                        Icon(
                          Icons.card_membership,
                          size: 14,
                          color: textColor.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tarjeta: ${activity.cardName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  
                  if (activity.cardLocation != null)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: textColor.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activity.cardLocation!,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  
                  if (activity.isOverdue && !activity.completed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'VENCIDA',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ver tarjeta ${activity.cardId}'),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_ios),
              iconSize: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar el calendario',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAllActivities,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
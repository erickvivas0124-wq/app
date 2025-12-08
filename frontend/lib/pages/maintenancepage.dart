import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_detail_bottom_bar.dart';
import '../widgets/custom_app_bar.dart';
import '../main.dart' as main_app;

class ApiConfig {
  static const String baseUrl = 'http://192.168.1.4:8000';
  static String getMaintenanceEndpoint(int cardId) => '/card/$cardId/maintenance/';
  
  static const String createCronogramaEndpoint = '/api/cronograma/create/';
  static const String createIntervencionEndpoint = '/api/intervencion/create/';
  
  static String updateCronogramaEndpoint(int cronogramaId) => '/api/cronograma/$cronogramaId/update/';
}

class CronogramaEvento {
  final int id;
  final String title;
  final DateTime date;
  final int cardId;
  final bool completed; 

  CronogramaEvento({
    required this.id,
    required this.title,
    required this.date,
    required this.cardId,
    this.completed = false, 
  });

  factory CronogramaEvento.fromJson(Map<String, dynamic> json) {
    return CronogramaEvento(
      id: json['id'],
      title: json['title'],
      date: DateTime.parse(json['date']),
      cardId: json['card_id'],
      completed: json['completed'] ?? false, 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'date': date.toIso8601String().split('T')[0],
      'card_id': cardId,
      'completed': completed, 
    };
  }

  CronogramaEvento copyWith({
    int? id,
    String? title,
    DateTime? date,
    int? cardId,
    bool? completed,
  }) {
    return CronogramaEvento(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      cardId: cardId ?? this.cardId,
      completed: completed ?? this.completed,
    );
  }

  bool get isOverdue => !completed && date.isBefore(DateTime.now());
  bool get isPending => !completed && !date.isBefore(DateTime.now());
  bool get isCompletedOrOverdue => completed || isOverdue;
}

class Intervencion {
  final int id;
  final String actionType;
  final DateTime date;
  final String description;
  final String responsible;
  final int cardId;

  Intervencion({
    required this.id,
    required this.actionType,
    required this.date,
    required this.description,
    required this.responsible,
    required this.cardId,
  });

  factory Intervencion.fromJson(Map<String, dynamic> json) {
    return Intervencion(
      id: json['id'],
      actionType: json['action_type'],
      date: DateTime.parse(json['date']),
      description: json['description'],
      responsible: json['responsible'],
      cardId: json['card_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action_type': actionType,
      'date': date.toIso8601String().split('T')[0],
      'description': description,
      'responsible': responsible,
      'card_id': cardId,
    };
  }
}

class ApiService {
  static Future<Map<String, dynamic>> getMaintenanceData(int cardId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getMaintenanceEndpoint(cardId)}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        
        List<CronogramaEvento> cronogramas = [];
        List<Intervencion> intervenciones = [];
        
        if (data['cronogramas'] != null) {
          cronogramas = (data['cronogramas'] as List)
              .map((item) => CronogramaEvento.fromJson({
                ...item,
                'card_id': item['card_id'] ?? cardId,
              }))
              .toList();
        }
        
        if (data['intervenciones'] != null) {
          intervenciones = (data['intervenciones'] as List)
              .map((item) => Intervencion.fromJson({
                ...item,
                'card_id': item['card_id'] ?? cardId,
              }))
              .toList();
        }
        
        return {
          'cronogramas': cronogramas,
          'intervenciones': intervenciones,
        };
      } else {
        throw Exception('Error al cargar datos de mantenimiento: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<CronogramaEvento> createCronograma(CronogramaEvento cronograma) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.createCronogramaEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(cronograma.toJson()),
      );

      if (response.statusCode == 201) {
        return CronogramaEvento.fromJson(json.decode(response.body));
      } else {
        print('Error response: ${response.body}');
        throw Exception('Error al crear cronograma: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception creating cronograma: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<CronogramaEvento> updateCronogramaStatus(CronogramaEvento cronograma) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.updateCronogramaEndpoint(cronograma.id)}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(cronograma.toJson()),
      );

      if (response.statusCode == 200) {
        return CronogramaEvento.fromJson(json.decode(response.body));
      } else {
        print('Error response: ${response.body}');
        throw Exception('Error al actualizar cronograma: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception updating cronograma: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<Intervencion> createIntervencion(Intervencion intervencion) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.createIntervencionEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(intervencion.toJson()),
      );

      if (response.statusCode == 201) {
        return Intervencion.fromJson(json.decode(response.body));
      } else {
        print('Error response: ${response.body}');
        throw Exception('Error al crear intervención: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception creating intervencion: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}

class MaintenanceScreen extends StatefulWidget {
  final int cardId;

  const MaintenanceScreen({Key? key, required this.cardId}) : super(key: key);

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  String selectedOption = '';
  bool isLoading = false;
  String? errorMessage;
  bool dataLoaded = false;
  
  List<CronogramaEvento> cronogramas = [];
  List<Intervencion> intervenciones = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadMaintenanceData() async {
    if (dataLoaded) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.getMaintenanceData(widget.cardId);
      setState(() {
        cronogramas = data['cronogramas'] as List<CronogramaEvento>;
        intervenciones = data['intervenciones'] as List<Intervencion>;
        isLoading = false;
        dataLoaded = true;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      dataLoaded = false;
    });
    await _loadMaintenanceData();
  }

  List<CronogramaEvento> _getSortedCronogramas() {
    final List<CronogramaEvento> sorted = List.from(cronogramas);
    
    sorted.sort((a, b) {
      if (a.isCompletedOrOverdue != b.isCompletedOrOverdue) {
        return a.isCompletedOrOverdue ? 1 : -1; 
      }
      
      return a.date.compareTo(b.date);
    });
    
    return sorted;
  }

  Future<void> _toggleCronogramaCompletion(CronogramaEvento evento) async {
    try {
      final updatedEvento = evento.copyWith(completed: !evento.completed);
      
      final result = await ApiService.updateCronogramaStatus(updatedEvento);
      
      setState(() {
        final index = cronogramas.indexWhere((e) => e.id == evento.id);
        if (index != -1) {
          cronogramas[index] = result;
        }
        cronogramas.sort((a, b) {
          if (a.isCompletedOrOverdue != b.isCompletedOrOverdue) {
            return a.isCompletedOrOverdue ? 1 : -1;
          }
          return a.date.compareTo(b.date);
        });
      });
      
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedEvento.completed ? 'Tarea marcada como completada' : 'Tarea marcada como pendiente'
          ),
          backgroundColor: updatedEvento.completed ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: CustomAppBar(
        pageTitle: 'Actividades',
        showBackButton: true,
        onBackPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => main_app.CardDetailPage(cardId: widget.cardId),
            ),
          );
        },
      ),
      body: Column(
        children: [
          Container(
            width: 300,
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedOption = 'cronograma';
                      });
                      _loadMaintenanceData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedOption == 'cronograma' 
                          ? Theme.of(context).primaryColor 
                          : Colors.white,
                      foregroundColor: selectedOption == 'cronograma' 
                          ? Colors.white 
                          : Colors.black87,
                    ),
                    child: const Text('Cronograma'),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedOption = 'intervenciones';
                      });
                      _loadMaintenanceData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedOption == 'intervenciones' 
                          ? Theme.of(context).primaryColor 
                          : Colors.white,
                      foregroundColor: selectedOption == 'intervenciones' 
                          ? Colors.white 
                          : Colors.black87,
                    ),
                    child: const Text('Registro de\nActividades', 
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _buildDynamicContent(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (selectedOption.isNotEmpty) {
            _showFormModal(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selecciona una opción primero'),
              ),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: CustomDetailBottomBar(
        cardId: widget.cardId, 
        currentPage: '/card_maintenance/${widget.cardId}'
      ),
    );
  }

  Widget _buildDynamicContent() {
    if (selectedOption.isEmpty) {
      return const Center(
        child: Text(
          'Selecciona una opción para comenzar',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
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
              'Error al cargar los datos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (selectedOption == 'cronograma') {
                  _refreshData();
                } else {
                  _refreshData();
                }
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (selectedOption == 'cronograma') {
      final sortedCronogramas = _getSortedCronogramas();
      
      return sortedCronogramas.isEmpty
          ? const Center(
              child: Text(
                'No hay eventos en el cronograma',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView.builder(
                itemCount: sortedCronogramas.length,
                itemBuilder: (context, index) {
                  return _buildCronogramaCard(sortedCronogramas[index]);
                },
              ),
            );
    } else {
      return intervenciones.isEmpty
          ? const Center(
              child: Text(
                'No hay intervenciones registradas',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView.builder(
                itemCount: intervenciones.length,
                itemBuilder: (context, index) {
                  return _buildIntervencionCard(intervenciones[index]);
                },
              ),
            );
    }
  }

  Widget _buildCronogramaCard(CronogramaEvento evento) {
    final bool isOverdue = evento.isOverdue;
    final bool isCompleted = evento.completed;
    
    Color cardColor;
    Color textColor;
    IconData statusIcon;
    
    if (isCompleted) {
      cardColor = Colors.green[50]!;
      textColor = Colors.green[800]!;
      statusIcon = Icons.check_circle;
    } else if (isOverdue) {
      cardColor = Colors.red[50]!;
      textColor = Colors.red[800]!;
      statusIcon = Icons.warning;
    } else {
      cardColor = Colors.white;
      textColor = Colors.black87;
      statusIcon = Icons.schedule;
    }

    return Card(
      key: ValueKey(evento.id), 
      margin: const EdgeInsets.only(bottom: 10),
      color: cardColor,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ver detalles de: ${evento.title}'),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                      evento.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy').format(evento.date)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    if (isOverdue && !isCompleted)
                      Text(
                        'Vencido',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              
              IconButton(
                onPressed: () => _toggleCronogramaCompletion(evento),
                icon: Icon(
                  isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isCompleted ? Colors.green : Colors.grey[600],
                  size: 28,
                ),
                tooltip: isCompleted ? 'Marcar como pendiente' : 'Marcar como completado',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntervencionCard(Intervencion intervencion) {
    String capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ver detalles de: ${capitalize(intervencion.actionType)}'),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                capitalize(intervencion.actionType),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fecha: ${DateFormat('dd/MM/yyyy').format(intervencion.date)}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Descripción: ${intervencion.description}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Responsable: ${intervencion.responsible}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFormModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    
    DateTime? cronogramaDate;
    String cronogramaTitle = '';
    
    String interventionType = 'correctiva';
    DateTime? interventionDate;
    String interventionDescription = '';
    String interventionResponsible = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(selectedOption == 'cronograma' 
                  ? 'Añadir evento al cronograma' 
                  : 'Registrar nueva intervención'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: selectedOption == 'cronograma'
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Fecha',
                                border: OutlineInputBorder(),
                              ),
                              readOnly: true,
                              controller: TextEditingController(
                                text: cronogramaDate != null 
                                    ? DateFormat('dd/MM/yyyy').format(cronogramaDate!)
                                    : '',
                              ),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (date != null) {
                                  setDialogState(() {
                                    cronogramaDate = date;
                                  });
                                }
                              },
                              validator: (value) {
                                if (cronogramaDate == null) {
                                  return 'Por favor selecciona una fecha';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Título',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                cronogramaTitle = value;
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa un título';
                                }
                                return null;
                              },
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Tipo de Acción',
                                border: OutlineInputBorder(),
                              ),
                              value: interventionType,
                              items: const [
                                DropdownMenuItem(
                                  value: 'correctiva',
                                  child: Text('Correctiva'),
                                ),
                                DropdownMenuItem(
                                  value: 'preventiva',
                                  child: Text('Preventiva'),
                                ),
                                DropdownMenuItem(
                                  value: 'calibracion',
                                  child: Text('Calibración'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    interventionType = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Fecha',
                                border: OutlineInputBorder(),
                              ),
                              readOnly: true,
                              controller: TextEditingController(
                                text: interventionDate != null 
                                    ? DateFormat('dd/MM/yyyy').format(interventionDate!)
                                    : '',
                              ),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (date != null) {
                                  setDialogState(() {
                                    interventionDate = date;
                                  });
                                }
                              },
                              validator: (value) {
                                if (interventionDate == null) {
                                  return 'Por favor selecciona una fecha';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Descripción',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              onChanged: (value) {
                                interventionDescription = value;
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa una descripción';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Responsable',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                interventionResponsible = value;
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa un responsable';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        if (selectedOption == 'cronograma' && cronogramaDate != null) {
                          final newCronograma = CronogramaEvento(
                            id: 0,
                            title: cronogramaTitle,
                            date: cronogramaDate!,
                            cardId: widget.cardId,
                            completed: false, 
                          );
                          
                          final createdCronograma = await ApiService.createCronograma(newCronograma);
                          
                          setState(() {
                            cronogramas.add(createdCronograma);
                          });
                          
                        } else if (selectedOption == 'intervenciones' && interventionDate != null) {
                          final newIntervencion = Intervencion(
                            id: 0,
                            actionType: interventionType,
                            date: interventionDate!,
                            description: interventionDescription,
                            responsible: interventionResponsible,
                            cardId: widget.cardId,
                          );
                          
                          final createdIntervencion = await ApiService.createIntervencion(newIntervencion);
                          
                          setState(() {
                            intervenciones.add(createdIntervencion);
                          });
                        }
                        
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Guardado exitosamente'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al guardar: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mantenimiento App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MaintenanceScreen(cardId: 0),
    );
  }
}